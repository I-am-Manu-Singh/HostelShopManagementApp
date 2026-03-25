-- 1. ADD SECURITY & VERIFICATION COLUMNS TO PROFILES
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS student_level INTEGER DEFAULT 1;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp_total INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS total_focus_time INTEGER DEFAULT 0; -- in seconds

-- 2. CREATE PERFORMANCE INCREMENT FUNCTION
CREATE OR REPLACE FUNCTION public.increment_workout_performance(
  user_id UUID,
  minutes INTEGER,
  xp_gain INTEGER
) RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET 
    xp = COALESCE(xp, 0) + xp_gain,
    total_focus_time = COALESCE(total_focus_time, 0) + (minutes * 60)
  WHERE id = user_id;
  
  -- LEVEL UP LOGIC
  UPDATE public.profiles
  SET student_level = FLOOR(COALESCE(xp, 0) / 1000) + 1
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. ENSURE MESSAGES TABLE SUPPORTS REALTIME
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;
