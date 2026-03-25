-- Add support for monthly add-ons and dynamic pricing
ALTER TABLE hostel_enrollments 
ADD COLUMN IF NOT EXISTS selected_packages JSONB DEFAULT '[]';

-- Update hostel_rooms to ensure room_type is always synchronized with fee_structure
-- (This is a logical constraint, handled in-app but good to have the column)
ALTER TABLE hostel_rooms
ADD COLUMN IF NOT EXISTS room_type TEXT;
