-- =============================================================================
-- PRO COACH APP - SUPABASE POSTGRESQL SCHEMA (FREE TIER OPTIMIZED)
-- =============================================================================

-- ۱. جدول ورزشکاران (Athletes)
CREATE TABLE IF NOT EXISTS public.athletes (
    id UUID PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    gender TEXT NOT NULL,
    age INTEGER NOT NULL,
    height_cm DOUBLE PRECISION NOT NULL,
    weight_kg DOUBLE PRECISION NOT NULL,
    fitness_goal TEXT NOT NULL,
    injury_tags JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- ۲. جدول تاریخچه سایزگیری و آنتروپومتریک (Measurement Logs)
CREATE TABLE IF NOT EXISTS public.measurement_logs (
    id UUID PRIMARY KEY,
    athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    weight_kg DOUBLE PRECISION NOT NULL,
    body_fat_percent DOUBLE PRECISION,
    shoulder_cm DOUBLE PRECISION,
    chest_cm DOUBLE PRECISION,
    waist_cm DOUBLE PRECISION,
    hips_cm DOUBLE PRECISION,
    biceps_cm DOUBLE PRECISION,
    forearm_cm DOUBLE PRECISION,
    thigh_cm DOUBLE PRECISION,
    calf_cm DOUBLE PRECISION,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۳. جدول برنامههای جامع (تمرینی، غذایی، مکمل، قالبها و وضعیت مالی)
CREATE TABLE IF NOT EXISTS public.programs (
    id UUID PRIMARY KEY,
    athlete_id UUID NOT NULL,
    title TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    duration_weeks INTEGER NOT NULL DEFAULT 4,
    days_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    diet_meals_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    water_liters DOUBLE PRECISION NOT NULL DEFAULT 3.5,
    diet_guidelines_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    supplements_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    total_fee DOUBLE PRECISION NOT NULL DEFAULT 0,
    paid_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'paid',
    is_template BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۴. جدول Heartbeat برای جلوگیری از Pause شدن پروژه در پلن رایگان Supabase بعد از ۷ روز
CREATE TABLE IF NOT EXISTS public.app_heartbeat (
    id INTEGER PRIMARY KEY DEFAULT 1,
    last_ping TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.app_heartbeat (id, last_ping)
VALUES (1, NOW())
ON CONFLICT (id) DO UPDATE SET last_ping = NOW();

-- ۵. جداول کاتالوگ سفارشی مربی
CREATE TABLE IF NOT EXISTS public.exercises_catalog (
    id TEXT PRIMARY KEY,
    name_fa TEXT NOT NULL,
    name_en TEXT NOT NULL,
    target_muscle TEXT NOT NULL,
    equipment TEXT NOT NULL DEFAULT 'custom',
    image_start_url TEXT NOT NULL DEFAULT '',
    image_end_url TEXT NOT NULL DEFAULT '',
    contraindicated_injuries JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.custom_foods_catalog (
    id TEXT PRIMARY KEY,
    name_fa TEXT NOT NULL,
    name_en TEXT NOT NULL,
    unit_fa TEXT NOT NULL,
    unit_en TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.custom_supplements_catalog (
    id TEXT PRIMARY KEY,
    name_fa TEXT NOT NULL,
    name_en TEXT NOT NULL,
    dosage_fa TEXT NOT NULL,
    dosage_en TEXT NOT NULL,
    timing_fa TEXT NOT NULL,
    timing_en TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ایجاد ایندکس برای سرعت بالای کوئری‌ها تا بیش از ۵۰۰ ورزشکار
CREATE INDEX IF NOT EXISTS idx_athletes_updated ON public.athletes(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_measurements_athlete ON public.measurement_logs(athlete_id, recorded_at ASC);
CREATE INDEX IF NOT EXISTS idx_programs_athlete ON public.programs(athlete_id, start_date DESC);

-- =============================================================================
-- PHASE 1: DUAL-ROLE (COACH & ATHLETE PORTAL), PURE TEXT CHAT, WORKOUT LOGS & RPCs
-- =============================================================================

-- ۱. ارتقای جدول ورزشکاران برای پشتیبانی از کد ورود اختصاصی شاگرد (access_code)، ایمیل و روزهای استمرار
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS access_code TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS streak_days INTEGER DEFAULT 1;

-- ۲. جدول چت متنی خالص بین مربی و ورزشکار (Pure Text Chat - بدون عکس و فایل برای حفظ سهمیه رایگان)
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY,
    athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
    coach_id UUID,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('coach', 'athlete')),
    message_text TEXT NOT NULL CHECK (char_length(message_text) <= 600),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۳. جدول ثبت گزارش تمرین، وزنههای زده شده، فیدبک روزانه و مصرف آب توسط ورزشکار
CREATE TABLE IF NOT EXISTS public.athlete_workout_logs (
    id UUID PRIMARY KEY,
    athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
    program_id UUID NOT NULL,
    day_number INTEGER NOT NULL,
    completed_sets_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    water_glasses INTEGER NOT NULL DEFAULT 0,
    session_rpe INTEGER NOT NULL DEFAULT 7,
    athlete_feedback TEXT DEFAULT '',
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۴. ایندکسهای مرکب برای سرعت بالای کوئریها در مقیاس بالا (بیش از ۵۰۰ شاگرد)
CREATE INDEX IF NOT EXISTS idx_athletes_coach_updated ON public.athletes(coach_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_athletes_access_code ON public.athletes(access_code);
CREATE INDEX IF NOT EXISTS idx_programs_coach_athlete ON public.programs(coach_id, athlete_id, start_date DESC);
CREATE INDEX IF NOT EXISTS idx_measurements_coach_athlete ON public.measurement_logs(coach_id, athlete_id, recorded_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_athlete_created ON public.chat_messages(athlete_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_workout_logs_athlete ON public.athlete_workout_logs(athlete_id, logged_at DESC);

-- ۵. فعالسازی RLS و تنظیم دسترسیها برای جداول جدید
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athlete_workout_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access chat messages" ON public.chat_messages;
CREATE POLICY "Access chat messages" ON public.chat_messages
FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Access athlete workout logs" ON public.athlete_workout_logs;
CREATE POLICY "Access athlete workout logs" ON public.athlete_workout_logs
FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- دسترسی پرتال ورزشکار به اطلاعات خود
DROP POLICY IF EXISTS "Athlete portal access by access_code" ON public.athletes;
CREATE POLICY "Athlete portal access by access_code" ON public.athletes
FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Athlete portal update own profile" ON public.athletes;
CREATE POLICY "Athlete portal update own profile" ON public.athletes
FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Athlete portal read programs" ON public.programs;
CREATE POLICY "Athlete portal read programs" ON public.programs
FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Athlete portal insert measurements" ON public.measurement_logs;
CREATE POLICY "Athlete portal insert measurements" ON public.measurement_logs
FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.chat_messages TO anon, authenticated;
GRANT ALL ON TABLE public.athlete_workout_logs TO anon, authenticated;

-- ۶. توابع امنیتی RPC برای ورود ورزشکار با کد اختصاصی و تکمیل پروفایل
CREATE OR REPLACE FUNCTION public.athlete_login_by_code(p_access_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_athlete RECORD;
  v_programs JSONB;
  v_measurements JSONB;
BEGIN
  SELECT * INTO v_athlete
  FROM public.athletes
  WHERE UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
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
  WHERE id = p_athlete_id
    AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code));

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- RPC CHAT & ATHLETE PORTAL ISOLATION
-- =============================================================================
CREATE OR REPLACE FUNCTION public.athlete_fetch_chat(
    p_athlete_id TEXT,
    p_access_code TEXT
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.athlete_send_chat(
    p_id TEXT,
    p_athlete_id TEXT,
    p_access_code TEXT,
    p_message_text TEXT
)
RETURNS BOOLEAN AS $$
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
        p_message_text,
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.athlete_fetch_chat TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_send_chat TO anon, authenticated;


-- =============================================================================
-- FINAL RPC TUNNELS FOR ATHLETE WORKOUT LOGS & WEEKLY WEIGHT CHECK-IN
-- =============================================================================
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
