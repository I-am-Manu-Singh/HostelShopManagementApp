-- 1. FIX COMPLAINTS TABLE (Ensure standard columns)
ALTER TABLE public.complaints DROP CONSTRAINT IF EXISTS complaints_status_check;
ALTER TABLE public.complaints ADD CONSTRAINT complaints_status_check 
CHECK (status IN ('Open', 'Pending', 'In-Progress', 'Resolved', 'Closed'));

-- 2. CREATE OUTPASSES TABLE (If not exists or sync with Flutter)
CREATE TABLE IF NOT EXISTS public.hostel_outpasses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    destination TEXT NOT NULL,
    reason TEXT NOT NULL,
    time_out TIMESTAMP WITH TIME ZONE NOT NULL,
    time_in TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Active', 'Returned')),
    approved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. CREATE GUEST INVITATIONS TABLE
CREATE TABLE IF NOT EXISTS public.guest_invitations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    guest_name TEXT NOT NULL,
    relationship TEXT,
    stay_duration INTEGER DEFAULT 1,
    pass_code TEXT UNIQUE NOT NULL, -- QR dynamic code
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Arrived', 'Departed')),
    approved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. ENABLE RLS
ALTER TABLE public.hostel_outpasses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_invitations ENABLE ROW LEVEL SECURITY;

-- 5. ACCESS POLICIES
DROP POLICY IF EXISTS "outpass_access" ON public.hostel_outpasses;
CREATE POLICY "outpass_access" ON public.hostel_outpasses FOR ALL USING (true);

DROP POLICY IF EXISTS "guest_access" ON public.guest_invitations;
CREATE POLICY "guest_access" ON public.guest_invitations FOR ALL USING (true);
