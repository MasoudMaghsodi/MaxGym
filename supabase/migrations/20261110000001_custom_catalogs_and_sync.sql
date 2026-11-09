-- =============================================================================
-- FINAL SUPABASE SCHEMA & RLS UPDATE (CUSTOM CATALOGS + FULL SYNC)
-- =============================================================================

-- ۱. ساخت جداول بانک‌های سفارشی مربی در فضای ابری (برای بکاپ حرکات، غذاها و مکمل‌های سفارشی)
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

-- ۲. حذف محدودیت کلید خارجی جدول programs برای ماندگاری دائمی قالب‌های آماده (Templates)
ALTER TABLE public.programs DROP CONSTRAINT IF EXISTS programs_athlete_id_fkey;

-- ۳. فعال‌سازی RLS و اعطای دسترسی کامل CRUD به کلید اپلیکیشن (anon / publishableKey)
ALTER TABLE public.athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.measurement_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_heartbeat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_foods_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_supplements_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow full access to athletes" ON public.athletes;
DROP POLICY IF EXISTS "Allow full access to measurement_logs" ON public.measurement_logs;
DROP POLICY IF EXISTS "Allow full access to programs" ON public.programs;
DROP POLICY IF EXISTS "Allow full access to app_heartbeat" ON public.app_heartbeat;
DROP POLICY IF EXISTS "Allow full access to exercises_catalog" ON public.exercises_catalog;
DROP POLICY IF EXISTS "Allow full access to custom_foods_catalog" ON public.custom_foods_catalog;
DROP POLICY IF EXISTS "Allow full access to custom_supplements_catalog" ON public.custom_supplements_catalog;

CREATE POLICY "Allow full access to athletes" ON public.athletes FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access to measurement_logs" ON public.measurement_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access to programs" ON public.programs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access to app_heartbeat" ON public.app_heartbeat FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access to exercises_catalog" ON public.exercises_catalog FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access to custom_foods_catalog" ON public.custom_foods_catalog FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access to custom_supplements_catalog" ON public.custom_supplements_catalog FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.athletes TO anon, authenticated;
GRANT ALL ON TABLE public.measurement_logs TO anon, authenticated;
GRANT ALL ON TABLE public.programs TO anon, authenticated;
GRANT ALL ON TABLE public.app_heartbeat TO anon, authenticated;
GRANT ALL ON TABLE public.exercises_catalog TO anon, authenticated;
GRANT ALL ON TABLE public.custom_foods_catalog TO anon, authenticated;
GRANT ALL ON TABLE public.custom_supplements_catalog TO anon, authenticated;
