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

