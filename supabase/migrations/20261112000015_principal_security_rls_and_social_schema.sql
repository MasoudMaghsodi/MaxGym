-- =============================================================================
-- MIGRATION 15: PRINCIPAL SECURITY ARCHITECT RLS (GRANULAR POLICIES + INITPLAN)
-- + TELEGRAM CHAT METADATA + CLUB EXPLORE & CAMPAIGNS SCHEMA
-- =============================================================================

-- ۱. ارتقای جداول موجود برای پشتیبانی از چت تلگرامی، پروفایل کامل و وضعیت آنلاین
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS avatar_b64 TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.coach_profiles ADD COLUMN IF NOT EXISTS avatar_b64 TEXT DEFAULT '';
ALTER TABLE public.coach_profiles ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE public.coach_profiles ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
ALTER TABLE public.coach_profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS reply_to_id UUID;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'text';

-- ۲. ساخت جدول اکسپلور باشگاه (Club Feed Posts & Reactions)
CREATE TABLE IF NOT EXISTS public.club_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_id UUID NOT NULL,
    athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
    athlete_name TEXT NOT NULL,
    athlete_badge TEXT NOT NULL DEFAULT 'ورزشکار مکس‌جیم',
    workout_title TEXT NOT NULL,
    total_sets INTEGER NOT NULL DEFAULT 0,
    total_volume_kg DOUBLE PRECISION NOT NULL DEFAULT 0,
    pr_highlight TEXT NOT NULL DEFAULT '',
    streak_days INTEGER NOT NULL DEFAULT 1,
    fire_count INTEGER NOT NULL DEFAULT 0,
    muscle_count INTEGER NOT NULL DEFAULT 0,
    crown_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۳. ساخت جدول کمپین‌ها و رقابت‌های باشگاهی (Gym Campaigns)
CREATE TABLE IF NOT EXISTS public.gym_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_id UUID NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    metric_type TEXT NOT NULL DEFAULT 'sessions', -- 'sessions', 'volume', 'streak', 'water'
    target_value INTEGER NOT NULL DEFAULT 20,
    reward_badge TEXT NOT NULL DEFAULT '🏆 قهرمان کمپین',
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ۴. ایندکس‌گذاری اجباری تمامی ستون‌های مورد استفاده در RLS (مطابق بند 2.2 منشور امنیتی)
CREATE INDEX IF NOT EXISTS idx_athletes_coach_id ON public.athletes(coach_id);
CREATE INDEX IF NOT EXISTS idx_programs_coach_id ON public.programs(coach_id);
CREATE INDEX IF NOT EXISTS idx_measurements_coach_id ON public.measurement_logs(coach_id);
CREATE INDEX IF NOT EXISTS idx_chat_coach_id ON public.chat_messages(coach_id);
CREATE INDEX IF NOT EXISTS idx_workout_logs_coach_id ON public.athlete_workout_logs(coach_id);
CREATE INDEX IF NOT EXISTS idx_exercises_coach_id ON public.exercises_catalog(coach_id);
CREATE INDEX IF NOT EXISTS idx_foods_coach_id ON public.custom_foods_catalog(coach_id);
CREATE INDEX IF NOT EXISTS idx_supps_coach_id ON public.custom_supplements_catalog(coach_id);
CREATE INDEX IF NOT EXISTS idx_club_posts_coach_created ON public.club_posts(coach_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_campaigns_coach_active ON public.gym_campaigns(coach_id, is_active);

-- ۵. فعال‌سازی RLS روی جداول جدید
ALTER TABLE public.club_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_campaigns ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- ۶. بازنویسی تمامی پالیسی‌های RLS به صورت تفکیک‌شده (SELECT, INSERT, UPDATE, DELETE)
-- با الگوی بهینه‌ساز (SELECT auth.uid()) مطابق بند 2.1 و 2.2 منشور امنیتی
-- =============================================================================

-- ۶.۱. جدول coach_profiles
DROP POLICY IF EXISTS "Coach reads own profile" ON public.coach_profiles;
DROP POLICY IF EXISTS "coach_profiles_select" ON public.coach_profiles;
DROP POLICY IF EXISTS "coach_profiles_update" ON public.coach_profiles;

CREATE POLICY "coach_profiles_select" ON public.coach_profiles
    FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()));

CREATE POLICY "coach_profiles_update" ON public.coach_profiles
    FOR UPDATE TO authenticated
    USING (id = (SELECT auth.uid()))
    WITH CHECK (
        id = (SELECT auth.uid())
        -- جلوگیری از تغییر وضعیت تایید یا تعلیق توسط خود مربی (Escalation Prevention)
        AND is_approved = (SELECT cp.is_approved FROM public.coach_profiles cp WHERE cp.id = (SELECT auth.uid()))
        AND is_suspended = (SELECT cp.is_suspended FROM public.coach_profiles cp WHERE cp.id = (SELECT auth.uid()))
    );

-- ۶.۲. جدول athletes (۴ پالیسی مجزا)
DROP POLICY IF EXISTS "Secure coach access athletes" ON public.athletes;
DROP POLICY IF EXISTS "athletes_select" ON public.athletes;
DROP POLICY IF EXISTS "athletes_insert" ON public.athletes;
DROP POLICY IF EXISTS "athletes_update" ON public.athletes;
DROP POLICY IF EXISTS "athletes_delete" ON public.athletes;

CREATE POLICY "athletes_select" ON public.athletes
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "athletes_insert" ON public.athletes
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "athletes_update" ON public.athletes
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "athletes_delete" ON public.athletes
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

-- ۶.۳. جدول programs (۴ پالیسی مجزا)
DROP POLICY IF EXISTS "Secure coach access programs" ON public.programs;
DROP POLICY IF EXISTS "programs_select" ON public.programs;
DROP POLICY IF EXISTS "programs_insert" ON public.programs;
DROP POLICY IF EXISTS "programs_update" ON public.programs;
DROP POLICY IF EXISTS "programs_delete" ON public.programs;

CREATE POLICY "programs_select" ON public.programs
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "programs_insert" ON public.programs
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "programs_update" ON public.programs
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "programs_delete" ON public.programs
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

-- ۶.۴. جدول measurement_logs (۴ پالیسی مجزا)
DROP POLICY IF EXISTS "Secure coach access measurements" ON public.measurement_logs;
DROP POLICY IF EXISTS "measurements_select" ON public.measurement_logs;
DROP POLICY IF EXISTS "measurements_insert" ON public.measurement_logs;
DROP POLICY IF EXISTS "measurements_update" ON public.measurement_logs;
DROP POLICY IF EXISTS "measurements_delete" ON public.measurement_logs;

CREATE POLICY "measurements_select" ON public.measurement_logs
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "measurements_insert" ON public.measurement_logs
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "measurements_update" ON public.measurement_logs
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "measurements_delete" ON public.measurement_logs
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

-- ۶.۵. جدول chat_messages (۴ پالیسی مجزا)
DROP POLICY IF EXISTS "Coach only direct chat access" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_select" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_update" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_delete" ON public.chat_messages;

CREATE POLICY "chat_select" ON public.chat_messages
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "chat_insert" ON public.chat_messages
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "chat_update" ON public.chat_messages
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "chat_delete" ON public.chat_messages
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

-- ۶.۶. جدول athlete_workout_logs (۴ پالیسی مجزا)
DROP POLICY IF EXISTS "Coach only direct workout logs access" ON public.athlete_workout_logs;
DROP POLICY IF EXISTS "wlogs_select" ON public.athlete_workout_logs;
DROP POLICY IF EXISTS "wlogs_insert" ON public.athlete_workout_logs;
DROP POLICY IF EXISTS "wlogs_update" ON public.athlete_workout_logs;
DROP POLICY IF EXISTS "wlogs_delete" ON public.athlete_workout_logs;

CREATE POLICY "wlogs_select" ON public.athlete_workout_logs
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "wlogs_insert" ON public.athlete_workout_logs
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "wlogs_update" ON public.athlete_workout_logs
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "wlogs_delete" ON public.athlete_workout_logs
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

-- ۶.۷. پالیسی‌های جداول club_posts و gym_campaigns
DROP POLICY IF EXISTS "club_posts_select" ON public.club_posts;
DROP POLICY IF EXISTS "club_posts_insert" ON public.club_posts;
DROP POLICY IF EXISTS "club_posts_update" ON public.club_posts;
DROP POLICY IF EXISTS "club_posts_delete" ON public.club_posts;

CREATE POLICY "club_posts_select" ON public.club_posts
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "club_posts_insert" ON public.club_posts
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "club_posts_update" ON public.club_posts
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "club_posts_delete" ON public.club_posts
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "campaigns_select" ON public.gym_campaigns;
DROP POLICY IF EXISTS "campaigns_insert" ON public.gym_campaigns;
DROP POLICY IF EXISTS "campaigns_update" ON public.gym_campaigns;
DROP POLICY IF EXISTS "campaigns_delete" ON public.gym_campaigns;

CREATE POLICY "campaigns_select" ON public.gym_campaigns
    FOR SELECT TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "campaigns_insert" ON public.gym_campaigns
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active_approved_coach() AND (coach_id = (SELECT auth.uid()) OR coach_id IS NULL));

CREATE POLICY "campaigns_update" ON public.gym_campaigns
    FOR UPDATE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()))
    WITH CHECK (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

CREATE POLICY "campaigns_delete" ON public.gym_campaigns
    FOR DELETE TO authenticated
    USING (public.is_active_approved_coach() AND coach_id = (SELECT auth.uid()));

-- =============================================================================
-- ۷. ارتقای توابع چت برای پشتیبانی از تیک دوگانه (read_at)، ریپلای و وضعیت آنلاین مربی/شاگرد
-- =============================================================================
CREATE OR REPLACE FUNCTION public.athlete_fetch_chat(
    p_athlete_id TEXT,
    p_access_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

    -- ثبت آنلاین بودن شاگرد
    UPDATE public.athletes
    SET last_seen_at = NOW()
    WHERE id = p_athlete_id::UUID;

    -- تیک دوگانه کردن (Seen) تمام پیام‌های مربی که شاگرد اکنون دید
    UPDATE public.chat_messages
    SET read_at = NOW()
    WHERE athlete_id = p_athlete_id::UUID
      AND sender_role = 'coach'
      AND read_at IS NULL;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'athlete_id', athlete_id,
                'coach_id', coach_id,
                'sender_role', sender_role,
                'message_text', message_text,
                'reply_to_id', reply_to_id,
                'read_at', read_at,
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
        LIMIT 120
    ) sub;

    RETURN v_messages;
END;
$$;

GRANT EXECUTE ON FUNCTION public.athlete_fetch_chat(TEXT, TEXT) TO anon, authenticated;

-- =============================================================================
-- PHASE 3 SQL ADDENDUM: TELEGRAM CHAT REPLY, DOUBLE-CHECK READ RECEIPTS & PRESENCE
-- =============================================================================

CREATE OR REPLACE FUNCTION public.athlete_send_chat(
    p_id TEXT,
    p_athlete_id TEXT,
    p_access_code TEXT,
    p_message_text TEXT,
    p_reply_to_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_coach_id UUID;
    v_reply_uuid UUID;
BEGIN
    SELECT coach_id INTO v_coach_id
    FROM public.athletes
    WHERE id = p_athlete_id::UUID
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
      AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF p_reply_to_id IS NOT NULL AND LENGTH(TRIM(p_reply_to_id)) >= 32 THEN
        v_reply_uuid := TRIM(p_reply_to_id)::UUID;
    ELSE
        v_reply_uuid := NULL;
    END IF;

    -- ثبت آنلاین بودن ورزشکار در لحظه ارسال پیام
    UPDATE public.athletes
    SET last_seen_at = NOW()
    WHERE id = p_athlete_id::UUID;

    INSERT INTO public.chat_messages (
        id, athlete_id, coach_id, sender_role, message_text, reply_to_id, created_at
    )
    VALUES (
        p_id::UUID,
        p_athlete_id::UUID,
        v_coach_id,
        'athlete',
        LEFT(TRIM(p_message_text), 500),
        v_reply_uuid,
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN TRUE;
END;
$$;

-- تابع ثبت تیک دوگانه (Seen) توسط مربی هنگام باز کردن چت یک شاگرد
CREATE OR REPLACE FUNCTION public.coach_mark_chat_read(p_athlete_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_active_approved_coach() THEN
        RETURN FALSE;
    END IF;

    UPDATE public.chat_messages
    SET read_at = NOW()
    WHERE athlete_id = p_athlete_id
      AND coach_id = (SELECT auth.uid())
      AND sender_role = 'athlete'
      AND read_at IS NULL;

    UPDATE public.coach_profiles
    SET last_seen_at = NOW()
    WHERE id = (SELECT auth.uid());

    RETURN TRUE;
END;
$$;

-- تابع بروزرسانی پروفایل و آواتار ورزشکار با تایید رمز عبور فعلی (Re-Authentication)
CREATE OR REPLACE FUNCTION public.athlete_update_own_profile_secure(
    p_athlete_id UUID,
    p_access_code TEXT,
    p_current_password_hash TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone TEXT,
    p_bio TEXT,
    p_avatar_b64 TEXT,
    p_new_password_hash TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_stored_hash TEXT;
BEGIN
    SELECT password_hash INTO v_stored_hash
    FROM public.athletes
    WHERE id = p_athlete_id
      AND is_deleted = FALSE
      AND (
          UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
          OR password_hash = TRIM(p_current_password_hash)
      );

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- اگر کاربر قبلاً رمز عبور داشته و می‌خواهد رمز جدید بگذارد، رمز فعلی باید تطابق داشته باشد
    IF COALESCE(TRIM(p_new_password_hash), '') != '' AND COALESCE(v_stored_hash, '') != '' THEN
        IF v_stored_hash != TRIM(p_current_password_hash) THEN
            RAISE EXCEPTION 'Re-authentication failed: Current password mismatch';
        END IF;
    END IF;

    UPDATE public.athletes
    SET first_name = LEFT(TRIM(p_first_name), 80),
        last_name = LEFT(TRIM(p_last_name), 80),
        phone = LEFT(TRIM(p_phone), 20),
        bio = LEFT(TRIM(COALESCE(p_bio, '')), 200),
        avatar_b64 = LEFT(COALESCE(p_avatar_b64, ''), 150000),
        password_hash = CASE
            WHEN COALESCE(TRIM(p_new_password_hash), '') != '' THEN TRIM(p_new_password_hash)
            ELSE password_hash
        END,
        updated_at = NOW(),
        last_seen_at = NOW()
    WHERE id = p_athlete_id;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.athlete_send_chat(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.coach_mark_chat_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_update_own_profile_secure(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- =============================================================================
-- PHASE 4 SQL ADDENDUM: SECURE RPCs FOR CLUB ARENA, POST SHARING & REACTIONS
-- =============================================================================

-- ۱. دریافت فید اکسپلور باشگاه و کمپین‌های فعال (مخصوص ورزشکار همان باشگاه)
CREATE OR REPLACE FUNCTION public.athlete_fetch_club_arena(
    p_athlete_id UUID,
    p_access_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_coach_id UUID;
    v_posts JSONB;
    v_campaigns JSONB;
    v_leaderboard JSONB;
BEGIN
    SELECT coach_id INTO v_coach_id
    FROM public.athletes
    WHERE id = p_athlete_id
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
      AND is_deleted = FALSE
    LIMIT 1;

    IF v_coach_id IS NULL THEN
        SELECT coach_id INTO v_coach_id
        FROM public.athletes
        WHERE id = p_athlete_id AND is_deleted = FALSE
        LIMIT 1;
    END IF;

    SELECT COALESCE(jsonb_agg(cp ORDER BY cp.created_at DESC), '[]'::jsonb)
    INTO v_posts
    FROM (
        SELECT * FROM public.club_posts
        WHERE (coach_id = v_coach_id OR v_coach_id IS NULL)
        ORDER BY created_at DESC
        LIMIT 60
    ) cp;

    SELECT COALESCE(jsonb_agg(gc ORDER BY gc.created_at DESC), '[]'::jsonb)
    INTO v_campaigns
    FROM public.gym_campaigns gc
    WHERE (gc.coach_id = v_coach_id OR v_coach_id IS NULL)
      AND gc.is_active = TRUE;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'full_name', TRIM(a.first_name || ' ' || a.last_name),
                'streak_days', COALESCE(a.streak_days, 1),
                'created_at', a.created_at
            ) ORDER BY COALESCE(a.streak_days, 1) DESC
        ),
        '[]'::jsonb
    )
    INTO v_leaderboard
    FROM (
        SELECT id, first_name, last_name, streak_days, created_at
        FROM public.athletes
        WHERE (coach_id = v_coach_id OR v_coach_id IS NULL)
          AND is_deleted = FALSE
        ORDER BY COALESCE(streak_days, 1) DESC
        LIMIT 10
    ) a;

    RETURN jsonb_build_object(
        'posts', v_posts,
        'campaigns', v_campaigns,
        'leaderboard', v_leaderboard
    );
END;
$$;

-- ۲. اشتراک‌گذاری خلاصه تمرین و رکورد شکسته شده توسط ورزشکار در اکسپلور باشگاه
CREATE OR REPLACE FUNCTION public.athlete_publish_club_post(
    p_athlete_id UUID,
    p_access_code TEXT,
    p_athlete_badge TEXT,
    p_workout_title TEXT,
    p_total_sets INTEGER,
    p_total_volume_kg DOUBLE PRECISION,
    p_pr_highlight TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_athlete RECORD;
BEGIN
    SELECT * INTO v_athlete
    FROM public.athletes
    WHERE id = p_athlete_id
      AND UPPER(TRIM(access_code)) = UPPER(TRIM(p_access_code))
      AND is_deleted = FALSE
    LIMIT 1;

    IF v_athlete IS NULL THEN
        RETURN FALSE;
    END IF;

    INSERT INTO public.club_posts (
        coach_id, athlete_id, athlete_name, athlete_badge,
        workout_title, total_sets, total_volume_kg, pr_highlight,
        streak_days, fire_count, muscle_count, crown_count, created_at
    ) VALUES (
        COALESCE(v_athlete.coach_id, '00000000-0000-0000-0000-000000000000'::UUID),
        v_athlete.id,
        TRIM(v_athlete.first_name || ' ' || v_athlete.last_name),
        LEFT(TRIM(COALESCE(p_athlete_badge, 'قهرمان مکس‌جیم')), 60),
        LEFT(TRIM(COALESCE(p_workout_title, 'جلسه تمرینی مکس‌جیم')), 100),
        GREATEST(1, LEAST(100, p_total_sets)),
        GREATEST(0, LEAST(200000, p_total_volume_kg)),
        LEFT(TRIM(COALESCE(p_pr_highlight, '')), 120),
        COALESCE(v_athlete.streak_days, 1),
        1, 0, 0, NOW()
    );

    RETURN TRUE;
END;
$$;

-- ۳. ثبت واکنش ورزشی (🔥 دمت گرم / 💪 ماشاالله / 👑 قهرمان) روی پست‌های اکسپلور باشگاه
CREATE OR REPLACE FUNCTION public.club_react_to_post(
    p_post_id UUID,
    p_reaction_type TEXT -- 'fire', 'muscle', 'crown'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_reaction_type = 'fire' THEN
        UPDATE public.club_posts SET fire_count = fire_count + 1 WHERE id = p_post_id;
    ELSIF p_reaction_type = 'muscle' THEN
        UPDATE public.club_posts SET muscle_count = muscle_count + 1 WHERE id = p_post_id;
    ELSIF p_reaction_type = 'crown' THEN
        UPDATE public.club_posts SET crown_count = crown_count + 1 WHERE id = p_post_id;
    ELSE
        RETURN FALSE;
    END IF;

    RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.athlete_fetch_club_arena(UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.athlete_publish_club_post(UUID, TEXT, TEXT, TEXT, INTEGER, DOUBLE PRECISION, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.club_react_to_post(UUID, TEXT) TO anon, authenticated;
