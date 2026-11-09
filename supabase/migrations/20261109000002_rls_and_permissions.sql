-- =============================================================================
-- SUPABASE RLS, PERMISSIONS & CONSTRAINT MIGRATION SCRIPT
-- =============================================================================

-- ۱. فعال‌سازی دسترسی کامل برای کلید عمومی (anon / publishableKey) در فاز تک‌کاربره
ALTER TABLE public.athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.measurement_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_heartbeat ENABLE ROW LEVEL SECURITY;

-- حذف پالیسی‌های قدیمی در صورت وجود برای جلوگیری از تداخل
DROP POLICY IF EXISTS "Allow full access to athletes" ON public.athletes;
DROP POLICY IF EXISTS "Allow full access to measurement_logs" ON public.measurement_logs;
DROP POLICY IF EXISTS "Allow full access to programs" ON public.programs;
DROP POLICY IF EXISTS "Allow full access to app_heartbeat" ON public.app_heartbeat;

-- ایجاد پالیسی دسترسی خواندن و نوشتن (CRUD) برای اپلیکیشن موبایل
CREATE POLICY "Allow full access to athletes"
ON public.athletes FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to measurement_logs"
ON public.measurement_logs FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to programs"
ON public.programs FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to app_heartbeat"
ON public.app_heartbeat FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

-- اعطای مجوزهای سطح جدول به نقش anon
GRANT ALL ON TABLE public.athletes TO anon, authenticated;
GRANT ALL ON TABLE public.measurement_logs TO anon, authenticated;
GRANT ALL ON TABLE public.programs TO anon, authenticated;
GRANT ALL ON TABLE public.app_heartbeat TO anon, authenticated;

-- ۲. اطمینان از اینکه جدول programs به قالب‌های آماده (Templates) اجازه ماندگاری دائمی می‌دهد
ALTER TABLE public.programs DROP CONSTRAINT IF EXISTS programs_athlete_id_fkey;
