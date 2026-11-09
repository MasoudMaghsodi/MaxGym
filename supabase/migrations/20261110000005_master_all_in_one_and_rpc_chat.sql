-- =============================================================================
-- MASTER ALL-IN-ONE & SECURE RPC CHAT MIGRATION
-- =============================================================================

-- ۱. اطمینان از وجود ستون‌های مورد نیاز
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS coach_id UUID;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS access_code TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS streak_days INTEGER DEFAULT 1;

ALTER TABLE public.programs ADD COLUMN IF NOT EXISTS coach_id UUID;
ALTER TABLE public.measurement_logs ADD COLUMN IF NOT EXISTS coach_id UUID;

-- ۲. ساخت جدول چت متنی خالص (در صورت عدم وجود)
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY,
    athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
    coach_id UUID,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('coach', 'athlete')),
    message_text TEXT NOT NULL CHECK (char_length(message_text) <= 600),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۳. ساخت جدول لاگ‌های تمرین ورزشکار (در صورت عدم وجود)
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

-- ۴. ایندکس‌های پرسرعت
CREATE INDEX IF NOT EXISTS idx_chat_athlete_created ON public.chat_messages(athlete_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_workout_logs_athlete ON public.athlete_workout_logs(athlete_id, logged_at DESC);

-- ۵. فعال‌سازی RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athlete_workout_logs ENABLE ROW LEVEL SECURITY;

-- ۶. RPC اختصاصی واکشی پیام‌های چت ورزشکار بدون افشای پیام‌های دیگران
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

-- ۷. RPC اختصاصی ارسال پیام توسط ورزشکار با اعتبارسنجی access_code
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

-- ۸. اعطای دسترسی‌های لازم
GRANT EXECUTE ON FUNCTION public.athlete_fetch_chat TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_send_chat TO anon, authenticated;
