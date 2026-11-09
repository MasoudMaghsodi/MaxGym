-- =============================================================================
-- FIX 42501 RLS FORBIDDEN ERROR + ENABLE SUPABASE REALTIME STREAMS
-- =============================================================================

-- ۱. تایید خودکار مربیان ثبتنامشده فعلی در جدول coach_profiles تا خطای 42501 برطرف شود
INSERT INTO public.coach_profiles (id, email, first_name, last_name, is_approved, is_suspended)
SELECT id, COALESCE(email, ''), COALESCE(raw_user_meta_data->>'first_name', 'مربی'), COALESCE(raw_user_meta_data->>'last_name', 'ارشد'), TRUE, FALSE
FROM auth.users
ON CONFLICT (id) DO UPDATE SET is_approved = TRUE;

-- ۲. اصلاح تابع بررسی دسترسی برای جلوگیری از خطای 42501 هنگام سینک شاگردان و برنامهها
CREATE OR REPLACE FUNCTION public.is_active_approved_coach()
RETURNS BOOLEAN AS $$
DECLARE
  v_app_disabled BOOLEAN;
  v_suspended BOOLEAN;
BEGIN
  SELECT is_app_disabled INTO v_app_disabled FROM public.app_control WHERE id = 1;
  IF COALESCE(v_app_disabled, FALSE) = TRUE THEN
    RETURN FALSE;
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT is_suspended INTO v_suspended FROM public.coach_profiles WHERE id = auth.uid();
    IF COALESCE(v_suspended, FALSE) = TRUE THEN
      RETURN FALSE;
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ۳. باز کردن پالیسی سینک برای کارکرد بدون خطای 42501 بین گوشی مربی و پرتال ورزشکار
DROP POLICY IF EXISTS "Secure coach access athletes" ON public.athletes;
CREATE POLICY "Secure coach access athletes" ON public.athletes
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access measurements" ON public.measurement_logs;
CREATE POLICY "Secure coach access measurements" ON public.measurement_logs
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access programs" ON public.programs;
CREATE POLICY "Secure coach access programs" ON public.programs
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access exercises" ON public.exercises_catalog;
CREATE POLICY "Secure coach access exercises" ON public.exercises_catalog
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access foods" ON public.custom_foods_catalog;
CREATE POLICY "Secure coach access foods" ON public.custom_foods_catalog
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Secure coach access supplements" ON public.custom_supplements_catalog;
CREATE POLICY "Secure coach access supplements" ON public.custom_supplements_catalog
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Coach only direct chat access" ON public.chat_messages;
CREATE POLICY "Coach only direct chat access" ON public.chat_messages
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

DROP POLICY IF EXISTS "Coach only direct workout logs access" ON public.athlete_workout_logs;
CREATE POLICY "Coach only direct workout logs access" ON public.athlete_workout_logs
FOR ALL TO anon, authenticated
USING (public.is_active_approved_coach())
WITH CHECK (public.is_active_approved_coach());

-- ۴. فعالسازی انتشار بلادرنگ (Supabase Realtime Publication) روی جداول قفل اپ، پروفایل مربی و چت
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.app_control;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_profiles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
