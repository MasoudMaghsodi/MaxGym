-- =============================================================================
-- MIGRATION 13: ONE-TIME ACCESS CODE BURN, ATHLETE EMAIL+PASSWORD AUTH & RESET
-- =============================================================================

-- ۱. افزودن ستون‌های رمز عبور، وضعیت ابطال کد یکبارمصرف و آواتار به جدول ورزشکاران
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS password_hash TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS is_code_burned BOOLEAN DEFAULT FALSE;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';

-- ۲. تابع فعال‌سازی اولیه با کد یکبارمصرف (PC-XXXXXX) -> اگر قبلاً باطل شده باشد خطا می‌دهد
CREATE OR REPLACE FUNCTION public.athlete_login_by_code(p_access_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_input TEXT;
  v_clean_code TEXT;
  v_athlete RECORD;
  v_programs JSONB;
  v_measurements JSONB;
BEGIN
  v_input := TRIM(p_access_code);
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

  -- اگر کد یکبارمصرف قبلاً استفاده و باطل شده باشد، اجازه ورود بدون رمز را نمی‌دهد!
  IF COALESCE(v_athlete.is_code_burned, FALSE) = TRUE AND COALESCE(v_athlete.password_hash, '') != '' THEN
    RETURN jsonb_build_object(
      'error', 'CODE_BURNED',
      'message', 'این کد دعوت یکبارمصرف قبلاً استفاده و باطل شده است. لطفاً با ایمیل و رمز عبور خود وارد شوید.'
    );
  END IF;

  SELECT COALESCE(jsonb_agg(p ORDER BY p.start_date DESC), '[]'::jsonb)
  INTO v_programs
  FROM public.programs p
  WHERE p.athlete_id = v_athlete.id AND p.is_template = FALSE;

  SELECT COALESCE(jsonb_agg(m ORDER BY m.recorded_at ASC), '[]'::jsonb)
  INTO v_measurements
  FROM public.measurement_logs m
  WHERE m.athlete_id = v_athlete.id;

  RETURN jsonb_build_object(
    'athlete', to_jsonb(v_athlete),
    'programs', v_programs,
    'measurements', v_measurements
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۳. تابع ورود دائمی ورزشکار با ایمیل یا شماره موبایل + رمز عبور
CREATE OR REPLACE FUNCTION public.athlete_login_with_password(
  p_identifier TEXT,
  p_password_hash TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_clean TEXT;
  v_athlete RECORD;
  v_programs JSONB;
  v_measurements JSONB;
BEGIN
  v_clean := LOWER(TRIM(p_identifier));

  SELECT * INTO v_athlete
  FROM public.athletes
  WHERE is_deleted = FALSE
    AND (LOWER(TRIM(email)) = v_clean OR TRIM(phone) = v_clean)
    AND password_hash = TRIM(p_password_hash)
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_athlete IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(jsonb_agg(p ORDER BY p.start_date DESC), '[]'::jsonb)
  INTO v_programs
  FROM public.programs p
  WHERE p.athlete_id = v_athlete.id AND p.is_template = FALSE;

  SELECT COALESCE(jsonb_agg(m ORDER BY m.recorded_at ASC), '[]'::jsonb)
  INTO v_measurements
  FROM public.measurement_logs m
  WHERE m.athlete_id = v_athlete.id;

  RETURN jsonb_build_object(
    'athlete', to_jsonb(v_athlete),
    'programs', v_programs,
    'measurements', v_measurements
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۴. تابع تکمیل پروفایل، ثبت رمز عبور و ابطال دائمی کد یکبارمصرف (Burn Code)
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
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.athletes
  SET first_name = p_first_name,
      last_name = p_last_name,
      phone = p_phone,
      email = LOWER(TRIM(p_email)),
      password_hash = TRIM(p_password_hash),
      is_code_burned = TRUE, -- ابطال دائمی کد دعوت پس از اولین استفاده
      age = p_age,
      height_cm = p_height_cm,
      weight_kg = p_weight_kg,
      updated_at = NOW()
  WHERE id = p_athlete_id;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۵. تابع بازیابی رمز عبور ورزشکار (تطابق همزمان ایمیل + شماره موبایل ثبت‌شده)
CREATE OR REPLACE FUNCTION public.athlete_reset_password_by_verification(
  p_email TEXT,
  p_phone TEXT,
  p_new_password_hash TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.athletes
  SET password_hash = TRIM(p_new_password_hash),
      is_code_burned = TRUE,
      updated_at = NOW()
  WHERE is_deleted = FALSE
    AND LOWER(TRIM(email)) = LOWER(TRIM(p_email))
    AND TRIM(phone) = TRIM(p_phone);

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.athlete_login_by_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_login_with_password(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_activate_and_burn_code(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_reset_password_by_verification(TEXT, TEXT, TEXT) TO anon, authenticated;
