-- 1. ENHANCE PROFILES WITH BIOMETRIC DATA
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS biometric_id TEXT; -- For device-independent fingerprint mapping (if using external hardware)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS face_embedding JSONB; -- For storing face descriptors/vectors
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS batch_year TEXT DEFAULT '2024'; -- To differentiate student batches
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 2. FIX ATTENDANCE CHECK CONSTRAINTS
-- Remove old constraints first
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_attendance_type_check;
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_meal_type_check;

-- Add updated constraints that match the App's current naming (gate, hostel, mess, Tea)
ALTER TABLE public.attendance ADD CONSTRAINT attendance_attendance_type_check 
CHECK (attendance_type IN ('hostel', 'mess', 'gate', 'academic', 'night', 'staff'));

ALTER TABLE public.attendance ADD CONSTRAINT attendance_meal_type_check 
CHECK (meal_type IN ('Breakfast', 'Lunch', 'Tea', 'Hi-Tea', 'Dinner'));

-- 3. ENABLE UPSERT LOGIC WITH UNIQUE CONSTRAINT
-- We want one attendance record per user per type per day per meal
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_unique_daily_record;
ALTER TABLE public.attendance ADD CONSTRAINT attendance_unique_daily_record 
UNIQUE (user_id, date, attendance_type, meal_type);

-- 4. FUNCTION TO RETRIEVE BIOMETRIC CACHE (to speed up face/fp matching on-device)
CREATE OR REPLACE FUNCTION public.get_biometric_telemetry()
RETURNS TABLE (id UUID, full_name TEXT, biometric_id TEXT, face_embedding JSONB, room_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.full_name, p.biometric_id, p.face_embedding, p.room_id
  FROM public.profiles p
  WHERE p.is_active = TRUE;
END;
$$;
