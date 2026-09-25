-- ============================================================================
-- SQL MIGRATION: Schema Fixes, Productivity Suite, and Missing Columns
-- ============================================================================

-- 1. Fix Postgrest Column Cache Issues
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS instructions TEXT;
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'domestic';
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS delivery_location TEXT;
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS advance_paid NUMERIC DEFAULT 0;
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS is_booking BOOLEAN DEFAULT FALSE;
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS booking_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- 1b. Fix Missing Fiscal and Mess Card Columns (Resolve PostgrestException 204)
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS total_amount NUMERIC;
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS room_rent NUMERIC;
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS collection_type TEXT DEFAULT 'Rent';
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'Cash';
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS collection_cycle TEXT;
ALTER TABLE public.fiscal_collections ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Approved';

ALTER TABLE public.mess_cards ADD COLUMN IF NOT EXISTS card_number TEXT;
ALTER TABLE public.mess_cards ADD COLUMN IF NOT EXISTS price NUMERIC DEFAULT 3500;
ALTER TABLE public.mess_cards ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.mess_cards ADD COLUMN IF NOT EXISTS card_type TEXT DEFAULT 'Standard';
ALTER TABLE public.mess_cards ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';

-- 1c. Khata / Lending Book Table & Columns (Rich Debtor Tracking)
CREATE TABLE IF NOT EXISTS public.lending_book (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    debtor_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    debtor_name TEXT NOT NULL,
    debtor_phone TEXT,
    photo_url TEXT,
    amount NUMERIC NOT NULL,
    type TEXT DEFAULT 'lent',
    status TEXT DEFAULT 'pending',
    notes TEXT,
    due_date TIMESTAMP WITH TIME ZONE,
    settled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.lending_book ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.lending_book ADD COLUMN IF NOT EXISTS debtor_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.lending_book ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE public.lending_book ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.lending_book ADD COLUMN IF NOT EXISTS due_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.lending_book ADD COLUMN IF NOT EXISTS settled_at TIMESTAMP WITH TIME ZONE;

-- Performance Indexes for fast temporal calculations (Today/Week/Month/Debtor Grouping)
CREATE INDEX IF NOT EXISTS idx_lending_book_user_id ON public.lending_book(user_id);
CREATE INDEX IF NOT EXISTS idx_lending_book_debtor_user_id ON public.lending_book(debtor_user_id);
CREATE INDEX IF NOT EXISTS idx_lending_book_created_at ON public.lending_book(created_at);

-- Ensure public storage bucket for khata debtor photos exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('proofs', 'proofs', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Profiles Table Extensions
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS study_status TEXT DEFAULT 'idle';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS total_focus_time INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS student_level INTEGER DEFAULT 1;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS face_embedding NUMERIC[];
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS biometric_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS biometric_type TEXT;

-- 3. Academic & Productivity Tables with dual student_id / user_id column compatibility
-- A. Academic Targets
CREATE TABLE IF NOT EXISTS public.student_academic_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL,
    content TEXT NOT NULL,
    is_achieved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_academic_targets ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_academic_targets ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- B. Knowledge Vault
CREATE TABLE IF NOT EXISTS public.student_knowledge_vault (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    subject TEXT,
    tags TEXT[],
    last_revised_at TIMESTAMP WITH TIME ZONE,
    next_revision_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_knowledge_vault ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_knowledge_vault ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- C. Student Doubts
CREATE TABLE IF NOT EXISTS public.student_doubts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT,
    doubt TEXT,
    question TEXT,
    resolution TEXT,
    is_resolved BOOLEAN DEFAULT FALSE,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_doubts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_doubts ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_doubts ADD COLUMN IF NOT EXISTS question TEXT;

-- D. Student Syllabus
CREATE TABLE IF NOT EXISTS public.student_syllabus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    test_date DATE NOT NULL,
    topics TEXT[],
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_syllabus ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_syllabus ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- E. Student Reflections
CREATE TABLE IF NOT EXISTS public.student_reflections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    achievements TEXT,
    focus_rating INTEGER DEFAULT 5,
    feeling TEXT,
    satisfaction_rating INTEGER DEFAULT 5,
    goals_met TEXT[],
    log_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_reflections ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_reflections ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- F. Student Mock Scores
CREATE TABLE IF NOT EXISTS public.student_mock_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    exam_name TEXT NOT NULL,
    subject TEXT,
    score_obtained NUMERIC NOT NULL,
    total_score NUMERIC NOT NULL,
    mock_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_mock_scores ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_mock_scores ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- G. Student Exam Deadlines
CREATE TABLE IF NOT EXISTS public.student_exam_deadlines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    exam_title TEXT NOT NULL,
    exam_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_exam_deadlines ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_exam_deadlines ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- H. Student Reminders
CREATE TABLE IF NOT EXISTS public.student_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    reminder_type TEXT DEFAULT 'Habit',
    category TEXT DEFAULT 'General',
    scheduled_time TEXT,
    recurring_days INTEGER[],
    is_active BOOLEAN DEFAULT TRUE,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_reminders ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_reminders ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_reminders ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'General';

-- I. Student Daily Routines
CREATE TABLE IF NOT EXISTS public.student_daily_routines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT DEFAULT 'Focus',
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    icon_name TEXT,
    is_done BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_daily_routines ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_daily_routines ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_daily_routines ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Focus';
ALTER TABLE public.student_daily_routines ADD COLUMN IF NOT EXISTS is_done BOOLEAN DEFAULT FALSE;

-- J. Student Tasks & Focus Logs
CREATE TABLE IF NOT EXISTS public.student_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    task_date DATE DEFAULT CURRENT_DATE,
    start_time TEXT,
    end_time TEXT,
    priority TEXT DEFAULT 'Medium',
    category TEXT DEFAULT 'Academics',
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_tasks ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_tasks ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS public.student_focus_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_type TEXT DEFAULT 'pomodoro',
    duration_minutes INTEGER DEFAULT 25,
    xp_earned INTEGER DEFAULT 50,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.student_focus_logs ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.student_focus_logs ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- K. Mess Menu Constraint Fix (Allow multi-week menus without conflict)
DO $$
BEGIN
    ALTER TABLE public.mess_menu DROP CONSTRAINT IF EXISTS mess_menu_day_key;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'mess_menu_week_year_day_key'
    ) THEN
        ALTER TABLE public.mess_menu ADD CONSTRAINT mess_menu_week_year_day_key UNIQUE (week_number, year, day);
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- L. Room Maintenance Records (if missing)
CREATE TABLE IF NOT EXISTS public.room_maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE CASCADE,
    inspector_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'OK',
    issue_description TEXT,
    resolution_details TEXT,
    actual_cost NUMERIC DEFAULT 0,
    inspection_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 4. Enable RLS and Policies for Student Tables (Safely inspecting column names)
DO $$
DECLARE
    tbl text;
    has_user_id boolean;
    has_student_id boolean;
    clause text;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'student_academic_targets',
        'student_knowledge_vault',
        'student_doubts',
        'student_syllabus',
        'student_reflections',
        'student_mock_scores',
        'student_exam_deadlines',
        'student_reminders',
        'student_daily_routines',
        'student_tasks',
        'student_focus_logs',
        'lending_book',
        'room_maintenance_records'
    ]) LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            EXECUTE format('DROP POLICY IF EXISTS "%s_owner_policy" ON public.%I;', tbl, tbl);
            
            IF tbl = 'room_maintenance_records' THEN
                EXECUTE format('CREATE POLICY "%s_owner_policy" ON public.%I FOR ALL USING (true);', tbl, tbl);
            ELSE
                SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = tbl AND column_name = 'user_id') INTO has_user_id;
                SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = tbl AND column_name = 'student_id') INTO has_student_id;
                
                IF has_user_id AND has_student_id THEN
                    clause := 'auth.uid() = COALESCE(user_id, student_id)';
                ELSIF has_user_id THEN
                    clause := 'auth.uid() = user_id';
                ELSIF has_student_id THEN
                    clause := 'auth.uid() = student_id';
                ELSE
                    clause := 'true';
                END IF;

                EXECUTE format('CREATE POLICY "%s_owner_policy" ON public.%I FOR ALL USING (%s) WITH CHECK (%s);', tbl, tbl, clause, clause);
            END IF;
        END IF;
    END LOOP;
END $$;

-- 5. Helper function for spaced repetition
CREATE OR REPLACE FUNCTION public.complete_knowledge_revision(vault_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.student_knowledge_vault
    SET 
        last_revised_at = now(),
        next_revision_date = now() + INTERVAL '7 days'
    WHERE id = vault_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Comprehensive RLS Policies for Finance & Approvals (Fixes 42501 Forbidden)
-- Enable RLS
ALTER TABLE public.fiscal_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mess_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_approvals ENABLE ROW LEVEL SECURITY;

-- Helper check function for admin / manager roles
CREATE OR REPLACE FUNCTION public.is_finance_manager(uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = uid
          AND role IN ('admin', 'owner', 'hostel_manager', 'manager', 'staff', 'accountant')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- A) fiscal_collections policies
DROP POLICY IF EXISTS "fiscal_collections_user_and_admin_policy" ON public.fiscal_collections;
DROP POLICY IF EXISTS "fiscal_collections_admin_policy" ON public.fiscal_collections;
DROP POLICY IF EXISTS "fiscal_collections_owner_policy" ON public.fiscal_collections;

CREATE POLICY "fiscal_collections_user_and_admin_policy" ON public.fiscal_collections
FOR ALL USING (
    auth.uid() = user_id
    OR auth.uid() = student_id
    OR public.is_finance_manager(auth.uid())
)
WITH CHECK (
    auth.uid() = user_id
    OR auth.uid() = student_id
    OR public.is_finance_manager(auth.uid())
);

-- B) mess_cards policies
DROP POLICY IF EXISTS "mess_cards_user_and_admin_policy" ON public.mess_cards;
DROP POLICY IF EXISTS "mess_cards_admin_policy" ON public.mess_cards;
DROP POLICY IF EXISTS "mess_cards_owner_policy" ON public.mess_cards;

CREATE POLICY "mess_cards_user_and_admin_policy" ON public.mess_cards
FOR ALL USING (
    auth.uid() = user_id
    OR public.is_finance_manager(auth.uid())
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_finance_manager(auth.uid())
);

-- C) payment_approvals policies
DROP POLICY IF EXISTS "payment_approvals_user_and_admin_policy" ON public.payment_approvals;
DROP POLICY IF EXISTS "payment_approvals_admin_policy" ON public.payment_approvals;

CREATE POLICY "payment_approvals_user_and_admin_policy" ON public.payment_approvals
FOR ALL USING (
    auth.uid() = user_id
    OR public.is_finance_manager(auth.uid())
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_finance_manager(auth.uid())
);

-- 7. App Settings Table & Logistics Rules Storage (Fix Fee & Festival Offers)
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Ensure value column is flexible (convert numeric to text if pre-existing as numeric)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'app_settings' 
          AND column_name = 'value'
          AND data_type IN ('numeric', 'double precision', 'integer')
    ) THEN
        ALTER TABLE public.app_settings ALTER COLUMN value TYPE TEXT USING value::text;
    END IF;
END $$;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_settings_read_policy" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_write_policy" ON public.app_settings;

CREATE POLICY "app_settings_read_policy" ON public.app_settings
FOR SELECT USING (true);

CREATE POLICY "app_settings_write_policy" ON public.app_settings
FOR ALL USING (
    public.is_finance_manager(auth.uid())
)
WITH CHECK (
    public.is_finance_manager(auth.uid())
);

-- Store/Company dynamic configuration seeds
INSERT INTO public.app_settings (key, value)
VALUES 
    ('delivery_charge', '20'),
    ('logistics_rules', '[]'),
    ('company_name', 'H House'),
    ('company_phone', '+91 79762 87989'),
    ('support_email', 'support@campusconnect.com'),
    ('website', 'https://hostelconnect.edu.in'),
    ('company_address', 'Campus Central Avenue, Tech Zone Block 4, Mohali – 160071'),
    ('store_gstin', '03ABCDE1234F1Z8'),
    ('merchant_name', 'Hostel SuperMart & POS'),
    ('merchant_upi_vpa', 'campusshop@upi'),
    ('receipt_footer_note', 'Thank you for shopping with us!\nVisit again.')
ON CONFLICT (key) DO NOTHING;

-- 8. Fix Outpasses Table & Biometric Gate Scanner Columns (Fix 42703 column outpasses.user_id does not exist)
CREATE TABLE IF NOT EXISTS public.outpasses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    destination TEXT DEFAULT 'Main Gate',
    reason TEXT DEFAULT 'Biometric Log',
    status TEXT DEFAULT 'Approved',
    time_out TIMESTAMP WITH TIME ZONE,
    time_in TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Ensure user_id column exists if table was pre-existing with only student_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'outpasses' 
          AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.outpasses ADD COLUMN user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'outpasses' 
          AND column_name = 'student_id'
    ) THEN
        ALTER TABLE public.outpasses ADD COLUMN student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'outpasses' 
          AND column_name = 'time_in'
    ) THEN
        ALTER TABLE public.outpasses ADD COLUMN time_in TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'outpasses' 
          AND column_name = 'time_out'
    ) THEN
        ALTER TABLE public.outpasses ADD COLUMN time_out TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Synchronize hostel_outpasses if pre-existing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'hostel_outpasses'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'hostel_outpasses' AND column_name = 'user_id'
        ) THEN
            ALTER TABLE public.hostel_outpasses ADD COLUMN user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

ALTER TABLE public.outpasses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "outpasses_access_policy" ON public.outpasses;
CREATE POLICY "outpasses_access_policy" ON public.outpasses FOR ALL USING (true) WITH CHECK (true);


