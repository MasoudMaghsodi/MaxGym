-- =============================================================================
-- REALTIME SYNC + MULTI-METHOD ATHLETE LOGIN (CODE / PHONE / EMAIL) + PROFILE FIX
-- =============================================================================

-- ۱. فعالسازی قطعی Realtime WebSocket روی جداول برنامهها، چت، ورزشکاران و کنترل اپ
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.programs; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.athletes; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.app_control; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_profiles; EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ۲. تابع ورود هوشمند ورزشکار: پشتیبانی همزمان از «کد اختصاصی»، «شماره موبایل» یا «ایمیل»!
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
      OR (LENGTH(v_input) >= 8 AND TRIM(phone) = v_input)
      OR (POSITION('@' IN v_input) > 1 AND LOWER(TRIM(email)) = LOWER(v_input))
    )
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

-- ۳. تابع تکمیل پروفایل ورزشکار (۹ پارامتر دقیق)
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
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.athletes
  SET first_name = p_first_name,
      last_name = p_last_name,
      phone = p_phone,
      email = p_email,
      age = p_age,
      height_cm = p_height_cm,
      weight_kg = p_weight_kg,
      updated_at = NOW()
  WHERE id = p_athlete_id;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۴. اعطای مجوز اجرا با امضای دقیق ۹ پارامتری (۱ عدد UUID + ۵ عدد TEXT + ۱ عدد INTEGER + ۲ عدد DOUBLE PRECISION)
GRANT EXECUTE ON FUNCTION public.athlete_login_by_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_complete_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;
