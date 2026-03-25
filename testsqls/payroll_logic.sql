-- 1. EXTEND ATTENDANCE TYPES
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_attendance_type_check;
ALTER TABLE public.attendance ADD CONSTRAINT attendance_attendance_type_check 
CHECK (attendance_type IN ('hostel', 'mess', 'gate', 'academic', 'night', 'staff'));

-- 2. FUNCTION: CALCULATE AD-HOC PAYROLL
-- Calculates salary for a specific employee for current month based on attendance
CREATE OR REPLACE FUNCTION public.calculate_employee_payroll(employee_id UUID, month_year DATE)
RETURNS TABLE (
    total_days INTEGER,
    present_days INTEGER,
    absent_days INTEGER,
    base_salary NUMERIC,
    calculated_salary NUMERIC
) LANGUAGE plpgsql AS $$
DECLARE
    entry_total_days INTEGER;
    entry_present_days INTEGER;
    entry_base_salary NUMERIC;
BEGIN
    -- Get total days in the month
    entry_total_days := date_part('days', (date_trunc('month', month_year) + interval '1 month' - interval '1 day'))::integer;
    
    -- Count distinct days present for 'staff' type
    SELECT COUNT(DISTINCT date) INTO entry_present_days
    FROM public.attendance
    WHERE user_id = employee_id 
    AND attendance_type = 'staff'
    AND date_trunc('month', date) = date_trunc('month', month_year);
    
    -- Get base salary from profiles
    SELECT COALESCE(salary, 0) INTO entry_base_salary
    FROM public.profiles
    WHERE id = employee_id;
    
    RETURN QUERY SELECT 
        entry_total_days, 
        entry_present_days, 
        (entry_total_days - entry_present_days),
        entry_base_salary,
        (entry_base_salary / entry_total_days * entry_present_days);
END;
$$;

-- 3. FUNCTION: GET ATTENDANCE SUMMARY (Skipped Days)
-- Returns count of skipped days for students
CREATE OR REPLACE FUNCTION public.get_attendance_summary(p_user_id UUID)
RETURNS TABLE (present_count INTEGER, skipped_count INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    total_eligible_days INTEGER;
BEGIN
    -- Eligible days = days since join or last 30 days
    total_eligible_days := 30; 
    
    RETURN QUERY 
    SELECT 
        COUNT(DISTINCT date)::INTEGER as present_count,
        (total_eligible_days - COUNT(DISTINCT date))::INTEGER as skipped_count
    FROM public.attendance
    WHERE user_id = p_user_id
    AND date > (CURRENT_DATE - INTERVAL '30 days');
END;
$$;
