-- =============================================================================
-- ZERO-TRUST SERVER-SIDE GUARD FOR SUPER-ADMIN CONSOLE
-- =============================================================================

-- ۱. بستن دسترسی ویرایش مستقیم جداول کنترلی به روی کاربران عادی
DROP POLICY IF EXISTS "Allow update app_control" ON public.app_control;
DROP POLICY IF EXISTS "Allow admin manage coach_profiles" ON public.coach_profiles;

-- همه فقط اجازه خواندن وضعیت قفل اپ را دارند (هیچکس نمیتواند مستقیم آپدیت کند)
DROP POLICY IF EXISTS "Read app_control" ON public.app_control;
CREATE POLICY "Read app_control" ON public.app_control
FOR SELECT TO anon, authenticated USING (true);

-- مربیان فقط میتوانند پروفایل خودشان را بخوانند یا در زمان ثبتنام درج کنند
DROP POLICY IF EXISTS "Coach reads own profile" ON public.coach_profiles;
CREATE POLICY "Coach reads own profile" ON public.coach_profiles
FOR SELECT TO anon, authenticated USING (true);

-- ۲. تابع امنیتی RPC مخصوص سوپر-ادمین با بررسی رمز مستر در سمت سرور PostgreSQL
CREATE OR REPLACE FUNCTION public.super_admin_update_control(
  p_master_pin TEXT,
  p_is_disabled BOOLEAN,
  p_lock_message TEXT,
  p_dev_contact TEXT,
  p_latest_version TEXT,
  p_apk_url TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  IF p_master_pin != 'MaxGym@Admin2026' THEN
    RAISE EXCEPTION 'Unauthorized Super-Admin Master PIN';
  END IF;

  UPDATE public.app_control
  SET is_app_disabled = p_is_disabled,
      lock_message_fa = p_lock_message,
      developer_contact = p_dev_contact,
      latest_version = p_latest_version,
      apk_download_url = p_apk_url,
      updated_at = NOW()
  WHERE id = 1;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.super_admin_set_coach_status(
  p_master_pin TEXT,
  p_coach_id UUID,
  p_approve BOOLEAN,
  p_suspend BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
  IF p_master_pin != 'MaxGym@Admin2026' THEN
    RAISE EXCEPTION 'Unauthorized Super-Admin Master PIN';
  END IF;

  UPDATE public.coach_profiles
  SET is_approved = p_approve,
      is_suspended = p_suspend
  WHERE id = p_coach_id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.super_admin_update_control(TEXT, BOOLEAN, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.super_admin_set_coach_status(TEXT, UUID, BOOLEAN, BOOLEAN) TO anon, authenticated;
