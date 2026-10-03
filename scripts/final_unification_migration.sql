-- FINAL_UNIFICATION_MIGRATION
DO $$ 
BEGIN 
  -- CORE PROFILE COLUMNS
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS balance DECIMAL DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS tasks_completed INTEGER DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact_no TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS blood_group TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS medical_info TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS passport_url TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS aadhar_url TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS medical_certificate_url TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  
  -- FINANCE & PERFORMANCE COLUMNS
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS salary DECIMAL DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS allowance DECIMAL DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS advances DECIMAL DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS dues_penalty DECIMAL DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bank_account_no TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS loyalty_rank INTEGER DEFAULT 1; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
END $$;

-- BLOGS TABLE
CREATE TABLE IF NOT EXISTS public.blogs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL
);

DO $$ 
BEGIN 
  BEGIN 
    ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS image_url TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Campus Info'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS claps INTEGER DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
END $$;

-- PROCUREMENTS TABLE
CREATE TABLE IF NOT EXISTS public.procurements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL
);

DO $$ 
BEGIN 
  BEGIN 
    ALTER TABLE public.procurements ADD COLUMN IF NOT EXISTS description TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.procurements ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'Medium'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.procurements ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'REQUESTED'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.procurements ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.procurements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
END $$;

-- EMPLOYEE TASKS
CREATE TABLE IF NOT EXISTS public.employee_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assignee_id UUID REFERENCES public.profiles(id) NOT NULL,
    title TEXT NOT NULL
);

DO $$ 
BEGIN 
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS task_type TEXT DEFAULT 'GENERAL'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'GENERAL'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS assigner_id UUID REFERENCES public.profiles(id) DEFAULT auth.uid(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS description TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'Medium'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Pending'; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS proof_image_url TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.employee_tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(); 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
END $$;

-- SECURITY (RLS)
ALTER TABLE public.blogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_blogs" ON public.blogs;
CREATE POLICY "public_blogs" ON public.blogs FOR ALL USING (true);

DROP POLICY IF EXISTS "public_procurements" ON public.procurements;
CREATE POLICY "public_procurements" ON public.procurements FOR ALL USING (true);

DROP POLICY IF EXISTS "public_tasks" ON public.employee_tasks;
CREATE POLICY "public_tasks" ON public.employee_tasks FOR ALL USING (true);

-- SEED DATA
INSERT INTO public.employee_tasks (title, description, assignee_id, priority, status, type, task_type)
SELECT 
  'Deliver Parcel to Room 204B', 
  'Fragile items for Resident 204. Handle with care.',
  id, 'Medium', 'Pending', 'DELIVERY', 'DELIVERY'
FROM profiles WHERE role = 'staff' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.employee_tasks (title, description, assignee_id, priority, status, type, task_type)
SELECT 
  'Main Block Cleaning Audit', 
  'Conduct sanitization and cleanliness audit for A Block.',
  id, 'High', 'In-Progress', 'MAINTENANCE', 'MAINTENANCE'
FROM profiles WHERE role = 'staff' LIMIT 1
ON CONFLICT DO NOTHING;
