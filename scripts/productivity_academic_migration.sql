-- CORE EXTENSIONS
-- Ensure profiles table has everything
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS study_status TEXT DEFAULT 'idle';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0; -- Deprecate xp_total or sync them

-- ACADEMIC TARGETS
CREATE TABLE IF NOT EXISTS public.student_academic_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL, -- weekly, monthly, semester
    content TEXT NOT NULL,
    is_achieved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- KNOWLEDGE VAULT
CREATE TABLE IF NOT EXISTS public.student_knowledge_vault (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL, -- trick, shortcut, important_topic
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    subject TEXT,
    tags TEXT[],
    last_revised_at TIMESTAMP WITH TIME ZONE,
    next_revision_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- STUDENT DOUBTS
CREATE TABLE IF NOT EXISTS public.student_doubts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT,
    doubt TEXT NOT NULL,
    resolution TEXT,
    is_resolved BOOLEAN DEFAULT FALSE,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- SYLLABUS TRACKER
CREATE TABLE IF NOT EXISTS public.student_syllabus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    test_date DATE NOT NULL,
    topics TEXT[],
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- REFLECTIONS
CREATE TABLE IF NOT EXISTS public.student_reflections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    achievements TEXT,
    focus_rating INTEGER DEFAULT 5,
    feeling TEXT,
    satisfaction_rating INTEGER DEFAULT 5,
    goals_met TEXT[],
    log_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- MOCK SCORES
CREATE TABLE IF NOT EXISTS public.student_mock_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    exam_name TEXT NOT NULL,
    subject TEXT,
    score_obtained NUMERIC NOT NULL,
    total_score NUMERIC NOT NULL,
    mock_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- EXAM DEADLINES
CREATE TABLE IF NOT EXISTS public.student_exam_deadlines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    exam_title TEXT NOT NULL,
    exam_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- REMINDERS
CREATE TABLE IF NOT EXISTS public.student_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    reminder_type TEXT DEFAULT 'Habit',
    scheduled_time TEXT, -- HH:mm
    recurring_days INTEGER[], -- 0:Sun, 1:Mon
    is_active BOOLEAN DEFAULT TRUE,
    is_completed BOOLEAN DEFAULT FALSE, -- for daily reset habits
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- DAILY ROUTINES
CREATE TABLE IF NOT EXISTS public.student_daily_routines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    start_time TEXT NOT NULL, -- HH:mm
    end_time TEXT NOT NULL, -- HH:mm
    icon_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- PERMISSIONS / RLS (Simplified)
ALTER TABLE public.student_academic_targets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own targets" ON public.student_academic_targets FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_knowledge_vault ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own vault" ON public.student_knowledge_vault FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_doubts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own doubts" ON public.student_doubts FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_syllabus ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own syllabus" ON public.student_syllabus FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_reflections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own reflections" ON public.student_reflections FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_mock_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own scores" ON public.student_mock_scores FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_exam_deadlines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own deadlines" ON public.student_exam_deadlines FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own reminders" ON public.student_reminders FOR ALL USING (auth.uid() = student_id);

ALTER TABLE public.student_daily_routines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own routines" ON public.student_daily_routines FOR ALL USING (auth.uid() = student_id);
-- REVISION FUNCTION
CREATE OR REPLACE FUNCTION public.complete_knowledge_revision(vault_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.student_knowledge_vault
    SET 
        last_revised_at = now(),
        next_revision_date = now() + INTERVAL '7 days' -- Simple spaced repetition: next in 7 days
    WHERE id = vault_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
