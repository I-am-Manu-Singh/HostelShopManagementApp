-- ====================================================================
-- HOSTEL & MANDI APP: UTILITIES, FLEET LOGS, AND MAINTENANCE SCHEMA
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ====================================================================

-- ────────────────────────────────────────────────────────────────────
-- 1. FLEET & REFUELING LOGS DATABASE
-- ────────────────────────────────────────────────────────────────────

-- Vans table to track vehicle details and default drivers
CREATE TABLE IF NOT EXISTS vans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  van_number TEXT NOT NULL UNIQUE,
  driver_name TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Refueling & Odometer logs
CREATE TABLE IF NOT EXISTS van_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  van_id UUID REFERENCES vans(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  previous_meter DECIMAL(12,2) DEFAULT 0.00,
  latest_meter DECIMAL(12,2) NOT NULL,
  fuel_liters DECIMAL(10,2) NOT NULL,
  amount_paid DECIMAL(10,2) NOT NULL,
  payment_method TEXT DEFAULT 'Cash',
  receipt_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for Fleet Tables
ALTER TABLE vans ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to authenticated users for vans" 
ON vans FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow read access to authenticated users for van_logs" 
ON van_logs FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert access to authenticated users for van_logs" 
ON van_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow insert access to admin for vans" 
ON vans FOR INSERT TO authenticated WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role IN ('admin', 'hostel_manager', 'owner')
  )
);


-- ────────────────────────────────────────────────────────────────────
-- 2. UTILITY POWER AUDIT (METER READINGS)
-- ────────────────────────────────────────────────────────────────────

-- Meter readings table for room electricity logging (Uses student_id instead of user_id)
CREATE TABLE IF NOT EXISTS meter_readings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id UUID REFERENCES hostel_rooms(id) ON DELETE CASCADE,
  student_id UUID REFERENCES auth.users(id),
  previous_reading DECIMAL(10,2) DEFAULT 0.00,
  latest_reading DECIMAL(10,2) NOT NULL,
  month_period DATE NOT NULL, -- Format: YYYY-MM-01
  reading_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(room_id, month_period)
);

-- Enable RLS for Meter Readings
ALTER TABLE meter_readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to authenticated users for meter_readings" 
ON meter_readings FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow upsert access to admin for meter_readings" 
ON meter_readings FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role IN ('admin', 'hostel_manager', 'owner')
  )
);
