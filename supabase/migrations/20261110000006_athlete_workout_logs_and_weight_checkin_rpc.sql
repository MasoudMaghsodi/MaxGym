-- =============================================================================
-- FINAL RPC TUNNELS FOR ATHLETE WORKOUT LOGS & WEEKLY WEIGHT CHECK-IN
-- =============================================================================

-- ۱. تابع امنیتی RPC برای ثبت گزارش تمرین و رکورد وزنهها توسط ورزشکار
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
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۲. تابع امنیتی RPC برای ثبت وزن و سایز کمر جدید توسط خود ورزشکار در پرتال
CREATE OR REPLACE FUNCTION public.athlete_submit_weight_checkin(
  p_id UUID,
  p_athlete_id UUID,
  p_access_code TEXT,
  p_weight_kg DOUBLE PRECISION,
  p_waist_cm DOUBLE PRECISION
)
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.athlete_submit_workout_log TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_submit_weight_checkin TO anon, authenticated;
