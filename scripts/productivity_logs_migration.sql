-- 1. HISTORY TABLES FOR PRODUCTIVITY
CREATE TABLE IF NOT EXISTS public.student_meditation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    duration_minutes INTEGER NOT NULL,
    xp_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.student_workout_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    duration_minutes INTEGER NOT NULL,
    workout_type TEXT,
    xp_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.student_focus_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    duration_seconds INTEGER NOT NULL,
    xp_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. ENABLE RLS
ALTER TABLE public.student_meditation_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can only access their own meditation logs" ON public.student_meditation_logs;
CREATE POLICY "Users can only access their own meditation logs" ON public.student_meditation_logs FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_workout_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can only access their own workout logs" ON public.student_workout_logs;
CREATE POLICY "Users can only access their own workout logs" ON public.student_workout_logs FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_focus_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can only access their own focus logs" ON public.student_focus_logs;
CREATE POLICY "Users can only access their own focus logs" ON public.student_focus_logs FOR ALL USING (auth.uid() = student_id);

-- 3. CLUB REMINDERS / HABITS ENHANCEMENT
ALTER TABLE public.student_reminders ADD COLUMN IF NOT EXISTS difficulty TEXT DEFAULT 'Easy'; -- Easy, Medium, Hard
ALTER TABLE public.student_reminders ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'General'; -- Health, Club, Study
ALTER TABLE public.student_reminders ADD COLUMN IF NOT EXISTS detail_data JSONB DEFAULT '{}'::jsonb; -- For customizable habit data

-- 4. UPDATE RPC FOR XP SYNC (ensure it updates both xp and xp_total if needed, but let's stick to 'xp' as primary)
CREATE OR REPLACE FUNCTION public.increment_performance_with_log(
  user_id UUID,
  p_type TEXT, -- 'workout', 'meditation', 'focus'
  p_value INTEGER, -- minutes or seconds
  p_xp INTEGER
) RETURNS VOID AS $$
BEGIN
  -- Update Profile
  UPDATE public.profiles
  SET 
    xp = COALESCE(xp, 0) + p_xp,
    total_focus_time = total_focus_time + (CASE WHEN p_type = 'focus' THEN p_value ELSE p_value * 60 END)
  WHERE id = user_id;

  -- Log Activity
  IF p_type = 'meditation' THEN
    INSERT INTO public.student_meditation_logs (student_id, duration_minutes, xp_earned) VALUES (user_id, p_value, p_xp);
  ELSIF p_type = 'workout' THEN
    INSERT INTO public.student_workout_logs (student_id, duration_minutes, xp_earned) VALUES (user_id, p_value, p_xp);
  ELSIF p_type = 'focus' THEN
    INSERT INTO public.student_focus_logs (student_id, duration_seconds, xp_earned) VALUES (user_id, p_value, p_xp);
  END IF;

  -- Level logic
  UPDATE public.profiles SET student_level = FLOOR(COALESCE(xp, 0) / 1000) + 1 WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.increment_xp_only(
  user_id UUID,
  p_xp INTEGER
) RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET xp = COALESCE(xp, 0) + p_xp
  WHERE id = user_id;
  
  -- Level logic
  UPDATE public.profiles SET student_level = FLOOR(COALESCE(xp, 0) / 1000) + 1 WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
