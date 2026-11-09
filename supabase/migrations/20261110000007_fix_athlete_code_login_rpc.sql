-- =============================================================================
-- FIX ATHLETE CODE LOGIN RPC PERMISSIONS & FLEXIBLE CODE MATCHING
-- =============================================================================

CREATE OR REPLACE FUNCTION public.athlete_login_by_code(p_access_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_clean_input TEXT;
  v_athlete RECORD;
  v_programs JSONB;
  v_measurements JSONB;
BEGIN
  -- حذف فاصلهها و پیشوند PC- برای تطابق هوشمند (چه با PC- چه بدون PC-)
  v_clean_input := UPPER(REGEXP_REPLACE(TRIM(p_access_code), '^PC-', '', 'i'));

  SELECT * INTO v_athlete
  FROM public.athletes
  WHERE (
    UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
    OR UPPER(REGEXP_REPLACE(TRIM(access_code), '^PC-', '', 'i')) = v_clean_input
  )
  AND is_deleted = FALSE
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

-- اعطای مجوز صریح اجرای توابع RPC به کاربران ناشناس (ورزشکار قبل از لاگین)
GRANT EXECUTE ON FUNCTION public.athlete_login_by_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_complete_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_fetch_chat(UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_send_chat(UUID, UUID, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_submit_workout_log(UUID, UUID, TEXT, UUID, INTEGER, JSONB, INTEGER, INTEGER, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_submit_weight_checkin(UUID, UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;
