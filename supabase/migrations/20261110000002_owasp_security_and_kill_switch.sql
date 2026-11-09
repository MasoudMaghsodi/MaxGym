-- =============================================================================
-- OWASP HARDENED SUPABASE SECURITY, ADMIN APPROVAL & KILL-SWITCH SCHEMA
-- =============================================================================

-- ۱. جدول کنترل سراسری اپلیکیشن توسط توسعهدهنده (Global App Kill-Switch)
CREATE TABLE IF NOT EXISTS public.app_control (
    id INTEGER PRIMARY KEY DEFAULT 1,
    is_app_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    lock_title_fa TEXT NOT NULL DEFAULT 'دسترسی به اپلیکیشن مسدود شده است',
    lock_message_fa TEXT NOT NULL DEFAULT 'به دلیل عدم تسویه حساب یا پایان اعتبار لایسنس، دسترسی به سامانه غیرفعال گردیده است. لطفاً با توسعهدهنده تماس بگیرید.',
    developer_contact TEXT NOT NULL DEFAULT 'Telegram / Support: @YourDeveloperID',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.app_control (id, is_app_disabled)
VALUES (1, FALSE)
ON CONFLICT (id) DO NOTHING;

-- ۲. جدول پروفایل مربیان (شامل تایید ادمین و سوییچ قطع دسترسی تکی)
CREATE TABLE IF NOT EXISTS public.coach_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,  -- شما باید در پنل سوپابیس این را TRUE کنید تا مربی وارد شود
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE, -- اگر TRUE کنید، اپ مربی فوراً قفل میشود
    lock_reason TEXT DEFAULT 'حساب کاربری شما توسط مدیریت مسدود شده است. جهت بررسی یا تسویه حساب با توسعهدهنده تماس بگیرید.',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۳. تریگر خودکار: به محض ثبتنام مربی در اپ، پروفایلش با وضعیت در انتظار تایید (is_approved = false) ساخته میشود
CREATE OR REPLACE FUNCTION public.handle_new_coach_signup()
RETURNS TRIGGER AS $$
BEGIN
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_coach_signup();

-- ۴. افزودن ستون coach_id به تمام جداول برای ایزولاسیون کامل دادههای هر مربی
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS coach_id UUID DEFAULT auth.uid();
ALTER TABLE public.measurement_logs ADD COLUMN IF NOT EXISTS coach_id UUID DEFAULT auth.uid();
ALTER TABLE public.programs ADD COLUMN IF NOT EXISTS coach_id UUID DEFAULT auth.uid();
ALTER TABLE public.exercises_catalog ADD COLUMN IF NOT EXISTS coach_id UUID DEFAULT auth.uid();
ALTER TABLE public.custom_foods_catalog ADD COLUMN IF NOT EXISTS coach_id UUID DEFAULT auth.uid();
ALTER TABLE public.custom_supplements_catalog ADD COLUMN IF NOT EXISTS coach_id UUID DEFAULT auth.uid();

-- ۵. تابع امنیتی سطح هسته (OWASP M3): بررسی همزمان JWT، تایید ادمین، عدم مسدودیت مربی و عدم قفل سراسری اپ
CREATE OR REPLACE FUNCTION public.is_active_approved_coach()
RETURNS BOOLEAN AS $$
DECLARE
  v_app_disabled BOOLEAN;
  v_approved BOOLEAN;
  v_suspended BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT is_app_disabled INTO v_app_disabled FROM public.app_control WHERE id = 1;
  IF COALESCE(v_app_disabled, FALSE) = TRUE THEN
    RETURN FALSE;
  END IF;

  SELECT is_approved, is_suspended INTO v_approved, v_suspended
  FROM public.coach_profiles
  WHERE id = auth.uid();

  RETURN (COALESCE(v_approved, FALSE) = TRUE) AND (COALESCE(v_suspended, TRUE) = FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۶. قفل کردن کامل Row Level Security (RLS)؛ هیچ درخواستی بدون توکن معتبر و تایید ادمین رد و بدل نمیشود!
ALTER TABLE public.app_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.measurement_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_heartbeat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_foods_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_supplements_catalog ENABLE ROW LEVEL SECURITY;

-- حذف پالیسیهای باز قبلی (anon)
DROP POLICY IF EXISTS "Allow full access to athletes" ON public.athletes;
DROP POLICY IF EXISTS "Allow full access to measurement_logs" ON public.measurement_logs;
DROP POLICY IF EXISTS "Allow full access to programs" ON public.programs;
DROP POLICY IF EXISTS "Allow full access to app_heartbeat" ON public.app_heartbeat;
DROP POLICY IF EXISTS "Allow full access to exercises_catalog" ON public.exercises_catalog;
DROP POLICY IF EXISTS "Allow full access to custom_foods_catalog" ON public.custom_foods_catalog;
DROP POLICY IF EXISTS "Allow full access to custom_supplements_catalog" ON public.custom_supplements_catalog;

-- پالیسی خواندن وضعیت قفل اپ و پروفایل خود مربی
DROP POLICY IF EXISTS "Read app_control" ON public.app_control;
CREATE POLICY "Read app_control" ON public.app_control FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Coach reads own profile" ON public.coach_profiles;
CREATE POLICY "Coach reads own profile" ON public.coach_profiles
FOR SELECT TO authenticated USING (id = auth.uid());

-- پالیسیهای فوق امنیتی جداول عملیاتی (فقط مربی تاییدشده و غیرمسدود، و فقط به دادههای خودش دسترسی دارد)
DROP POLICY IF EXISTS "Secure coach access athletes" ON public.athletes;
CREATE POLICY "Secure coach access athletes" ON public.athletes
FOR ALL TO authenticated
USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access measurements" ON public.measurement_logs;
CREATE POLICY "Secure coach access measurements" ON public.measurement_logs
FOR ALL TO authenticated
USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access programs" ON public.programs;
CREATE POLICY "Secure coach access programs" ON public.programs
FOR ALL TO authenticated
USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access exercises" ON public.exercises_catalog;
CREATE POLICY "Secure coach access exercises" ON public.exercises_catalog
FOR ALL TO authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access foods" ON public.custom_foods_catalog;
CREATE POLICY "Secure coach access foods" ON public.custom_foods_catalog
FOR ALL TO authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access supplements" ON public.custom_supplements_catalog;
CREATE POLICY "Secure coach access supplements" ON public.custom_supplements_catalog
FOR ALL TO authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure heartbeat" ON public.app_heartbeat;
CREATE POLICY "Secure heartbeat" ON public.app_heartbeat
FOR ALL TO authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());
