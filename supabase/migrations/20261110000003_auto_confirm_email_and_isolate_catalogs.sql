-- =============================================================================
-- FINAL NEEDLE-AUDIT SQL FIX: AUTO-CONFIRM EMAIL ON SIGNUP & ISOLATE CATALOGS
-- =============================================================================

-- ۱. ارتقای تریگر ثبتنام: تایید خودکار ایمیل مربی در لحظه ثبتنام تا فقط تیک is_approved شما ملاک ورود باشد
CREATE OR REPLACE FUNCTION public.handle_new_coach_signup()
RETURNS TRIGGER AS $$
BEGIN
  -- تایید خودکار ایمیل برای جلوگیری از قفل شدن مربی در لینک ایمیل
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
  WHERE id = NEW.id;

  -- درج پروفایل مربی با وضعیت در انتظار تایید ادمین (is_approved = false)
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

-- ۲. اصلاح پالیسی کاتالوگهای سفارشی برای جلوگیری از تداخل بین دو مربی مختلف
DROP POLICY IF EXISTS "Secure coach access exercises" ON public.exercises_catalog;
CREATE POLICY "Secure coach access exercises" ON public.exercises_catalog
FOR ALL TO authenticated
USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access foods" ON public.custom_foods_catalog;
CREATE POLICY "Secure coach access foods" ON public.custom_foods_catalog
FOR ALL TO authenticated
USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access supplements" ON public.custom_supplements_catalog;
CREATE POLICY "Secure coach access supplements" ON public.custom_supplements_catalog
FOR ALL TO authenticated
USING (public.is_active_approved_coach() AND (coach_id = auth.uid() OR coach_id IS NULL))
WITH CHECK (public.is_active_approved_coach());
