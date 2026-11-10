-- =============================================================================
-- MIGRATION 12: MULTI-TENANT COACH ISOLATION + AUTO COACH_ID TRIGGER
-- =============================================================================

-- ۱. تریگر خودکار برای ست کردن coach_id هنگام درج رکورد توسط مربی (جلوگیری از خطای 42501)
CREATE OR REPLACE FUNCTION public.auto_assign_coach_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.coach_id IS NULL AND auth.uid() IS NOT NULL THEN
    NEW.coach_id := auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_athletes_coach_id ON public.athletes;
CREATE TRIGGER trg_athletes_coach_id
  BEFORE INSERT ON public.athletes
  FOR EACH ROW EXECUTE FUNCTION public.auto_assign_coach_id();

DROP TRIGGER IF EXISTS trg_programs_coach_id ON public.programs;
CREATE TRIGGER trg_programs_coach_id
  BEFORE INSERT ON public.programs
  FOR EACH ROW EXECUTE FUNCTION public.auto_assign_coach_id();

DROP TRIGGER IF EXISTS trg_measurements_coach_id ON public.measurement_logs;
CREATE TRIGGER trg_measurements_coach_id
  BEFORE INSERT ON public.measurement_logs
  FOR EACH ROW EXECUTE FUNCTION public.auto_assign_coach_id();

DROP TRIGGER IF EXISTS trg_chats_coach_id ON public.chat_messages;
CREATE TRIGGER trg_chats_coach_id
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.auto_assign_coach_id();

-- ۲. محدود کردن دسترسی جدول لاگها (ثبت لاگ برای همه مجاز، خواندن فقط برای مربیان تاییدشده)
DROP POLICY IF EXISTS "Allow insert and read app_logs" ON public.app_logs;
DROP POLICY IF EXISTS "Allow insert app_logs" ON public.app_logs;
DROP POLICY IF EXISTS "Allow read app_logs" ON public.app_logs;

CREATE POLICY "Allow insert app_logs" ON public.app_logs
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Allow read app_logs" ON public.app_logs
  FOR SELECT TO authenticated
  USING (public.is_active_approved_coach());
