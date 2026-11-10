-- =============================================================================
-- PHASE 2 SQL: SUPABASE CRASH TELEMETRY (app_logs), DEVICE FINGERPRINT & VERSIONING
-- =============================================================================

-- ۱. افزودن فیلدهای مدیریت نسخه و لینک دانلود به جدول app_control برای پنل سوپر-ادمین
ALTER TABLE public.app_control ADD COLUMN IF NOT EXISTS latest_version TEXT DEFAULT '1.2.0';
ALTER TABLE public.app_control ADD COLUMN IF NOT EXISTS apk_download_url TEXT DEFAULT 'https://github.com/MasoudMaghsodi/MaxGym/releases/latest/download/MaxGym-Release.apk';
ALTER TABLE public.app_control ADD COLUMN IF NOT EXISTS release_notes_fa TEXT DEFAULT 'افزایش سرعت، افزودن هیتمپ سه‌بعدی عضلات و چت زنده مربی و ورزشکار';

-- ۲. افزودن ستون اثرانگشت دستگاه (Device Fingerprint) برای جلوگیری از اشتراک‌گذاری غیرمجاز اکانت
ALTER TABLE public.coach_profiles ADD COLUMN IF NOT EXISTS bound_device_id TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS bound_device_id TEXT DEFAULT '';

-- ۳. جدول تلمتری و ثبت خودکار کرش و باگ‌ها (جایگزین بومی و بدون تحریم Firebase Crashlytics)
CREATE TABLE IF NOT EXISTS public.app_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    level TEXT NOT NULL DEFAULT 'error', -- 'error', 'warning', 'security'
    error_message TEXT NOT NULL,
    stack_trace TEXT DEFAULT '',
    platform_info TEXT DEFAULT '',
    user_context TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow insert and read app_logs" ON public.app_logs;
CREATE POLICY "Allow insert and read app_logs" ON public.app_logs
FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update app_control" ON public.app_control;
CREATE POLICY "Allow update app_control" ON public.app_control
FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow admin manage coach_profiles" ON public.coach_profiles;
CREATE POLICY "Allow admin manage coach_profiles" ON public.coach_profiles
FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.app_logs TO anon, authenticated;
GRANT ALL ON TABLE public.app_control TO anon, authenticated;
GRANT ALL ON TABLE public.coach_profiles TO anon, authenticated;
