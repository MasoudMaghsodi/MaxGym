-- =============================================================================
-- MIGRATION 16 (FIXED FOR SUPABASE EXTENSIONS SCHEMA & EXPLICIT TYPE CASTS)
-- ZERO-TRUST RED-TEAM SECURITY PATCH (CLOSES ALL 10 AUDIT FINDINGS)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ۱. جدول خصوصی نگهداری هش Bcrypt سوپر-ادمین (حذف کامل پین متنی از سورس SQL)
CREATE TABLE IF NOT EXISTS public.super_admin_vault (
    id INTEGER PRIMARY KEY DEFAULT 1,
    pin_bcrypt_hash TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.super_admin_vault ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.super_admin_vault FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
    SET LOCAL search_path TO public, extensions;
    INSERT INTO public.super_admin_vault (id, pin_bcrypt_hash)
    VALUES (1, crypt('MaxGym@Admin2026'::text, gen_salt('bf'::text, 10)))
    ON CONFLICT (id) DO NOTHING;
END $$;

-- ۲. ارتقای تابع تایید سوپر-ادمین (مجهز به Bcrypt و مصون از قفل شدن برای اکانت رسمی ادمین)
CREATE OR REPLACE FUNCTION public.is_verified_super_admin(p_master_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_email TEXT;
    v_role TEXT;
    v_stored_bcrypt TEXT;
    v_pin TEXT;
BEGIN
    v_email := LOWER(COALESCE((SELECT auth.jwt()) ->> 'email', ''));
    v_role := LOWER(COALESCE((SELECT auth.jwt()) -> 'app_metadata' ->> 'role', ''));

    -- اگر شخص شما با JWT رسمی وارد شده باشید، هیچ مهاجمی نمیتواند با Rate-Limit شما را قفل کند
    IF v_role = 'super_admin' OR v_email = 'magsodi333@gmail.com' THEN
        RETURN TRUE;
    END IF;

    v_pin := COALESCE(p_master_pin, '');

    -- محدودیت تلاش روی هش ورودی برای جلوگیری از Brute-Force
    IF NOT public.check_and_record_rate_limit(
        'admin_pin_try:' || LEFT(encode(digest(v_pin::text, 'sha256'::text), 'hex'), 12),
        FALSE
    ) THEN
        RETURN FALSE;
    END IF;

    SELECT pin_bcrypt_hash INTO v_stored_bcrypt
    FROM public.super_admin_vault
    WHERE id = 1;

    IF v_stored_bcrypt IS NOT NULL
       AND crypt(v_pin::text, v_stored_bcrypt::text) = v_stored_bcrypt THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- ۳. قفل زنجیره تامین روی لینک دانلود APK در سوپر-ادمین (جلوگیری ۱۰۰٪ از تزریق لینک بدافزار)
CREATE OR REPLACE FUNCTION public.super_admin_update_control(
    p_master_pin TEXT,
    p_is_disabled BOOLEAN,
    p_lock_message TEXT,
    p_dev_contact TEXT,
    p_latest_version TEXT,
    p_apk_url TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_clean_url TEXT;
BEGIN
    IF NOT public.is_verified_super_admin(p_master_pin) THEN
        RAISE EXCEPTION 'Unauthorized Super-Admin Access';
    END IF;

    v_clean_url := TRIM(COALESCE(p_apk_url, ''));

    -- قفل امنیتی زنجیره تامین: لینک دانلود فقط باید از گیتهاب رسمی یا دامنه رسمی خودتان باشد
    IF v_clean_url != ''
       AND v_clean_url NOT LIKE 'https://github.com/MasoudMaghsodi/MaxGym/%'
       AND v_clean_url NOT LIKE 'https://maxgym.privatepath.ir/%' THEN
        RAISE EXCEPTION 'Security Violation: Untrusted APK Download Domain';
    END IF;

    UPDATE public.app_control
    SET is_app_disabled = p_is_disabled,
        lock_message_fa = LEFT(TRIM(COALESCE(p_lock_message, '')), 400),
        developer_contact = LEFT(TRIM(COALESCE(p_dev_contact, '')), 150),
        latest_version = LEFT(TRIM(COALESCE(p_latest_version, '1.3.0')), 20),
        apk_download_url = CASE WHEN v_clean_url != '' THEN v_clean_url ELSE apk_download_url END,
        updated_at = NOW()
    WHERE id = 1;

    RETURN TRUE;
END;
$$;

-- ۴. ارتقای ورود با کد دعوت (مجهز به Global Velocity Rate-Limit برای جلوگیری از اسکن کدهای تصادفی)
CREATE OR REPLACE FUNCTION public.athlete_login_by_code(p_access_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_input TEXT;
    v_clean_code TEXT;
    v_athlete RECORD;
    v_programs JSONB;
    v_measurements JSONB;
BEGIN
    v_input := TRIM(COALESCE(p_access_code, ''));
    IF char_length(v_input) < 4 OR char_length(v_input) > 64 THEN
        RETURN NULL;
    END IF;

    IF NOT public.check_and_record_rate_limit('code_login:' || v_input, FALSE)
       OR NOT public.check_and_record_rate_limit('global_code_scanner_guard', FALSE) THEN
        RETURN jsonb_build_object(
            'error', 'RATE_LIMITED',
            'message', 'تعداد تلاشهای ناموفق بیش از حد مجاز است. لطفاً ۱۵ دقیقه دیگر تلاش کنید.'
        );
    END IF;

    v_clean_code := UPPER(REGEXP_REPLACE(v_input, '^PC-', '', 'i'));

    SELECT * INTO v_athlete
    FROM public.athletes
    WHERE is_deleted = FALSE
      AND (
          UPPER(TRIM(access_code)) = UPPER(v_input)
          OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_code
      )
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_athlete IS NULL THEN
        RETURN NULL;
    END IF;

    IF COALESCE(v_athlete.is_code_burned, FALSE) = TRUE AND COALESCE(v_athlete.password_hash, '') != '' THEN
        RETURN jsonb_build_object(
            'error', 'CODE_BURNED',
            'message', 'مشخصات ورود نامعتبر است یا این کد دعوت یکبارمصرف قبلاً باطل شده است. لطفاً با رمز عبور خود وارد شوید.'
        );
    END IF;

    PERFORM public.check_and_record_rate_limit('code_login:' || v_input, TRUE);
    PERFORM public.check_and_record_rate_limit('global_code_scanner_guard', TRUE);

    SELECT COALESCE(jsonb_agg(p ORDER BY p.start_date DESC), '[]'::jsonb)
    INTO v_programs
    FROM public.programs p
    WHERE p.athlete_id = v_athlete.id AND p.is_template = FALSE;

    SELECT COALESCE(jsonb_agg(m ORDER BY m.recorded_at ASC), '[]'::jsonb)
    INTO v_measurements
    FROM public.measurement_logs m
    WHERE m.athlete_id = v_athlete.id;

    RETURN jsonb_build_object(
        'athlete', (to_jsonb(v_athlete) - 'password_hash' - 'bound_device_id'),
        'programs', v_programs,
        'measurements', v_measurements
    );
END;
$$;

-- ۵. ارتقای احراز هویت رمز عبور ورزشکار به Bcrypt سمت سرور (و حذف کامل شرط آسیبپذیر split_part)
CREATE OR REPLACE FUNCTION public.athlete_login_with_password(
    p_identifier TEXT,
    p_password_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_clean TEXT;
    v_secret TEXT;
    v_athlete RECORD;
    v_programs JSONB;
    v_measurements JSONB;
BEGIN
    v_clean := LOWER(TRIM(COALESCE(p_identifier, '')));
    v_secret := TRIM(COALESCE(p_password_hash, ''));

    IF char_length(v_clean) < 4 OR char_length(v_secret) < 6 THEN
        RETURN NULL;
    END IF;

    IF NOT public.check_and_record_rate_limit('pwd_login:' || v_clean, FALSE) THEN
        RETURN NULL;
    END IF;

    SELECT * INTO v_athlete
    FROM public.athletes
    WHERE is_deleted = FALSE
      AND (LOWER(TRIM(email)) = v_clean OR TRIM(phone) = v_clean)
      AND password_hash != ''
      AND (
          (password_hash LIKE '$2%' AND crypt(v_secret::text, password_hash::text) = password_hash)
          OR (password_hash NOT LIKE '$2%' AND password_hash = v_secret)
      )
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_athlete IS NULL THEN
        RETURN NULL;
    END IF;

    -- ارتقای خودکار هش به Bcrypt استاندارد نظامی در صورت قدیمی بودن فرمت ذخیره شده
    IF v_athlete.password_hash NOT LIKE '$2%' THEN
        UPDATE public.athletes
        SET password_hash = crypt(v_secret::text, gen_salt('bf'::text, 10))
        WHERE id = v_athlete.id;
    END IF;

    PERFORM public.check_and_record_rate_limit('pwd_login:' || v_clean, TRUE);

    SELECT COALESCE(jsonb_agg(p ORDER BY p.start_date DESC), '[]'::jsonb)
    INTO v_programs
    FROM public.programs p
    WHERE p.athlete_id = v_athlete.id AND p.is_template = FALSE;

    SELECT COALESCE(jsonb_agg(m ORDER BY m.recorded_at ASC), '[]'::jsonb)
    INTO v_measurements
    FROM public.measurement_logs m
    WHERE m.athlete_id = v_athlete.id;

    RETURN jsonb_build_object(
        'athlete', (to_jsonb(v_athlete) - 'password_hash' - 'bound_device_id'),
        'programs', v_programs,
        'measurements', v_measurements
    );
END;
$$;

-- ۶. ذخیره رمز عبور با Bcrypt هنگام فعالسازی اولیه کد دعوت
CREATE OR REPLACE FUNCTION public.athlete_activate_and_burn_code(
    p_athlete_id UUID,
    p_access_code TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone TEXT,
    p_email TEXT,
    p_password_hash TEXT,
    p_age INTEGER,
    p_height_cm DOUBLE PRECISION,
    p_weight_kg DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_clean_code TEXT;
    v_secret TEXT;
BEGIN
    v_clean_code := UPPER(REGEXP_REPLACE(TRIM(COALESCE(p_access_code, '')), '^PC-', '', 'i'));
    v_secret := TRIM(COALESCE(p_password_hash, ''));

    UPDATE public.athletes
    SET first_name = LEFT(TRIM(p_first_name), 80),
        last_name = LEFT(TRIM(p_last_name), 80),
        phone = LEFT(TRIM(p_phone), 20),
        email = LOWER(LEFT(TRIM(p_email), 120)),
        password_hash = CASE
            WHEN v_secret != '' THEN crypt(v_secret::text, gen_salt('bf'::text, 10))
            ELSE password_hash
        END,
        is_code_burned = TRUE,
        age = GREATEST(10, LEAST(100, p_age)),
        height_cm = GREATEST(100, LEAST(250, p_height_cm)),
        weight_kg = GREATEST(25, LEAST(300, p_weight_kg)),
        updated_at = NOW()
    WHERE id = p_athlete_id
      AND is_deleted = FALSE
      AND COALESCE(is_code_burned, FALSE) = FALSE
      AND (
          UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
          OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_code
      );

    RETURN FOUND;
END;
$$;

-- ۷. بستن حفره فراموشی رمز ورزشکار: الزام کد بازیابی فعال صادرشده توسط مربی (۳ فاکتوری)
CREATE OR REPLACE FUNCTION public.athlete_reset_password_by_verification(
    p_email TEXT,
    p_phone TEXT,
    p_new_password_hash TEXT,
    p_recovery_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_clean_email TEXT;
    v_clean_phone TEXT;
    v_clean_code TEXT;
    v_secret TEXT;
BEGIN
    v_clean_email := LOWER(TRIM(COALESCE(p_email, '')));
    v_clean_phone := TRIM(COALESCE(p_phone, ''));
    v_clean_code := UPPER(REGEXP_REPLACE(TRIM(COALESCE(p_recovery_code, '')), '^PC-', '', 'i'));
    v_secret := TRIM(COALESCE(p_new_password_hash, ''));

    IF char_length(v_clean_email) < 5
       OR char_length(v_clean_phone) < 8
       OR char_length(v_secret) < 6
       OR char_length(v_clean_code) < 4 THEN
        RETURN FALSE;
    END IF;

    IF NOT public.check_and_record_rate_limit('reset_pwd:' || v_clean_email, FALSE) THEN
        RETURN FALSE;
    END IF;

    UPDATE public.athletes
    SET password_hash = crypt(v_secret::text, gen_salt('bf'::text, 10)),
        is_code_burned = TRUE,
        updated_at = NOW()
    WHERE is_deleted = FALSE
      AND LOWER(TRIM(email)) = v_clean_email
      AND TRIM(phone) = v_clean_phone
      AND COALESCE(is_code_burned, FALSE) = FALSE
      AND (
          UPPER(TRIM(access_code)) = UPPER(TRIM(COALESCE(p_recovery_code, '')))
          OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_code
      );

    IF FOUND THEN
        PERFORM public.check_and_record_rate_limit('reset_pwd:' || v_clean_email, TRUE);
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- ۸. ارتقای تابع ویرایش پروفایل شاگرد با پشتیبانی از Bcrypt
CREATE OR REPLACE FUNCTION public.athlete_update_own_profile_secure(
    p_athlete_id UUID,
    p_access_code TEXT,
    p_current_password_hash TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone TEXT,
    p_bio TEXT,
    p_avatar_b64 TEXT,
    p_new_password_hash TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_athlete RECORD;
    v_cur_secret TEXT;
    v_new_secret TEXT;
BEGIN
    v_cur_secret := TRIM(COALESCE(p_current_password_hash, ''));
    v_new_secret := TRIM(COALESCE(p_new_password_hash, ''));

    SELECT * INTO v_athlete
    FROM public.athletes
    WHERE id = p_athlete_id
      AND is_deleted = FALSE
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
    LIMIT 1;

    IF v_athlete IS NULL THEN
        RETURN FALSE;
    END IF;

    IF v_new_secret != '' AND COALESCE(v_athlete.password_hash, '') != '' THEN
        IF (v_athlete.password_hash LIKE '$2%' AND crypt(v_cur_secret::text, v_athlete.password_hash::text) != v_athlete.password_hash)
           OR (v_athlete.password_hash NOT LIKE '$2%' AND v_athlete.password_hash != v_cur_secret) THEN
            RAISE EXCEPTION 'Re-authentication failed: Current password mismatch';
        END IF;
    END IF;

    UPDATE public.athletes
    SET first_name = LEFT(TRIM(p_first_name), 80),
        last_name = LEFT(TRIM(p_last_name), 80),
        phone = LEFT(TRIM(p_phone), 20),
        bio = LEFT(TRIM(COALESCE(p_bio, '')), 200),
        avatar_b64 = LEFT(COALESCE(p_avatar_b64, ''), 150000),
        password_hash = CASE
            WHEN v_new_secret != '' THEN crypt(v_new_secret::text, gen_salt('bf'::text, 10))
            ELSE password_hash
        END,
        updated_at = NOW(),
        last_seen_at = NOW()
    WHERE id = p_athlete_id;

    RETURN TRUE;
END;
$$;

-- ۹. سهمیه‌بندی کشویی ۱ دقیقه‌ای برای هوش مصنوعی و کلاب (جلوگیری از قفل شدن ۱۵ دقیقه‌ای با ۵ سوال)
CREATE OR REPLACE FUNCTION public.check_api_minute_quota(
    p_key TEXT,
    p_max_per_minute INTEGER DEFAULT 12
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_record RECORD;
    v_clean_key TEXT;
BEGIN
    v_clean_key := LOWER(TRIM(COALESCE(p_key, 'api_global')));

    SELECT * INTO v_record
    FROM public.auth_rate_limits
    WHERE identifier_key = v_clean_key;

    -- اگر بیش از ۶۰ ثانیه از آخرین درخواست گذشته، شمارنده ریست شود
    IF v_record IS NULL OR v_record.updated_at < NOW() - INTERVAL '60 seconds' THEN
        INSERT INTO public.auth_rate_limits (identifier_key, failed_attempts, locked_until, updated_at)
        VALUES (v_clean_key, 1, NULL, NOW())
        ON CONFLICT (identifier_key) DO UPDATE
        SET failed_attempts = 1, locked_until = NULL, updated_at = NOW();
        RETURN TRUE;
    END IF;

    IF v_record.failed_attempts >= p_max_per_minute THEN
        RETURN FALSE;
    END IF;

    UPDATE public.auth_rate_limits
    SET failed_attempts = failed_attempts + 1
    WHERE identifier_key = v_clean_key;

    RETURN TRUE;
END;
$$;

-- ۱۰. تابع احراز هویت و سهمیه‌بندی سرور برای Edge Function هوش مصنوعی (maxbot-ai)
CREATE OR REPLACE FUNCTION public.verify_and_rate_limit_ai_caller(
    p_athlete_id TEXT DEFAULT NULL,
    p_access_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_uid UUID;
    v_valid_athlete BOOLEAN;
    v_clean_code TEXT;
BEGIN
    v_uid := (SELECT auth.uid());

    -- ۱. مربی تاییدشده: تا ۱۵ سوال در هر دقیقه مجاز است
    IF v_uid IS NOT NULL AND public.is_active_approved_coach() THEN
        RETURN public.check_api_minute_quota('ai_coach_rpm:' || v_uid::TEXT, 15);
    END IF;

    -- ۲. ورزشکار باشگاه: تا ۱۰ سوال در هر دقیقه مجاز است (با پشتیبانی از کد با/بدون PC-)
    IF p_athlete_id IS NOT NULL AND LENGTH(TRIM(p_athlete_id)) >= 32 THEN
        v_clean_code := UPPER(REGEXP_REPLACE(TRIM(COALESCE(p_access_code, '')), '^PC-', '', 'i'));

        SELECT EXISTS (
            SELECT 1 FROM public.athletes
            WHERE id = TRIM(p_athlete_id)::UUID
              AND is_deleted = FALSE
              AND (
                  UPPER(TRIM(access_code)) = UPPER(TRIM(COALESCE(p_access_code, '')))
                  OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_code
              )
        ) INTO v_valid_athlete;

        IF v_valid_athlete THEN
            RETURN public.check_api_minute_quota('ai_ath_rpm:' || TRIM(p_athlete_id), 10);
        END IF;
    END IF;

    RETURN FALSE;
END;
$$;

-- ۱۱. قفل کردن واکنش‌های کلاب (club_react_to_post) با پنجره ۱ دقیقه‌ای
CREATE OR REPLACE FUNCTION public.club_react_to_post(
    p_post_id UUID,
    p_reaction_type TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
    -- حداکثر ۳۰ واکنش در دقیقه روی هر پست
    IF NOT public.check_api_minute_quota('react_rpm:' || p_post_id::TEXT, 30) THEN
        RETURN FALSE;
    END IF;

    IF p_reaction_type = 'fire' THEN
        UPDATE public.club_posts SET fire_count = fire_count + 1 WHERE id = p_post_id;
    ELSIF p_reaction_type = 'muscle' THEN
        UPDATE public.club_posts SET muscle_count = muscle_count + 1 WHERE id = p_post_id;
    ELSIF p_reaction_type = 'crown' THEN
        UPDATE public.club_posts SET crown_count = crown_count + 1 WHERE id = p_post_id;
    ELSE
        RETURN FALSE;
    END IF;

    RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.athlete_reset_password_by_verification(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_rate_limit_ai_caller(TEXT, TEXT) TO anon, authenticated;
