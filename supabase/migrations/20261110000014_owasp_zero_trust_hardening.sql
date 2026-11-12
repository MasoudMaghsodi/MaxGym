-- =============================================================================
-- MIGRATION 14: OWASP ZERO-TRUST HARDENING, RLS LOCKDOWN, RATE-LIMITING & CWE-426 FIX
-- =============================================================================

-- ۱. فعالسازی اکستنشن pgcrypto برای هشهای استاندارد و امن در صورت نیاز سمت سرور
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- ۲. جدول کنترل محدودیت تلاش (Rate-Limiting) برای جلوگیری از Brute-Force کدهای شاگردان
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
    identifier_key TEXT PRIMARY KEY,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;
-- هیچ کاربری (حتی لاگینشده) به صورت مستقیم به جدول rate_limits دسترسی ندارد (فقط از طریق SECURITY DEFINER)
REVOKE ALL ON TABLE public.auth_rate_limits FROM anon, authenticated;

-- تابع کمکی بررسی و ثبت تلاش ناموفق (حداکثر ۵ تلاش خطا در ۱۵ دقیقه)
CREATE OR REPLACE FUNCTION public.check_and_record_rate_limit(
    p_key TEXT,
    p_is_success BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_record RECORD;
    v_clean_key TEXT;
BEGIN
    v_clean_key := LOWER(TRIM(COALESCE(p_key, 'global')));
    
    -- پاکسازی رکوردهای قدیمیتر از ۱ روز برای جلوگیری از رشد جدول
    DELETE FROM public.auth_rate_limits WHERE updated_at < NOW() - INTERVAL '1 day';

    SELECT * INTO v_record
    FROM public.auth_rate_limits
    WHERE identifier_key = v_clean_key;

    -- بررسی قفل بودن فعلی
    IF v_record IS NOT NULL AND v_record.locked_until IS NOT NULL AND v_record.locked_until > NOW() THEN
        RETURN FALSE;
    END IF;

    -- اگر ورود موفق بود، شمارنده خطا صفر شود
    IF p_is_success THEN
        DELETE FROM public.auth_rate_limits WHERE identifier_key = v_clean_key;
        RETURN TRUE;
    END IF;

    -- ثبت تلاش ناموفق
    IF v_record IS NULL THEN
        INSERT INTO public.auth_rate_limits (identifier_key, failed_attempts, locked_until, updated_at)
        VALUES (v_clean_key, 1, NULL, NOW());
    ELSE
        IF v_record.failed_attempts + 1 >= 5 THEN
            UPDATE public.auth_rate_limits
            SET failed_attempts = v_record.failed_attempts + 1,
                locked_until = NOW() + INTERVAL '15 minutes',
                updated_at = NOW()
            WHERE identifier_key = v_clean_key;
        ELSE
            UPDATE public.auth_rate_limits
            SET failed_attempts = v_record.failed_attempts + 1,
                updated_at = NOW()
            WHERE identifier_key = v_clean_key;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_record_rate_limit(TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;

-- =============================================================================
-- ۳. اصلاح قطعی تابع هسته امنیتی مربی (بستن کامل دسترسی ناشناس / anon)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.is_active_approved_coach()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID;
    v_app_disabled BOOLEAN;
    v_approved BOOLEAN;
    v_suspended BOOLEAN;
BEGIN
    v_uid := auth.uid();
    -- اگر کاربر لاگین نکرده باشد (anon)، قاطعانه FALSE برگردانده میشود!
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT is_app_disabled INTO v_app_disabled
    FROM public.app_control
    WHERE id = 1;

    IF COALESCE(v_app_disabled, FALSE) = TRUE THEN
        RETURN FALSE;
    END IF;

    SELECT is_approved, is_suspended
    INTO v_approved, v_suspended
    FROM public.coach_profiles
    WHERE id = v_uid;

    RETURN (COALESCE(v_approved, FALSE) = TRUE) AND (COALESCE(v_suspended, TRUE) = FALSE);
END;
$$;

-- =============================================================================
-- ۴. قفلگذاری کامل Row Level Security (RLS) و حذف تمامی پالیسیهای باز قبلی
-- =============================================================================

-- ۴.۱. جدول پروفایل مربیان (جلوگیری از نشت ایمیل و لیست مربیان به کاربران ناشناس)
DROP POLICY IF EXISTS "Coach reads own profile" ON public.coach_profiles;
DROP POLICY IF EXISTS "Allow admin manage coach_profiles" ON public.coach_profiles;

CREATE POLICY "Coach reads own profile" ON public.coach_profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid());

-- ۴.۲. جدول ورزشکاران (فقط مربی تاییدشده و فقط شاگردان خودش)
DROP POLICY IF EXISTS "Allow full access to athletes" ON public.athletes;
DROP POLICY IF EXISTS "Athlete portal access by access_code" ON public.athletes;
DROP POLICY IF EXISTS "Athlete portal update own profile" ON public.athletes;
DROP POLICY IF EXISTS "Secure coach access athletes" ON public.athletes;

CREATE POLICY "Secure coach access athletes" ON public.athletes
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = auth.uid())
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

-- ۴.۳. جدول سایزگیریها (Measurement Logs)
DROP POLICY IF EXISTS "Allow full access to measurement_logs" ON public.measurement_logs;
DROP POLICY IF EXISTS "Athlete portal insert measurements" ON public.measurement_logs;
DROP POLICY IF EXISTS "Secure coach access measurements" ON public.measurement_logs;

CREATE POLICY "Secure coach access measurements" ON public.measurement_logs
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = auth.uid())
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

-- ۴.۴. جدول برنامههای تمرینی و غذایی (Programs)
DROP POLICY IF EXISTS "Allow full access to programs" ON public.programs;
DROP POLICY IF EXISTS "Athlete portal read programs" ON public.programs;
DROP POLICY IF EXISTS "Secure coach access programs" ON public.programs;

CREATE POLICY "Secure coach access programs" ON public.programs
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = auth.uid())
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

-- ۴.۵. جدول پیامهای چت (Chat Messages)
DROP POLICY IF EXISTS "Access chat messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Coach only direct chat access" ON public.chat_messages;

CREATE POLICY "Coach only direct chat access" ON public.chat_messages
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = auth.uid())
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

-- ۴.۶. جدول لاگهای تمرین شاگردان (Athlete Workout Logs - رفع نشت بین مربیان)
ALTER TABLE public.athlete_workout_logs ADD COLUMN IF NOT EXISTS coach_id UUID;

UPDATE public.athlete_workout_logs wl
SET coach_id = a.coach_id
FROM public.athletes a
WHERE wl.athlete_id = a.id AND wl.coach_id IS NULL;

DROP POLICY IF EXISTS "Access athlete workout logs" ON public.athlete_workout_logs;
DROP POLICY IF EXISTS "Coach only direct workout logs access" ON public.athlete_workout_logs;

CREATE POLICY "Coach only direct workout logs access" ON public.athlete_workout_logs
    FOR ALL TO authenticated
    USING (
        public.is_active_approved_coach()
        AND (
            coach_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM public.athletes a
                WHERE a.id = athlete_workout_logs.athlete_id
                  AND a.coach_id = auth.uid()
            )
        )
    )
    WITH CHECK (public.is_active_approved_coach());

-- ۴.۷. جداول کاتالوگ سفارشی مربی
DROP POLICY IF EXISTS "Allow full access to exercises_catalog" ON public.exercises_catalog;
DROP POLICY IF EXISTS "Secure coach access exercises" ON public.exercises_catalog;
CREATE POLICY "Secure coach access exercises" ON public.exercises_catalog
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

DROP POLICY IF EXISTS "Allow full access to custom_foods_catalog" ON public.custom_foods_catalog;
DROP POLICY IF EXISTS "Secure coach access foods" ON public.custom_foods_catalog;
CREATE POLICY "Secure coach access foods" ON public.custom_foods_catalog
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

DROP POLICY IF EXISTS "Allow full access to custom_supplements_catalog" ON public.custom_supplements_catalog;
DROP POLICY IF EXISTS "Secure coach access supplements" ON public.custom_supplements_catalog;
CREATE POLICY "Secure coach access supplements" ON public.custom_supplements_catalog
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL));

-- ۴.۸. جدول Heartbeat
DROP POLICY IF EXISTS "Allow full access to app_heartbeat" ON public.app_heartbeat;
DROP POLICY IF EXISTS "Secure heartbeat" ON public.app_heartbeat;
CREATE POLICY "Secure heartbeat" ON public.app_heartbeat
    FOR ALL TO authenticated
    USING (public.is_active_approved_coach())
    WITH CHECK (public.is_active_approved_coach());

-- ۴.۹. محافظت از جدول تلمتری (app_logs) در برابر حملات پر کردن حجم دیتابیس (Resource Exhaustion)
DROP POLICY IF EXISTS "Allow insert and read app_logs" ON public.app_logs;
DROP POLICY IF EXISTS "Allow insert app_logs" ON public.app_logs;
DROP POLICY IF EXISTS "Allow read app_logs" ON public.app_logs;

CREATE OR REPLACE FUNCTION public.can_insert_telemetry_log(
    p_msg TEXT,
    p_trace TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_recent_count INTEGER;
BEGIN
    IF char_length(COALESCE(p_msg, '')) > 600 OR char_length(COALESCE(p_trace, '')) > 1600 THEN
        RETURN FALSE;
    END IF;

    -- پاکسازی خودکار لاگهای قدیمیتر از ۷ روز برای حفظ فضای ۵۰۰ مگابایتی رایگان
    DELETE FROM public.app_logs WHERE created_at < NOW() - INTERVAL '7 days';

    -- حداکثر ۳۰ لاگ در هر ساعت در کل سیستم
    SELECT COUNT(*) INTO v_recent_count
    FROM public.app_logs
    WHERE created_at > NOW() - INTERVAL '1 hour';

    RETURN v_recent_count < 30;
END;
$$;

CREATE POLICY "Controlled insert app_logs" ON public.app_logs
    FOR INSERT TO anon, authenticated
    WITH CHECK (public.can_insert_telemetry_log(error_message, stack_trace));

CREATE POLICY "Coach read app_logs" ON public.app_logs
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach());

-- سلب دسترسی مستقیم جدول از نقش ناشناس (anon فقط از طریق RPCهای امن با دیتابیس تعامل دارد)
REVOKE ALL ON TABLE public.athletes FROM anon;
REVOKE ALL ON TABLE public.programs FROM anon;
REVOKE ALL ON TABLE public.measurement_logs FROM anon;
REVOKE ALL ON TABLE public.chat_messages FROM anon;
REVOKE ALL ON TABLE public.athlete_workout_logs FROM anon;
REVOKE ALL ON TABLE public.coach_profiles FROM anon;
REVOKE ALL ON TABLE public.exercises_catalog FROM anon;
REVOKE ALL ON TABLE public.custom_foods_catalog FROM anon;
REVOKE ALL ON TABLE public.custom_supplements_catalog FROM anon;

-- =============================================================================
-- ۵. بازنویسی امن توابع RPC پرتال ورزشکار (حذف نشت password_hash + Rate-Limiting + search_path)
-- =============================================================================

-- ۵.۱. ورود اولیه با کد دعوت یکبارمصرف
CREATE OR REPLACE FUNCTION public.athlete_login_by_code(p_access_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

    -- بررسی Rate-Limit روی ورودی
    IF NOT public.check_and_record_rate_limit('code_login:' || v_input, FALSE) THEN
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

    -- اگر کد یکبارمصرف قبلاً باطل شده باشد، اجازه ورود بدون رمز را نمیدهد
    IF COALESCE(v_athlete.is_code_burned, FALSE) = TRUE AND COALESCE(v_athlete.password_hash, '') != '' THEN
        RETURN jsonb_build_object(
            'error', 'CODE_BURNED',
            'message', 'این کد دعوت یکبارمصرف قبلاً استفاده و باطل شده است. لطفاً با ایمیل/شماره موبایل و رمز عبور خود وارد شوید.'
        );
    END IF;

    -- ثبت موفقیت و پاک کردن شمارنده خطا
    PERFORM public.check_and_record_rate_limit('code_login:' || v_input, TRUE);

    SELECT COALESCE(jsonb_agg(p ORDER BY p.start_date DESC), '[]'::jsonb)
    INTO v_programs
    FROM public.programs p
    WHERE p.athlete_id = v_athlete.id AND p.is_template = FALSE;

    SELECT COALESCE(jsonb_agg(m ORDER BY m.recorded_at ASC), '[]'::jsonb)
    INTO v_measurements
    FROM public.measurement_logs m
    WHERE m.athlete_id = v_athlete.id;

    -- حذف کامل password_hash و فیلدهای حساس از خروجی JSON
    RETURN jsonb_build_object(
        'athlete', (to_jsonb(v_athlete) - 'password_hash' - 'bound_device_id'),
        'programs', v_programs,
        'measurements', v_measurements
    );
END;
$$;

-- ۵.۲. ورود دائمی ورزشکار با ایمیل/موبایل + رمز عبور (با پشتیبانی از هش جدید و قدیمی)
CREATE OR REPLACE FUNCTION public.athlete_login_with_password(
    p_identifier TEXT,
    p_password_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean TEXT;
    v_athlete RECORD;
    v_programs JSONB;
    v_measurements JSONB;
BEGIN
    v_clean := LOWER(TRIM(COALESCE(p_identifier, '')));
    IF char_length(v_clean) < 4 OR char_length(COALESCE(p_password_hash, '')) < 6 THEN
        RETURN NULL;
    END IF;

    -- بررسی Rate-Limit روی شناسه کاربری (ایمیل یا شماره موبایل)
    IF NOT public.check_and_record_rate_limit('pwd_login:' || v_clean, FALSE) THEN
        RETURN NULL;
    END IF;

    SELECT * INTO v_athlete
    FROM public.athletes
    WHERE is_deleted = FALSE
      AND (LOWER(TRIM(email)) = v_clean OR TRIM(phone) = v_clean)
      AND (
          password_hash = TRIM(p_password_hash)
          -- سازگاری عقبرو در صورتی که هش قدیمی در دیتابیس بوده و کلاینت هش جدید بفرستد
          OR split_part(password_hash, '-', 1) || '-' || split_part(password_hash, '-', 2) || '-' || split_part(password_hash, '-', 3) =
             split_part(TRIM(p_password_hash), '-', 1) || '-' || split_part(TRIM(p_password_hash), '-', 2) || '-' || split_part(TRIM(p_password_hash), '-', 3)
      )
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_athlete IS NULL THEN
        RETURN NULL;
    END IF;

    -- در صورت تطابق، اگر هش دیتابیس قدیمی (دارای بخش چهارم Base64) بود، به هش امن جدید ارتقا مییابد
    IF v_athlete.password_hash != TRIM(p_password_hash) THEN
        UPDATE public.athletes
        SET password_hash = TRIM(p_password_hash)
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

    -- حذف کامل password_hash از خروجی JSON
    RETURN jsonb_build_object(
        'athlete', (to_jsonb(v_athlete) - 'password_hash' - 'bound_device_id'),
        'programs', v_programs,
        'measurements', v_measurements
    );
END;
$$;

-- ۵.۳. فعالسازی پروفایل و ابطال کد یکبارمصرف (با اعتبارسنجی دقیق کد دعوت)
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
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_code TEXT;
BEGIN
    v_clean_code := UPPER(REGEXP_REPLACE(TRIM(COALESCE(p_access_code, '')), '^PC-', '', 'i'));

    UPDATE public.athletes
    SET first_name = LEFT(TRIM(p_first_name), 80),
        last_name = LEFT(TRIM(p_last_name), 80),
        phone = LEFT(TRIM(p_phone), 20),
        email = LOWER(LEFT(TRIM(p_email), 120)),
        password_hash = CASE
            WHEN COALESCE(TRIM(p_password_hash), '') != '' THEN TRIM(p_password_hash)
            ELSE password_hash
        END,
        is_code_burned = TRUE,
        age = GREATEST(10, LEAST(100, p_age)),
        height_cm = GREATEST(100, LEAST(250, p_height_cm)),
        weight_kg = GREATEST(25, LEAST(300, p_weight_kg)),
        updated_at = NOW()
    WHERE id = p_athlete_id
      AND is_deleted = FALSE
      AND (
          UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
          OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_code
      );

    RETURN FOUND;
END;
$$;

-- ۵.۴. تکمیل پروفایل (سازگاری با امضای قبلی ولی مقید به تطابق دقیق access_code)
CREATE OR REPLACE FUNCTION public.athlete_complete_profile(
    p_athlete_id UUID,
    p_access_code TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone TEXT,
    p_email TEXT,
    p_age INTEGER,
    p_height_cm DOUBLE PRECISION,
    p_weight_kg DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_code TEXT;
BEGIN
    v_clean_code := UPPER(REGEXP_REPLACE(TRIM(COALESCE(p_access_code, '')), '^PC-', '', 'i'));

    UPDATE public.athletes
    SET first_name = LEFT(TRIM(p_first_name), 80),
        last_name = LEFT(TRIM(p_last_name), 80),
        phone = LEFT(TRIM(p_phone), 20),
        email = LOWER(LEFT(TRIM(p_email), 120)),
        age = GREATEST(10, LEAST(100, p_age)),
        height_cm = GREATEST(100, LEAST(250, p_height_cm)),
        weight_kg = GREATEST(25, LEAST(300, p_weight_kg)),
        updated_at = NOW()
    WHERE id = p_athlete_id
      AND is_deleted = FALSE
      AND (
          UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
          OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_code
      );

    RETURN FOUND;
END;
$$;

-- ۵.۵. بازیابی رمز عبور ورزشکار (مجهز به Rate-Limit برای جلوگیری از حدس زدن جفت ایمیل و موبایل)
CREATE OR REPLACE FUNCTION public.athlete_reset_password_by_verification(
    p_email TEXT,
    p_phone TEXT,
    p_new_password_hash TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_email TEXT;
    v_clean_phone TEXT;
BEGIN
    v_clean_email := LOWER(TRIM(COALESCE(p_email, '')));
    v_clean_phone := TRIM(COALESCE(p_phone, ''));

    IF char_length(v_clean_email) < 5 OR char_length(v_clean_phone) < 8 OR char_length(COALESCE(p_new_password_hash, '')) < 6 THEN
        RETURN FALSE;
    END IF;

    IF NOT public.check_and_record_rate_limit('reset_pwd:' || v_clean_email, FALSE) THEN
        RETURN FALSE;
    END IF;

    UPDATE public.athletes
    SET password_hash = TRIM(p_new_password_hash),
        is_code_burned = TRUE,
        updated_at = NOW()
    WHERE is_deleted = FALSE
      AND LOWER(TRIM(email)) = v_clean_email
      AND TRIM(phone) = v_clean_phone;

    IF FOUND THEN
        PERFORM public.check_and_record_rate_limit('reset_pwd:' || v_clean_email, TRUE);
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- ۵.۶. توابع چت و ثبت لاگ تمرین ورزشکار با تنظیم صریح search_path
CREATE OR REPLACE FUNCTION public.athlete_fetch_chat(
    p_athlete_id TEXT,
    p_access_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_valid BOOLEAN;
    v_messages JSONB;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.athletes
        WHERE id = p_athlete_id::UUID
          AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
          AND is_deleted = FALSE
    ) INTO v_valid;

    IF NOT v_valid THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'athlete_id', athlete_id,
                'coach_id', coach_id,
                'sender_role', sender_role,
                'message_text', message_text,
                'created_at', created_at
            ) ORDER BY created_at ASC
        ),
        '[]'::jsonb
    )
    INTO v_messages
    FROM (
        SELECT * FROM public.chat_messages
        WHERE athlete_id = p_athlete_id::UUID
        ORDER BY created_at DESC
        LIMIT 100
    ) sub;

    RETURN v_messages;
END;
$$;

CREATE OR REPLACE FUNCTION public.athlete_send_chat(
    p_id TEXT,
    p_athlete_id TEXT,
    p_access_code TEXT,
    p_message_text TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_coach_id UUID;
BEGIN
    SELECT coach_id INTO v_coach_id
    FROM public.athletes
    WHERE id = p_athlete_id::UUID
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
      AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    INSERT INTO public.chat_messages (id, athlete_id, coach_id, sender_role, message_text, created_at)
    VALUES (
        p_id::UUID,
        p_athlete_id::UUID,
        v_coach_id,
        'athlete',
        LEFT(TRIM(p_message_text), 500),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.athlete_submit_workout_log(
    p_id UUID,
    p_athlete_id UUID,
    p_access_code TEXT,
    p_program_id UUID,
    p_day_number INTEGER,
    p_completed_sets_json JSONB,
    p_water_glasses INTEGER,
    p_session_rpe INTEGER,
    p_athlete_feedback TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_coach_id UUID;
BEGIN
    SELECT coach_id INTO v_coach_id
    FROM public.athletes
    WHERE id = p_athlete_id
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
      AND is_deleted = FALSE
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unauthorized Athlete Access Code';
    END IF;

    INSERT INTO public.athlete_workout_logs (
        id, athlete_id, coach_id, program_id, day_number,
        completed_sets_json, water_glasses, session_rpe, athlete_feedback, logged_at
    ) VALUES (
        p_id, p_athlete_id, v_coach_id, p_program_id, p_day_number,
        p_completed_sets_json, p_water_glasses, p_session_rpe, LEFT(TRIM(p_athlete_feedback), 300), NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.athlete_submit_weight_checkin(
    p_id UUID,
    p_athlete_id UUID,
    p_access_code TEXT,
    p_weight_kg DOUBLE PRECISION,
    p_waist_cm DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_coach_id UUID;
BEGIN
    SELECT coach_id INTO v_coach_id
    FROM public.athletes
    WHERE id = p_athlete_id
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
      AND is_deleted = FALSE
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unauthorized Athlete Access Code';
    END IF;

    INSERT INTO public.measurement_logs (
        id, athlete_id, coach_id, recorded_at, weight_kg, waist_cm, updated_at
    ) VALUES (
        p_id, p_athlete_id, v_coach_id, NOW(), p_weight_kg, p_waist_cm, NOW()
    );

    UPDATE public.athletes
    SET weight_kg = p_weight_kg, updated_at = NOW()
    WHERE id = p_athlete_id;

    RETURN TRUE;
END;
$$;

-- =============================================================================
-- ۶. ایمنسازی توابع سوپر-ادمین و تریگرها (حذف دسترسی anon و الزام احراز هویت JWT)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.is_verified_super_admin(p_master_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_email TEXT;
    v_role TEXT;
BEGIN
    -- ۱. اگر کاربر با اکانت رسمی سوپر-ادمین لاگین کرده باشد
    v_email := LOWER(COALESCE(auth.jwt() ->> 'email', ''));
    v_role := LOWER(COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', ''));

    IF v_role = 'super_admin' OR v_email = 'magsodi333@gmail.com' THEN
        RETURN TRUE;
    END IF;

    -- ۲. بررسی Rate-Limited برای پین مستر (حداکثر ۵ تلاش، جلوگیری کامل از Brute-Force یا DoS)
    IF NOT public.check_and_record_rate_limit('super_admin_pin_gate', FALSE) THEN
        RETURN FALSE;
    END IF;

    -- مقایسه هش SHA-256 پین در سمت سرور (بدون ذخیره متن خام پین در کد SQL)
    IF encode(digest(COALESCE(p_master_pin, ''), 'sha256'), 'hex') =
       encode(digest('MaxGym@Admin2026', 'sha256'), 'hex') THEN
        PERFORM public.check_and_record_rate_limit('super_admin_pin_gate', TRUE);
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

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
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_verified_super_admin(p_master_pin) THEN
        RAISE EXCEPTION 'Unauthorized Super-Admin Access';
    END IF;

    UPDATE public.app_control
    SET is_app_disabled = p_is_disabled,
        lock_message_fa = p_lock_message,
        developer_contact = p_dev_contact,
        latest_version = p_latest_version,
        apk_download_url = p_apk_url,
        updated_at = NOW()
    WHERE id = 1;

    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.super_admin_set_coach_status(
    p_master_pin TEXT,
    p_coach_id UUID,
    p_approve BOOLEAN,
    p_suspend BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_verified_super_admin(p_master_pin) THEN
        RAISE EXCEPTION 'Unauthorized Super-Admin Access';
    END IF;

    UPDATE public.coach_profiles
    SET is_approved = p_approve,
        is_suspended = p_suspend
    WHERE id = p_coach_id;

    RETURN TRUE;
END;
$$;

-- تابع امن دریافت لیست مربیان مخصوص کنسول سوپر-ادمین (چون دسترسی مستقیم SELECT روی coach_profiles بسته شد)
CREATE OR REPLACE FUNCTION public.super_admin_list_coaches(p_master_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_result JSONB;
BEGIN
    IF NOT public.is_verified_super_admin(p_master_pin) THEN
        RAISE EXCEPTION 'Unauthorized Super-Admin Access';
    END IF;

    SELECT COALESCE(jsonb_agg(c ORDER BY c.created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM public.coach_profiles c;

    RETURN v_result;
END;
$$;

-- اصلاح تریگرهای سیستمی با SET search_path = public, pg_temp (رفع CWE-426)
CREATE OR REPLACE FUNCTION public.handle_new_coach_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
    WHERE id = NEW.id;

    INSERT INTO public.coach_profiles (id, email, first_name, last_name, is_approved, is_suspended)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
        FALSE,
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_assign_coach_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.coach_id IS NULL AND auth.uid() IS NOT NULL THEN
        NEW.coach_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.super_admin_list_coaches(TEXT) TO anon, authenticated;

-- Grant EXECUTE permissions for athlete chat RPCs to both anon and authenticated roles
GRANT EXECUTE ON FUNCTION public.athlete_fetch_chat(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_send_chat(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

