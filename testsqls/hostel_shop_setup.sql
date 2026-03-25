-- HOSTEL & SHOP MANAGEMENT SYSTEM SETUP
-- 1. ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CREATE TABLES
-- ==========================================

-- PROFILES: Extended roles
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    role TEXT DEFAULT 'store_customer' CHECK (role IN ('staff', 'hostel_student', 'store_customer', 'shop_admin', 'hostel_manager', 'hostel_owner', 'mess_student')),
    avatar_url TEXT,
    phone TEXT,
    room_number TEXT, -- For hostel students
    student_id TEXT, -- Unique ID from hostel/college
    department TEXT, -- For staff
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- HOSTEL ROOMS
CREATE TABLE IF NOT EXISTS public.hostel_rooms (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_number TEXT NOT NULL UNIQUE,
    wing TEXT,
    floor INTEGER,
    capacity INTEGER DEFAULT 1,
    available_beds INTEGER DEFAULT 1,
    base_price NUMERIC NOT NULL,
    room_type TEXT CHECK (room_type IN ('Single', 'Double', 'Triple', 'Dorm')),
    amenities JSONB DEFAULT '[]'::jsonb, -- ["AC", "WiFi", "Attached Bath"]
    image_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SHOP ITEMS (General Store)
CREATE TABLE IF NOT EXISTS public.shop_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    sku_qr TEXT UNIQUE, -- QR Code / Barcode
    category TEXT NOT NULL,
    description TEXT,
    price NUMERIC NOT NULL,
    discount_price NUMERIC,
    stock_quantity INTEGER DEFAULT 0,
    image_url TEXT,
    is_available BOOLEAN DEFAULT TRUE,
    brand TEXT, -- e.g. "Amul", "Lays"
    weight_ml TEXT, -- e.g. "500ml", "1kg"
    package_type TEXT, -- e.g. "Bottle", "Packet"
    is_bestseller BOOLEAN DEFAULT FALSE,
    rating NUMERIC DEFAULT 4.5,
    total_reviews INTEGER DEFAULT 0,
    shelf_life TEXT,
    tags TEXT[], -- ["Spicy", "Veg"]
    ingredients TEXT,
    nutritional_info JSONB, -- { "calories": "200kcal", "protein": "5g" }
    how_to_use TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure newest columns exist if table was already there (Supabase/PG 9.6+)
DO $$ 
BEGIN 
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN brand TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN weight_ml TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN package_type TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN is_bestseller BOOLEAN DEFAULT FALSE; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN rating NUMERIC DEFAULT 4.5; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN total_reviews INTEGER DEFAULT 0; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN shelf_life TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN tags TEXT[]; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN ingredients TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN nutritional_info JSONB; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
  BEGIN 
    ALTER TABLE public.shop_items ADD COLUMN how_to_use TEXT; 
  EXCEPTION WHEN duplicate_column THEN NULL; END;
END $$;

-- HOSTEL ENROLLMENTS (Bookings)
CREATE TABLE IF NOT EXISTS public.hostel_enrollments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE CASCADE,
    check_in_date DATE NOT NULL,
    check_out_date DATE,
    total_price NUMERIC NOT NULL,
    payment_status TEXT DEFAULT 'Pending' CHECK (payment_status IN ('Pending', 'Partial', 'Paid')),
    status TEXT DEFAULT 'Active' CHECK (status IN ('Active', 'Completed', 'Cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SHOP ORDERS
CREATE TABLE IF NOT EXISTS public.shop_orders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    items JSONB NOT NULL, -- List of {"id": "...", "name": "...", "qty": 1, "price": 100}
    total_price NUMERIC NOT NULL,
    payment_status TEXT DEFAULT 'Pending' CHECK (payment_status IN ('Pending', 'Paid')),
    order_status TEXT DEFAULT 'Placed' CHECK (order_status IN ('Placed', 'Packing', 'Ready', 'Delivered', 'Cancelled')),
    order_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ATTENDANCE (Hostel & Mess)
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendance_type TEXT NOT NULL CHECK (attendance_type IN ('hostel', 'mess')),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    meal_type TEXT CHECK (meal_type IN ('Breakfast', 'Lunch', 'Hi-Tea', 'Dinner')), -- Only for mess
    status TEXT DEFAULT 'Present' CHECK (status IN ('Present', 'Absent')),
    marked_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- COMPLAINTS
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT CHECK (category IN ('Electrical', 'Plumbing', 'Cleaning', 'Roommate', 'Food', 'Other')),
    status TEXT DEFAULT 'Open' CHECK (status IN ('Open', 'In-Progress', 'Resolved', 'Closed')),
    priority TEXT DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    image_url TEXT,
    resolved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- CHATS (Messaging)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id TEXT NOT NULL, -- Unique identifier for chat between two users or a group
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES public.profiles(id), -- NULL if group chat
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. SECURITY (RLS)
-- ==========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hostel_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hostel_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- SIMPLE PUBLIC POLICIES (Adjust for production)
DROP POLICY IF EXISTS "public_view_profiles" ON public.profiles;
CREATE POLICY "public_view_profiles" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_view_rooms" ON public.hostel_rooms;
CREATE POLICY "public_view_rooms" ON public.hostel_rooms FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_view_shop" ON public.shop_items;
CREATE POLICY "public_view_shop" ON public.shop_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "user_view_own_enrollments" ON public.hostel_enrollments;
CREATE POLICY "user_view_own_enrollments" ON public.hostel_enrollments FOR SELECT USING (auth.uid() = student_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('hostel_manager', 'hostel_owner')));

DROP POLICY IF EXISTS "user_view_own_orders" ON public.shop_orders;
CREATE POLICY "user_view_own_orders" ON public.shop_orders FOR SELECT USING (auth.uid() = customer_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('shop_admin')));

DROP POLICY IF EXISTS "attendance_access" ON public.attendance;
CREATE POLICY "attendance_access" ON public.attendance FOR ALL USING (true);

DROP POLICY IF EXISTS "complaint_access" ON public.complaints;
CREATE POLICY "complaint_access" ON public.complaints FOR ALL USING (true);

DROP POLICY IF EXISTS "message_access" ON public.messages;
CREATE POLICY "message_access" ON public.messages FOR ALL USING (true);

-- 4. AUTOMATED PROFILE CREATION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, role)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'avatar_url', COALESCE(NEW.raw_user_meta_data->>'role', 'store_customer'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 5. INITIAL SEED DATA
-- Add some sample rooms
INSERT INTO public.hostel_rooms (room_number, wing, floor, capacity, base_price, room_type, amenities, description) VALUES
('101', 'A-Block', 1, 2, 5000, 'Double', '["WiFi", "Laundry"]', 'Pool view double room'),
('102', 'A-Block', 1, 1, 8000, 'Single', '["AC", "WiFi", "Attached Bath"]', 'Premium single suite'),
('201', 'B-Block', 2, 4, 3500, 'Dorm', '["WiFi", "Locker"]', 'Spacious dorm room')
ON CONFLICT (room_number) DO NOTHING;

-- Add some sample shop items
-- LEGACY SEED (7 columns)
INSERT INTO public.shop_items (name, sku_qr, category, price, discount_price, stock_quantity, description) VALUES
-- Snacks & Munchies
('Lay''s Magic Masala (50g)', 'LAYS-MASALA', 'Snacks', 20, 15, 150, 'Spicy potato chips - 50g pack'),
('Kurkure Masala Munch (90g)', 'KURK-001', 'Snacks', 20, 18, 120, 'Crunchy masala sticks - 90g pack'),
('Uncle Chipps Spicy (50g)', 'UNCLE-001', 'Snacks', 20, 18, 80, 'Spicy potato chips - 50g classic'),
('Bingo Mad Angles (80g)', 'BINGO-001', 'Snacks', 20, 18, 100, 'Achaari Masti - 80g pack'),
('Haldiram Alu Bhujia (150g)', 'HALD-001', 'Snacks', 35, 30, 60, 'Traditional Indian snack - 150g'),
('Oreo Original (120g)', 'OREO-001', 'Snacks', 30, 25, 90, 'Vanilla cream biscuits - 120g tube'),
('Parle-G (200g)', 'PARLE-G', 'Snacks', 20, 18, 500, 'Original Glucose biscuits - 200g'),
('Britannia Bourbon (150g)', 'BRIT-BOUR', 'Snacks', 40, 35, 100, 'Classic chocolate cream - 150g'),
('Hide & Seek Choco (100g)', 'HIDE-SEEK', 'Snacks', 50, 45, 80, 'Premium chocolate chips - 100g'),
('Act II Butter Popcorn (30g)', 'ACT2-BUT', 'Snacks', 35, 30, 60, 'Instant microwave - 30g pack'),
('Too Yumm Chips (40g)', 'TOO-YUMM', 'Snacks', 20, 15, 120, 'Healthy baked multigrain chips - 40g'),
('Princesse Wafers (100g)', 'WAFER-001', 'Snacks', 40, 35, 50, 'Crunchy strawberry rolls - 100g'),
('Kinder Joy (20g)', 'KINDER-JOY', 'Snacks', 45, 40, 100, 'Chocolate & toy surprise - 20g'),
('KitKat 4 Finger (45g)', 'KITKAT-4', 'Snacks', 40, 35, 200, 'Crispy wafer in chocolate - 45g'),
('Maggi Pazzta (70g)', 'MAGGI-PAZ', 'Snacks', 30, 25, 50, 'Instant cheesy tomato - 70g'),
('Kellogg''s Chocos (250g)', 'CHOC-001', 'Snacks', 120, 110, 40, 'Chocolate breakfast cereal - 250g'),

-- Beverages & Energy
('Coca Cola (500ml)', 'COKE-500', 'Beverages', 40, 38, 100, 'Original refreshing cola - 500ml'),
('Pepsi Black (500ml)', 'PEPSI-500', 'Beverages', 40, 38, 100, 'Zero sugar refreshing cola - 500ml'),
('Sprite (500ml)', 'SPRITE-500', 'Beverages', 40, 38, 100, 'Lemony fresh lime - 500ml pet'),
('Monster Energy (350ml)', 'MONSTER-001', 'Beverages', 110, 105, 30, 'LHR Edition Energy - 350ml'),
('Red Bull (250ml)', 'REDBULL-250', 'Beverages', 125, 115, 40, 'Premium energy drink - 250ml'),
('Sting Energy (250ml)', 'STING-250', 'Beverages', 20, 18, 200, 'Berry blast energy - 250ml'),
('Nescafe Classic (50g)', 'NES-50LC', 'Beverages', 160, 150, 25, 'Rich instant coffee - 50g glass'),
('Society Tea (250g)', 'SOC-TEA', 'Beverages', 135, 125, 20, 'Premium leaf tea - 250g pack'),
('Red Label (250g)', 'RED-TEA', 'Beverages', 140, 130, 30, 'Strong black tea - 250g carton'),
('Appy Fizz (160ml)', 'APPY-FIZZ', 'Beverages', 15, 12, 150, 'Sparkling apple treat - 160ml can'),
('Frooti (160ml)', 'FROOTI-250', 'Beverages', 15, 12, 100, 'Mango fruit nectar - 160ml tetra'),
('Maaza (600ml)', 'MAAZA-600', 'Beverages', 45, 40, 80, 'Thick mango drink - 600ml bottle'),
('Limca (500ml)', 'LIMCA-500', 'Beverages', 40, 38, 60, 'Refreshing cloudy lime - 500ml'),
('Mountain Dew (500ml)', 'DEW-500', 'Beverages', 40, 38, 70, 'Bold citrus exhilarator - 500ml'),
('Hershey''s Milkshake (200ml)', 'HERS-MILK', 'Beverages', 40, 35, 50, 'Premium chocolate shake - 200ml tetra'),
('Cadbury Hot Choc (250g)', 'CAD-HOT', 'Beverages', 150, 140, 20, 'Ready mix drink - 250g jar'),

-- Dairy & Breakfast
('Amul Gold (500ml)', 'AMUL-GOLD', 'Dairy', 33, 31, 40, 'Full cream fresh milk - 500ml'),
('Amul Butter (100g)', 'AMUL-BUTTER', 'Dairy', 56, 52, 30, 'Classic salted butter - 100g pack'),
('Amul Cheese (200g)', 'AMUL-CHEESE', 'Dairy', 145, 135, 15, '10 slices processed - 200g'),
('Mother Dairy Curd (400g)', 'MD-CURD', 'Dairy', 30, 28, 25, 'Creamy fresh dahi - 400g cup'),
('Amul Cool (200ml)', 'AMUL-COOL', 'Dairy', 30, 25, 60, 'Kesar flavored milk - 200ml pet'),
('Amul Lassi (250ml)', 'AMUL-LASSI', 'Dairy', 15, 12, 100, 'Sweet probiotic drink - 250ml'),
('Paneer Fresh (200g)', 'PANEER-200', 'Dairy', 90, 80, 20, 'High protein cottage cheese - 200g'),
('Peanut Butter (340g)', 'PB-340', 'Dairy', 180, 160, 15, 'Creamy high protein - 340g jar'),
('Nutella (350g)', 'NUTELLA-350', 'Dairy', 450, 420, 10, 'Hazelnut spread - 350g glass'),
('Quaker Oats (400g)', 'QUAKER-OATS', 'Dairy', 95, 85, 30, 'Wholegrain breakfast - 400g'),
('Maggi Oats Noodles (280g)', 'MAGGI-OATS', 'Dairy', 150, 140, 30, 'Healthy wheat noodles - 280g'),
('Brown Bread (400g)', 'BREAD-BROWN', 'Dairy', 55, 50, 20, 'Premium whole wheat - 400g loaf'),
('Eggs (6 Nos)', 'EGGS-6', 'Dairy', 42, 38, 50, 'Farm fresh white eggs - 6 pack'),

-- Health & Hygiene
('Dove Shampoo (180ml)', 'DOVE-SHAM', 'Personal Care', 185, 165, 20, 'Deep moisturizing - 180ml bottle'),
('Dettol Liquid (200ml)', 'DETT-HW', 'Personal Care', 99, 89, 45, 'Original handwash - 200ml pump'),
('Park Avenue (150ml)', 'PARK-DEO', 'Personal Care', 210, 180, 15, 'Signature body spray - 150ml can'),
('Gillette (3 Nos)', 'GILL-M3', 'Personal Care', 450, 399, 10, 'Mach 3 Turbo Razors - 3 pack'),
('Nivea Balm (4.8g)', 'NIV-LIP', 'Personal Care', 175, 160, 25, 'Original essential care - 4.8g'),
('Glow & Lovely (50g)', 'FL-50', 'Personal Care', 60, 55, 30, 'Premium face cream - 50g tube'),
('Wild Stone (150ml)', 'WS-EDGE', 'Personal Care', 199, 175, 20, 'Edge intense deo - 150ml'),
('Lifebuoy Soap (125g)', 'LIFE-SOAP', 'Personal Care', 35, 30, 100, 'Germ protection - 125g bar'),
('Colgate Max (150g)', 'COL-MAX', 'Personal Care', 95, 85, 40, 'Red spicy fresh - 150g box'),
('Sensodyne (70g)', 'SENSO-70', 'Personal Care', 120, 110, 20, 'Rapid relief for teeth - 70g'),
('Oral-B (Soft)', 'ORAL-B', 'Personal Care', 40, 35, 60, 'Gum care toothbrush - 1 unit'),
('DermiCool (150g)', 'DERMI-COOL', 'Personal Care', 110, 95, 25, 'Prickly heat powder - 150g'),
('Savlon (100ml)', 'SAVLON-100', 'Personal Care', 45, 40, 50, 'Antiseptic liquid - 100ml'),
('Whisper Ultra (7 Nos)', 'WHIS-ULTRA', 'Personal Care', 150, 135, 40, 'Ultra Soft protection - 7 XL'),

-- Stationery & Tech
('Classmate (A4/160)', 'CLASS-NOTE', 'Stationery', 65, 60, 200, 'Soft cover 160pg - A4'),
('Reynolds (5 Nos)', 'REYN-BLUE', 'Stationery', 50, 40, 100, 'Original ball pens - 5 pack'),
('Pilot V7 (1 unit)', 'PILOT-V7', 'Stationery', 70, 65, 50, 'Hi-Tecpoint blue - 1 unit'),
('Natraj (10 Nos)', 'NAT-PEN', 'Stationery', 50, 45, 40, 'Classic pencils - 10 pack'),
('Sticky Notes (100s)', 'STICKY-001', 'Stationery', 45, 40, 30, 'Yellow neon pads - 100 sheets'),
('Casio (fx-991EX)', 'CASIO-991', 'Stationery', 1200, 1100, 10, 'Classwiz engineering cal'),
('SanDisk (64GB)', 'SAND-64', 'Stationery', 650, 599, 15, 'Ultra dual USB 3.0 - 64GB'),
('Boat (Bassheads)', 'BOAT-225', 'Stationery', 499, 449, 20, 'Model 225 wired - 1 unit'),
('Duracell (2 Nos)', 'DURA-AA', 'Stationery', 80, 75, 60, 'Ultra alkaline AA - 2 pack'),
('Syska 10000mAh Power', 'SYSKA-100', 'Stationery', 999, 849, 10, 'PowerPort duo - 10000mAh'),
('Uniball (Blue/1)', 'UNI-EYE', 'Stationery', 100, 90, 40, 'Eye micro waterproof - 1 unit')
ON CONFLICT (sku_qr) DO NOTHING;

-- HIGH-FIDELITY ELITE SEED (15 columns)
INSERT INTO public.shop_items (name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, rating, total_reviews, shelf_life, tags) VALUES
('Lay''s Magic Masala (50g)', 'LAYS-MASALA', 'Snacks', 20, 15, 150, 'Spicy potato chips - 50g pack', 'Lay''s', '50g', 'Packet', TRUE, 4.8, 1200, '6 Months', ARRAY['Spicy', 'Veg']),
('Kurkure Masala Munch (90g)', 'KURK-001', 'Snacks', 20, 18, 120, 'Crunchy masala sticks - 90g pack', 'Kurkure', '90g', 'Packet', TRUE, 4.7, 850, '4 Months', ARRAY['Masala', 'Veg']),
('Uncle Chipps Spicy (50g)', 'UNCLE-001', 'Snacks', 20, 18, 80, 'Spicy potato chips - 50g classic', 'Uncle Chipps', '50g', 'Packet', FALSE, 4.5, 400, '6 Months', ARRAY['Classic', 'Veg']),
('Bingo Mad Angles (80g)', 'BINGO-001', 'Snacks', 20, 18, 100, 'Achaari Masti - 80g pack', 'Bingo', '80g', 'Packet', FALSE, 4.6, 300, '6 Months', ARRAY['Tangy', 'Veg']),
('Haldiram Alu Bhujia (150g)', 'HALD-001', 'Snacks', 35, 30, 60, 'Traditional Indian snack - 150g', 'Haldiram', '150g', 'Packet', TRUE, 4.9, 2100, '6 Months', ARRAY['Savory', 'Veg']),
('Oreo Original (120g)', 'OREO-001', 'Snacks', 30, 25, 90, 'Vanilla cream biscuits - 120g tube', 'Oreo', '120g', 'Tube', TRUE, 4.8, 1500, '9 Months', ARRAY['Sweet', 'Veg']),
('Parle-G (200g)', 'PARLE-G', 'Snacks', 20, 18, 500, 'Original Glucose biscuits - 200g', 'Parle', '200g', 'Packet', TRUE, 4.9, 5000, '12 Months', ARRAY['Classic', 'Veg']),
('Britannia Bourbon (150g)', 'BRIT-BOUR', 'Snacks', 40, 35, 100, 'Classic chocolate cream - 150g', 'Britannia', '150g', 'Packet', FALSE, 4.5, 600, '9 Months', ARRAY['Sweet', 'Veg']),
('Hide & Seek Choco (100g)', 'HIDE-SEEK', 'Snacks', 50, 45, 80, 'Premium chocolate chips - 100g', 'Parle', '100g', 'Packet', TRUE, 4.8, 900, '9 Months', ARRAY['Premium', 'Veg']),
('Act II Butter Popcorn (30g)', 'ACT2-BUT', 'Snacks', 35, 30, 60, 'Instant microwave - 30g pack', 'Act II', '30g', 'Packet', FALSE, 4.4, 250, '12 Months', ARRAY['Instant', 'Veg']),
('Too Yumm Chips (40g)', 'TOO-YUMM', 'Snacks', 20, 15, 120, 'Healthy baked multigrain chips - 40g', 'Too Yumm', '40g', 'Packet', FALSE, 4.3, 180, '6 Months', ARRAY['Healthy', 'Veg']),
('Princesse Wafers (100g)', 'WAFER-001', 'Snacks', 40, 35, 50, 'Crunchy strawberry rolls - 100g', 'Princesse', '100g', 'Packet', FALSE, 4.2, 120, '9 Months', ARRAY['Sweet', 'Veg']),
('Kinder Joy (20g)', 'KINDER-JOY', 'Snacks', 45, 40, 100, 'Chocolate & toy surprise - 20g', 'Kinder', '20g', 'Egg', TRUE, 4.7, 1100, '12 Months', ARRAY['Kids', 'Veg']),
('KitKat 4 Finger (45g)', 'KITKAT-4', 'Snacks', 40, 35, 200, 'Crispy wafer in chocolate - 45g', 'Nestle', '45g', 'Bar', TRUE, 4.8, 2500, '9 Months', ARRAY['Sweet', 'Veg']),
('Maggi Pazzta (70g)', 'MAGGI-PAZ', 'Snacks', 30, 25, 50, 'Instant cheesy tomato - 70g', 'Maggi', '70g', 'Packet', FALSE, 4.4, 450, '9 Months', ARRAY['Instant', 'Veg']),
('Kellogg''s Chocos (250g)', 'CHOC-001', 'Snacks', 120, 100, 40, 'Chocolate breakfast cereal - 250g', 'Kellogg''s', '250g', 'Box', TRUE, 4.7, 800, '12 Months', ARRAY['Breakfast', 'Veg']),
('Lotte Choco Pie (30g)', 'LOTTE-CHOCO', 'Snacks', 15, 12, 150, 'Marshmallow melt - 30g unit', 'Lotte', '30g', 'Packet', TRUE, 4.6, 1200, '9 Months', ARRAY['Sweet', 'Veg']),
('Melody (100 Nos)', 'MELODY-PK', 'Snacks', 100, 90, 40, 'Chocolaty toffee - 100 unit pack', 'Parle', '100 units', 'Jar', FALSE, 4.8, 950, '12 Months', ARRAY['Sweet', 'Veg']),
('Happydent (6 Nos)', 'HAPPYDENT', 'Snacks', 10, 8, 200, 'White peppermint - 6 unit strip', 'Happydent', '6 units', 'Strip', TRUE, 4.5, 3000, '24 Months', ARRAY['Mint', 'Veg']),
('Pulse (50 Nos)', 'PULSE-PK', 'Snacks', 50, 45, 50, 'Mango burst candy - 50 unit pack', 'Pass Pass', '50 units', 'Pouch', TRUE, 4.9, 4200, '12 Months', ARRAY['Tangy', 'Veg']),
('Maggi Masala (70g)', 'MAGGI-70', 'Snacks', 15, 12, 500, '2-minute noodles - 70g single', 'Maggi', '70g', 'Packet', TRUE, 4.9, 10000, '9 Months', ARRAY['Instant', 'Veg']),
('Top Ramen (70g)', 'TOP-RAMEN', 'Snacks', 15, 12, 100, 'Spicy curry noodles - 70g', 'Nissin', '70g', 'Packet', FALSE, 4.4, 800, '9 Months', ARRAY['Instant', 'Veg']),
('Wai Wai (70g)', 'WAI-WAI', 'Snacks', 20, 18, 150, 'Ready to eat noodles - 70g', 'Wai Wai', '70g', 'Packet', FALSE, 4.3, 600, '9 Months', ARRAY['Instant', 'Veg']),
('Ching''s Soup (15g)', 'CHINGS-SOUP', 'Snacks', 10, 8, 80, 'Hot & Sour instant veg soup', 'Ching''s Secret', '15g', 'Sachet', FALSE, 4.1, 400, '12 Months', ARRAY['Soup', 'Veg']),
('MTR Poha (60g)', 'MTR-POHA', 'Snacks', 45, 40, 30, 'Ready to eat breakfast - 60g cup', 'MTR', '60g', 'Cup', FALSE, 4.2, 200, '6 Months', ARRAY['Breakfast', 'Veg']),

-- Beverages (20 items)
('Coca Cola (500ml)', 'COKE-500', 'Beverages', 40, 38, 100, 'Original refreshing cola - 500ml', 'Coca Cola', '500ml', 'Bottle', TRUE, 4.7, 3500, '6 Months', ARRAY['Cola', 'Veg']),
('Pepsi Black (500ml)', 'PEPSI-500', 'Beverages', 40, 38, 100, 'Zero sugar refreshing cola - 500ml', 'Pepsi', '500ml', 'Bottle', FALSE, 4.5, 1200, '6 Months', ARRAY['Cola', 'Veg']),
('Sprite (500ml)', 'SPRITE-500', 'Beverages', 40, 38, 100, 'Lemony fresh lime - 500ml pet', 'Sprite', '500ml', 'Bottle', TRUE, 4.6, 2800, '6 Months', ARRAY['Lime', 'Veg']),
('Monster Energy (350ml)', 'MONSTER-001', 'Beverages', 110, 105, 30, 'LHR Edition Energy - 350ml', 'Monster', '350ml', 'Can', TRUE, 4.8, 900, '24 Months', ARRAY['Energy', 'Veg']),
('Red Bull (250ml)', 'REDBULL-250', 'Beverages', 125, 115, 40, 'Premium energy drink - 250ml', 'Red Bull', '250ml', 'Can', TRUE, 4.9, 1500, '24 Months', ARRAY['Energy', 'Veg']),
('Sting Energy (250ml)', 'STING-250', 'Beverages', 20, 18, 200, 'Berry blast energy - 250ml', 'Sting', '250ml', 'Bottle', TRUE, 4.3, 4000, '6 Months', ARRAY['Energy', 'Veg']),
('Nescafe Coffee (50g)', 'NES-50LC', 'Beverages', 160, 150, 25, 'Instant coffee powder - 50g jar', 'Nescafe', '50g', 'Jar', TRUE, 4.8, 800, '18 Months', ARRAY['Coffee', 'Veg']),
('Society Tea (250g)', 'SOC-TEA', 'Beverages', 135, 125, 20, 'Premium black tea - 250g pack', 'Society', '250g', 'Packet', FALSE, 4.7, 400, '12 Months', ARRAY['Tea', 'Veg']),
('Red Label Tea (250g)', 'RED-TEA', 'Beverages', 140, 130, 30, 'Strong black tea - 250g pack', 'Brooke Bond', '250g', 'Packet', TRUE, 4.7, 1100, '12 Months', ARRAY['Tea', 'Veg']),
('Appy Fizz (160ml)', 'APPY-FIZZ', 'Beverages', 15, 12, 150, 'Sparkling apple drink - 160ml', 'Appy', '160ml', 'Bottle', FALSE, 4.4, 1500, '9 Months', ARRAY['Fruit', 'Veg']),
('Frooti (160ml)', 'FROOTI-250', 'Beverages', 15, 12, 100, 'Mango fruit nectar - 160ml tetra', 'Frooti', '160ml', 'Tetra', FALSE, 4.3, 1200, '6 Months', ARRAY['Fruit', 'Veg']),
('Maaza (600ml)', 'MAAZA-600', 'Beverages', 45, 40, 80, 'Thick mango indulgence - 600ml', 'Maaza', '600ml', 'Bottle', TRUE, 4.7, 2400, '6 Months', ARRAY['Fruit', 'Veg']),
('Limca (500ml)', 'LIMCA-500', 'Beverages', 40, 38, 60, 'Refreshing cloudy lime - 500ml', 'Limca', '500ml', 'Bottle', FALSE, 4.5, 1800, '6 Months', ARRAY['Lime', 'Veg']),
('Mountain Dew (500ml)', 'DEW-500', 'Beverages', 40, 38, 70, 'Bold neon citrus - 500ml', 'Mountain Dew', '500ml', 'Bottle', FALSE, 4.6, 1100, '6 Months', ARRAY['Citrus', 'Veg']),
('Hershey''s Shake (200ml)', 'HERS-MILK', 'Beverages', 40, 35, 50, 'Creamy chocolate milkshake', 'Hershey''s', '200ml', 'Tetra', TRUE, 4.8, 750, '9 Months', ARRAY['Dairy', 'Veg']),
('Cadbury Hot Choc (250g)', 'CAD-HOT', 'Beverages', 150, 140, 20, 'Instant hot chocolate mix', 'Cadbury', '250g', 'Jar', FALSE, 4.7, 300, '12 Months', ARRAY['Sweet', 'Veg']),
('Paper Boat (200ml)', 'PB-AAM', 'Beverages', 35, 30, 40, 'Memories of summer aamras', 'Paper Boat', '200ml', 'Pouch', TRUE, 4.8, 1400, '6 Months', ARRAY['Fruit', 'Veg']),
('Bisleri (1L)', 'BISL-1L', 'Beverages', 20, 18, 500, 'Purified mineral water - 1L', 'Bisleri', '1L', 'Bottle', TRUE, 4.9, 10000, '12 Months', ARRAY['Water', 'Veg']),
('Real Cranberry (1L)', 'REAL-CRAN', 'Beverages', 125, 110, 20, 'Premium fruit juice - 1L tetra', 'Real', '1L', 'Tetra', FALSE, 4.6, 900, '7 Months', ARRAY['Fruit', 'Veg']),
('Real Orange (1L)', 'REAL-ORN', 'Beverages', 125, 110, 20, 'Fresh orange nectar - 1L tetra', 'Real', '1L', 'Tetra', FALSE, 4.5, 800, '7 Months', ARRAY['Fruit', 'Veg']),

-- Dairy & Breakfast (15 items)
('Amul Gold (500ml)', 'AMUL-GOLD', 'Dairy', 33, 31, 40, 'Full cream fresh milk - 500ml', 'Amul', '500ml', 'Pouch', TRUE, 4.9, 12000, '2 Days', ARRAY['Fresh', 'Veg']),
('Amul Butter (100g)', 'AMUL-BUTTER', 'Dairy', 56, 52, 30, 'Classic salted butter - 100g', 'Amul', '100g', 'Box', TRUE, 4.9, 4500, '12 Months', ARRAY['Fresh', 'Veg']),
('Amul Cheese (200g)', 'AMUL-CHEESE', 'Dairy', 145, 135, 15, 'Processed cheese slices - 10 unit', 'Amul', '200g', 'Packet', TRUE, 4.8, 2200, '9 Months', ARRAY['Fresh', 'Veg']),
('Mother Dairy Curd (400g)', 'MD-CURD', 'Dairy', 30, 28, 25, 'Fresh thick dahi - 400g cup', 'Mother Dairy', '400g', 'Cup', TRUE, 4.7, 1800, '15 Days', ARRAY['Fresh', 'Veg']),
('Amul Cool Milk (200ml)', 'AMUL-COOL', 'Dairy', 30, 25, 60, 'Kesar flavored milk - 200ml', 'Amul', '200ml', 'Bottle', FALSE, 4.5, 950, '6 Months', ARRAY['Milk', 'Veg']),
('Amul Lassi (250ml)', 'AMUL-LASSI', 'Dairy', 15, 12, 100, 'Sweet probiotic lassi - 250ml', 'Amul', '250ml', 'Tetra', FALSE, 4.6, 1600, '6 Months', ARRAY['Probiotic', 'Veg']),
('Fresh Paneer (200g)', 'PANEER-200', 'Dairy', 90, 80, 20, 'Fresh cottage cheese - 200g pack', 'Amul', '200g', 'Packet', TRUE, 4.8, 1400, '15 Days', ARRAY['Protein', 'Veg']),
('Peanut Butter (340g)', 'PB-340', 'Dairy', 180, 160, 15, 'Creamy unsweetened - 340g', 'Dr. Oetker', '340g', 'Jar', FALSE, 4.7, 600, '12 Months', ARRAY['Protein', 'Veg']),
('Nutella (350g)', 'NUTELLA-350', 'Dairy', 450, 420, 10, 'Hazelnut cocoa spread - 350g', 'Ferrero', '350g', 'Jar', TRUE, 4.9, 3200, '12 Months', ARRAY['Sweet', 'Veg']),
('Quaker Oats (400g)', 'QUAKER-OATS', 'Dairy', 95, 85, 30, 'Wholegrain nutritional oats - 400g', 'Quaker', '400g', 'Packet', FALSE, 4.6, 1100, '12 Months', ARRAY['Healthy', 'Veg']),
('Brown Bread (400g)', 'BREAD-BROWN', 'Dairy', 55, 50, 20, 'Whole wheat premium bread - 400g', 'Harvest Gold', '400g', 'Packet', TRUE, 4.7, 2400, '4 Days', ARRAY['Whole Wheat', 'Veg']),
('Fresh Eggs (6 Nos)', 'EGGS-6', 'Dairy', 42, 38, 50, 'Farm fresh white eggs - 6 pack', 'Local Farm', '6 units', 'Box', TRUE, 4.8, 5000, '15 Days', ARRAY['Protein', 'Non-Veg']),
('Yakult (5 Nos)', 'YAKULT', 'Dairy', 80, 75, 30, 'Probiotic milk beverage - 5 pack', 'Yakult', '5 units', 'Pack', FALSE, 4.8, 800, '30 Days', ARRAY['Probiotic', 'Veg']),
('Amul Mozzarella (200g)', 'AMUL-PIZZA', 'Dairy', 125, 115, 20, 'Diced pizza cheese - 200g', 'Amul', '200g', 'Packet', FALSE, 4.7, 450, '6 Months', ARRAY['Fresh', 'Veg']),
('Greek Yogurt (100g)', 'YOGURT-100', 'Dairy', 45, 40, 30, 'Strawberry high protein yogurt', 'Epigamia', '100g', 'Cup', TRUE, 4.6, 600, '15 Days', ARRAY['Healthy', 'Veg']),

-- Health & Hygiene (15 items)
('Dove Shampoo (180ml)', 'DOVE-SHAM', 'Personal Care', 185, 165, 20, 'Moisturizing care shampoo - 180ml', 'Dove', '180ml', 'Bottle', TRUE, 4.8, 4500, '24 Months', ARRAY['Beauty', 'Veg']),
('Dettol Liquid (200ml)', 'DETT-HW', 'Personal Care', 99, 89, 45, 'Antibacterial original handwash', 'Dettol', '200ml', 'Pump', TRUE, 4.9, 12000, '24 Months', ARRAY['Health', 'Veg']),
('Park Avenue Deo (150ml)', 'PARK-DEO', 'Personal Care', 210, 180, 15, 'Signature men fragrance - 150ml', 'Park Avenue', '150ml', 'Can', FALSE, 4.6, 900, '36 Months', ARRAY['Beauty', 'Veg']),
('Gillette Mach 3 (1U)', 'GILL-M3', 'Personal Care', 450, 399, 10, 'Premium precision razor - 1 unit', 'Gillette', '1 unit', 'Box', TRUE, 4.9, 2100, '48 Months', ARRAY['Beauty', 'Veg']),
('Nivea Lip Balm (4.8g)', 'NIV-LIP', 'Personal Care', 175, 160, 25, 'Essential care lip balm - 4.8g', 'Nivea', '4.8g', 'Tube', FALSE, 4.7, 1500, '24 Months', ARRAY['Beauty', 'Veg']),
('Glow & Lovely (50g)', 'FL-50', 'Personal Care', 60, 55, 30, 'Advanced multivitamin face cream', 'Glow & Lovely', '50g', 'Tube', FALSE, 4.5, 3200, '24 Months', ARRAY['Beauty', 'Veg']),
('Lifebuoy Soap (125g)', 'LIFE-SOAP', 'Personal Care', 35, 30, 100, 'Total germ protection soap', 'Lifebuoy', '125g', 'Bar', TRUE, 4.7, 15000, '36 Months', ARRAY['Health', 'Veg']),
('Colgate MaxFresh (150g)', 'COL-MAX', 'Personal Care', 95, 85, 40, 'Lal spicy fresh toothpaste - 150g', 'Colgate', '150g', 'Box', TRUE, 4.8, 8000, '24 Months', ARRAY['Care', 'Veg']),
('Sensodyne (70g)', 'SENSO-70', 'Personal Care', 120, 110, 20, 'Rapid relief sensitive teeth', 'Sensodyne', '70g', 'Box', FALSE, 4.8, 2500, '24 Months', ARRAY['Care', 'Veg']),
('Oral-B (Soft)', 'ORAL-B', 'Personal Care', 40, 35, 60, 'Gum care reach toothbrush - 1 unit', 'Oral-B', '1 unit', 'Pack', FALSE, 4.5, 4200, '36 Months', ARRAY['Care', 'Veg']),
('DermiCool (150g)', 'DERMI-COOL', 'Personal Care', 110, 95, 25, 'Prickly heat cooling powder', 'DermiCool', '150g', 'Bottle', TRUE, 4.6, 1100, '36 Months', ARRAY['Health', 'Veg']),
('Whisper Ultra (7 XL)', 'WHIS-ULTRA', 'Personal Care', 150, 135, 40, 'Sanitary pads extra large - 7 unit', 'Whisper', '7 units', 'Packet', TRUE, 4.9, 9000, '36 Months', ARRAY['Care', 'Veg']),
('Vicks Vaporub (25g)', 'VICKS-25', 'Personal Care', 85, 80, 20, 'Cold & cough rapid relief - 25g', 'Vicks', '25g', 'Jar', FALSE, 4.8, 1400, '36 Months', ARRAY['Health', 'Veg']),
('Dettol Soap (125g)', 'DETT-SOAP', 'Personal Care', 45, 40, 100, 'Original germ kill bar - 125g', 'Dettol', '125g', 'Bar', TRUE, 4.8, 12000, '36 Months', ARRAY['Health', 'Veg']),
('Set Wet Gel (50ml)', 'SETWET', 'Personal Care', 60, 55, 30, 'Cool hold hair styling gel', 'Set Wet', '50ml', 'Jar', FALSE, 4.4, 1800, '24 Months', ARRAY['Beauty', 'Veg']),

-- Stationery & Tech (15 items)
('Classmate (A4/160)', 'CLASS-NOTE', 'Stationery', 65, 60, 200, 'Long book soft cover - A4 160pg', 'Classmate', 'A4 160pg', 'Book', TRUE, 4.9, 12000, 'Long-Lasting', ARRAY['Study', 'Veg']),
('Reynolds (5 Nos)', 'REYN-BLUE', 'Stationery', 50, 45, 100, 'Original classic ball pens - Blue', 'Reynolds', '5 units', 'Pack', TRUE, 4.8, 25000, 'Classic', ARRAY['Study', 'Veg']),
('Pilot V7 (Blue)', 'PILOT-V7', 'Stationery', 70, 65, 50, 'Hi-Tecpoint liquid ink - Blue', 'Pilot', '1 unit', 'Pen', FALSE, 4.8, 4500, 'Reliable', ARRAY['Study', 'Veg']),
('Sticky Notes (100s)', 'STICKY-001', 'Stationery', 45, 40, 30, 'Neon yellow 3x3 sticky pads', 'Post-It', '100 sheets', 'Pad', FALSE, 4.7, 1200, 'Office', ARRAY['Study', 'Veg']),
('Casio (fx-991EX)', 'CASIO-991', 'Stationery', 1200, 1100, 10, 'Classwiz engineering scientific', 'Casio', '1 unit', 'Box', TRUE, 4.9, 3200, 'Complex', ARRAY['Study', 'Veg']),
('SanDisk (64GB)', 'SAND-64', 'Stationery', 650, 599, 15, 'Ultra dual drive USB 3.0 m3.0', 'SanDisk', '64GB', 'Pack', TRUE, 4.8, 2400, 'Digital', ARRAY['Tech', 'Veg']),
('Boat Bassheads 225', 'BOAT-225', 'Stationery', 499, 449, 20, 'Premium wired earphones - Black', 'Boat', '1 unit', 'Box', TRUE, 4.7, 8500, 'Digital', ARRAY['Tech', 'Veg']),
('Duracell AA (2 Nos)', 'DURA-AA', 'Stationery', 80, 75, 60, 'Ultra alkaline batteries - LR6', 'Duracell', '2 units', 'Pack', FALSE, 4.9, 3000, 'Power', ARRAY['Tech', 'Veg']),
('Syska (10K mAh)', 'SYSKA-100', 'Stationery', 999, 849, 10, 'PowerPort dual port - 10000mAh', 'Syska', '10000mAh', 'Box', FALSE, 4.6, 1100, 'Power', ARRAY['Tech', 'Veg']),
('Uniball (Blue/1)', 'UNI-EYE', 'Stationery', 100, 90, 40, 'Eye Micro waterproof ink - Blue', 'Uniball', '1 unit', 'Pen', FALSE, 4.8, 3800, 'Premium', ARRAY['Study', 'Veg']),
('Camlin Geometry Box', 'CAM-GEO', 'Stationery', 150, 135, 20, 'Scholastic precision mathematical', 'Camlin', '1 unit', 'Box', TRUE, 4.7, 2100, 'Study', ARRAY['Study', 'Veg']),
('Apsara Pencils (10U)', 'APSARA-10', 'Stationery', 50, 45, 50, 'Platinum extra dark pencils', 'Apsara', '10 units', 'Box', TRUE, 4.9, 15000, 'Study', ARRAY['Study', 'Veg']),
('Fevistick (15g)', 'FEVI-15', 'Stationery', 35, 30, 40, 'Non-toxic glue stick premium', 'Fevicol', '15g', 'Tube', FALSE, 4.7, 5000, 'Office', ARRAY['Study', 'Veg']),
('Oxford Dictionary', 'OXFORD-MINI', 'Stationery', 250, 220, 15, 'Mini English dictionary portable', 'Oxford', '1 unit', 'Book', FALSE, 4.8, 800, 'Study', ARRAY['Study', 'Veg']),
('Parker Jotter (1U)', 'PARKER-J', 'Stationery', 350, 310, 10, 'Stainless steel ball pen classic', 'Parker', '1 unit', 'Case', TRUE, 4.9, 1200, 'Premium', ARRAY['Study', 'Veg']),

-- Home Needs (10 items)
('Comfort (800ml)', 'COMFORT-800', 'Home Needs', 220, 200, 15, 'Morning fresh fabric conditioner', 'Comfort', '800ml', 'Pouch', TRUE, 4.8, 3200, '24 Months', ARRAY['Hostel', 'Veg']),
('Surf Excel (500g)', 'SURF-500', 'Home Needs', 65, 60, 25, 'Easy wash high efficient detergent', 'Surf Excel', '500g', 'Packet', TRUE, 4.9, 11000, '24 Months', ARRAY['Hostel', 'Veg']),
('Vim Gel (250ml)', 'VIM-250', 'Home Needs', 50, 45, 30, 'Lemon fresh dishwash liquid', 'Vim', '250ml', 'Pouch', TRUE, 4.9, 8500, '24 Months', ARRAY['Hostel', 'Veg']),
('Harpic Red (500ml)', 'HARPIC-RED', 'Home Needs', 99, 90, 40, 'Bathroom disinfectant fresh', 'Harpic', '500ml', 'Bottle', FALSE, 4.8, 6000, '24 Months', ARRAY['Hostel', 'Veg']),
('Lizol (500ml)', 'LIZOL-500', 'Home Needs', 105, 95, 30, 'Citrus disinfecting surface cleaner', 'Lizol', '500ml', 'Bottle', FALSE, 4.7, 5200, '24 Months', ARRAY['Hostel', 'Veg']),
('Mosquito Bat (Rech)', 'BAT-RECH', 'Home Needs', 250, 220, 15, 'Ultimate rechargeable zapper', 'Eveready', '1 unit', 'Box', TRUE, 4.6, 2800, '12 Months', ARRAY['Hostel', 'Veg']),
('All Out (45ml)', 'ALL-OUT', 'Home Needs', 85, 80, 30, 'Ultra power mosquito refill', 'All Out', '45ml', 'Bottle', TRUE, 4.7, 9500, '24 Months', ARRAY['Hostel', 'Veg']),
('Cloth Clips (12U)', 'CLIP-12', 'Home Needs', 40, 35, 50, 'Heavy duty anti-rust clips', 'Local', '12 units', 'Pack', FALSE, 4.3, 1400, 'Durable', ARRAY['Hostel', 'Veg']),
('Hangers (6 Nos)', 'HANG-6', 'Home Needs', 120, 100, 20, 'Premium plastic garment hangers', 'Local', '6 units', 'Pack', FALSE, 4.4, 2200, 'Durable', ARRAY['Hostel', 'Veg']),
('Plastic Bucket (20L)', 'BUCKET-SET', 'Home Needs', 350, 300, 10, 'High-grade robust plastic set', 'Cello', '20L', 'Set', TRUE, 4.5, 1100, 'Durable', ARRAY['Hostel', 'Veg']),

-- ADDITIONAL ELITE INVENTORY (100 more items)
-- Energy & Performance (15 items)
('Ghost Energy Sour Patch', 'ENERGY-GHOST', 'Beverages', 250, 230, 20, 'Sour Patch Kids flavor - 473ml', 'Ghost', '473ml', 'Can', TRUE, 4.9, 450, '24 Months', ARRAY['Energy', 'Zero Sugar']),
('C4 Performance Energy', 'ENERGY-C4', 'Beverages', 220, 200, 25, 'Explosive energy - 473ml', 'C4', '473ml', 'Can', FALSE, 4.7, 300, '24 Months', ARRAY['Energy', 'Pre-workout']),
('MuscleBlaze Whey Shaker', 'MB-SHAKE', 'Dairy', 300, 280, 15, '700ml leakproof protein shaker', 'MuscleBlaze', '700ml', 'Unit', TRUE, 4.5, 900, 'Durable', ARRAY['Fitness', 'BPA Free']),
('Protein Bar Choco', 'YOGA-BAR', 'Snacks', 60, 55, 50, '20g protein - almond choco', 'Yoga Bar', '50g', 'Bar', TRUE, 4.6, 1200, '9 Months', ARRAY['Fitness', 'Veg']),
('Gatorade Blue Bolt', 'GATOR-BLUE', 'Beverages', 50, 45, 100, 'Electrolyte drink - 500ml', 'Gatorade', '500ml', 'Bottle', TRUE, 4.7, 2800, '12 Months', ARRAY['Sports', 'Veg']),
('ORSL Apple Drink', 'ORSL-APP', 'Beverages', 40, 38, 50, 'Electrolyte recharge - 200ml', 'ORSL', '200ml', 'Tetra', FALSE, 4.8, 1100, '12 Months', ARRAY['Sports', 'Veg']),
('Hell Energy Classic', 'HELL-250', 'Beverages', 50, 45, 100, 'Focus & Energy - 250ml', 'Hell', '250ml', 'Can', FALSE, 4.4, 950, '18 Months', ARRAY['Energy', 'Veg']),
('Vitamin Water Reset', 'VIT-WATER', 'Beverages', 100, 90, 30, 'Dragonfruit flavor - 500ml', 'Glaceau', '500ml', 'Bottle', FALSE, 4.5, 400, '12 Months', ARRAY['Health', 'Veg']),
('Fast&Up Reload (20U)', 'FASTUP-20', 'Beverages', 350, 310, 20, 'Effervescent electrolytes - Lime', 'Fast&Up', '20 units', 'Tube', TRUE, 4.8, 1500, '24 Months', ARRAY['Sports', 'Veg']),
('Zevic Stevia Drops', 'ZEVIC-STE', 'Kitchen', 250, 220, 10, 'Natural sweetener - 30ml', 'Zevic', '30ml', 'Dropper', FALSE, 4.4, 300, '24 Months', ARRAY['Diet', 'Veg']),
('Honey Squeezy (250g)', 'DABUR-HONEY', 'Kitchen', 110, 100, 40, 'Pure natural honey - 250g', 'Dabur', '250g', 'Bottle', TRUE, 4.7, 2200, '18 Months', ARRAY['Natural', 'Veg']),
('Green Tea Tulsi (25U)', 'ORGANIC-GT', 'Beverages', 160, 145, 30, 'Classic Tulsi Green Tea - 25 bags', 'Organic India', '25 units', 'Box', TRUE, 4.8, 1800, '24 Months', ARRAY['Health', 'Veg']),
('Coffee Creamer (200g)', 'NESTLE-CRM', 'Dairy', 200, 180, 20, 'Rich coffee mate - 200g', 'Nestle', '200g', 'Jar', FALSE, 4.5, 600, '12 Months', ARRAY['Dairy', 'Veg']),

-- Premium Grooming & Skincare (20 items)
('The Man Co. Facewash', 'TMC-FW', 'Personal Care', 350, 320, 15, 'Charcoal deep cleanse - 100ml', 'The Man Co.', '100ml', 'Tube', TRUE, 4.7, 1200, '24 Months', ARRAY['Grooming', 'Premium']),
('Beardo Beard Oil', 'BEARDO-OIL', 'Personal Care', 299, 270, 12, 'Godfather signature - 30ml', 'Beardo', '30ml', 'Bottle', TRUE, 4.6, 950, '24 Months', ARRAY['Grooming', 'Premium']),
('Mamaearth Onion Oil', 'MAMA-OIL', 'Personal Care', 499, 450, 20, 'For hair fall control - 150ml', 'Mamaearth', '150ml', 'Bottle', TRUE, 4.8, 3500, '24 Months', ARRAY['Grooming', 'Natural']),
('Neutrogena Sunscreen', 'NEUT-SUN', 'Personal Care', 550, 499, 10, 'Ultra Sheer Dry-Touch SPF 50+', 'Neutrogena', '30ml', 'Tube', TRUE, 4.9, 5200, '36 Months', ARRAY['Skin', 'Premium']),
('L''Oreal Serioxyl', 'LOREAL-SER', 'Personal Care', 850, 799, 8, 'Advanced hair density - 90ml', 'L''Oreal', '90ml', 'Bottle', FALSE, 4.7, 1100, '36 Months', ARRAY['Grooming', 'Premium']),
('Bombay Shaving Kit', 'BS-KIT', 'Personal Care', 1200, 1100, 5, 'Complete 6-part shaving system', 'Bombay Shaving Co.', 'Set', 'Box', FALSE, 4.8, 800, '48 Months', ARRAY['Grooming', 'Premium']),
('Minoxidil 5% (60ml)', 'REGAINE', 'Personal Care', 750, 699, 15, 'Hair regrowth treatment - 60ml', 'Regaine', '60ml', 'Bottle', FALSE, 4.4, 2100, '24 Months', ARRAY['Health', 'Medical']),
('Cetaphil Cleanser', 'CETAPHIL', 'Personal Care', 320, 290, 20, 'Gentle skin cleanser - 125ml', 'Cetaphil', '125ml', 'Bottle', TRUE, 4.9, 15000, '36 Months', ARRAY['Skin', 'Premium']),
('Plum Green Tea Mist', 'PLUM-MIST', 'Personal Care', 360, 320, 15, 'Refresh & Control - 100ml', 'Plum', '100ml', 'Spray', FALSE, 4.6, 1200, '24 Months', ARRAY['Skin', 'Vegan']),
('mCaffeine Scrub', 'MCAF-SCRUB', 'Personal Care', 450, 399, 18, 'Coffee body scrub - 100g', 'mCaffeine', '100g', 'Jar', TRUE, 4.7, 8500, '24 Months', ARRAY['Grooming', 'Premium']),
('Philips OneBlade', 'PHIL-OB', 'Personal Care', 2200, 1999, 5, 'Hybrid trimmer & shaver - QP2525', 'Philips', '1 unit', 'Box', TRUE, 4.8, 12000, 'Durable', ARRAY['Grooming', 'Tech']),
('Nova Hair Dryer', 'NOVA-DRY', 'Personal Care', 850, 750, 10, 'Foldable 1200W pro dryer', 'Nova', '1 unit', 'Box', FALSE, 4.2, 3500, 'Durable', ARRAY['Grooming', 'Tech']),
('Garnier Sheet Mask', 'GAR-SHEET', 'Personal Care', 99, 89, 50, 'Hydra Bomb charcoal - 32g', 'Garnier', '32g', 'Sachet', TRUE, 4.5, 6000, '36 Months', ARRAY['Skin', 'Instant']),
('Biotique Papaya', 'BIO-PAP', 'Personal Care', 180, 160, 25, 'Revitalizing scrub facewash', 'Biotique', '100ml', 'Tube', FALSE, 4.4, 2800, '24 Months', ARRAY['Grooming', 'Natural']),
('Axe Signature (150ml)', 'AXE-SIG', 'Personal Care', 250, 220, 30, 'Elite concentrated fragrance', 'Axe', '150ml', 'Can', TRUE, 4.6, 9500, '36 Months', ARRAY['Beauty', 'Classic']),

-- Advanced Tech & Accessories (20 items)
('Apple EarPods (Type-C)', 'APPLE-EP', 'Stationery', 1900, 1800, 5, 'Original wired EarPods - Type C', 'Apple', '1 unit', 'Box', TRUE, 4.8, 1500, 'Durable', ARRAY['Tech', 'Elite']),
('Logitech B170 Mouse', 'LOGI-M170', 'Stationery', 650, 599, 12, 'Wireless optical mouse - 2.4GHz', 'Logitech', '1 unit', 'Box', TRUE, 4.7, 5200, 'Durable', ARRAY['Tech', 'Elite']),
('HDMI Cable 2.0 (1.5m)', 'HDMI-1.5', 'Stationery', 350, 300, 20, '4K Ultra HD braided cable', 'Generic', '1.5m', 'Bag', FALSE, 4.3, 800, 'Durable', ARRAY['Tech', 'Essential']),
('TP-Link USB Adapter', 'TPL-USB', 'Stationery', 550, 499, 10, '150Mbps Nano Wireless N', 'TP-Link', '1 unit', 'Box', TRUE, 4.6, 2100, 'Durable', ARRAY['Tech', 'Elite']),
('Laptop Sleeve (15")', 'SLEEVE-15', 'Stationery', 450, 399, 15, 'Neoprene padded protection', 'Generic', '15 inch', 'Bag', FALSE, 4.4, 600, 'Durable', ARRAY['Tech', 'Hostel']),
('Type-C PD 20W Wall', 'CHARG-20W', 'Stationery', 850, 750, 10, 'Fast charging pro adapter', 'Generic', '1 unit', 'Box', TRUE, 4.5, 1200, 'Durable', ARRAY['Tech', 'Essential']),
('Braided C-to-C Cable', 'CABLE-CC', 'Stationery', 299, 250, 30, '60W PD Fast Charging - 2m', 'Generic', '2m', 'Bag', TRUE, 4.4, 1800, 'Durable', ARRAY['Tech', 'Essential']),
('Ring Light (10 inch)', 'RING-10', 'Stationery', 1200, 999, 5, 'With tripod for streaming', 'Generic', '1 unit', 'Box', FALSE, 4.1, 450, 'Durable', ARRAY['Tech', 'Hostel']),
('RGB LED Strip (5m)', 'LED-5M', 'Home Needs', 499, 449, 15, 'Remote controlled room decor', 'Generic', '5m', 'Box', TRUE, 4.5, 3200, 'Durable', ARRAY['Decor', 'Hostel']),
('Extension Board (4S)', 'EXT-4S', 'Home Needs', 550, 499, 10, 'Heavy duty 2.5m cable + 4 sockets', 'Anchor', '1 unit', 'Box', TRUE, 4.8, 1100, 'Durable', ARRAY['Tech', 'Essential']),

-- Kitchen & Pantry (20 items)
('Maggi Family (420g)', 'MAGGI-FAM', 'Snacks', 60, 56, 100, 'Family saver pack - 6 units', 'Maggi', '420g', 'Packet', TRUE, 4.9, 15000, '9 Months', ARRAY['Instant', 'Veg']),
('Kissan Ketchup (1kg)', 'KISSAN-1K', 'Kitchen', 135, 125, 40, 'Fresh tomato ketchup - 1kg', 'Kissan', '1kg', 'Pouch', TRUE, 4.7, 3200, '12 Months', ARRAY['Pantry', 'Veg']),
('Pasta Penne (500g)', 'PASTA-500', 'Kitchen', 110, 95, 30, '100% durum wheat semolina', 'Bambino', '500g', 'Packet', FALSE, 4.4, 800, '12 Months', ARRAY['Pantry', 'Veg']),
('Rice Basmati (1kg)', 'RICE-1K', 'Kitchen', 180, 160, 20, 'Extra long grain premium', 'India Gate', '1kg', 'Packet', FALSE, 4.8, 1400, '24 Months', ARRAY['Pantry', 'Veg']),
('TATA Salt (1kg)', 'TATA-SALT', 'Kitchen', 25, 23, 200, 'Desh ka namak - Iodized', 'TATA', '1kg', 'Packet', TRUE, 4.9, 25000, 'Infinite', ARRAY['Pantry', 'Veg']),
('Sugar Premium (1kg)', 'SUGAR-1K', 'Kitchen', 50, 48, 100, 'Sulfur free refined sugar', 'Generic', '1kg', 'Packet', TRUE, 4.5, 5200, '36 Months', ARRAY['Pantry', 'Veg']),
('Tea Coffee Mug (350ml)', 'MUG-350', 'Home Needs', 150, 130, 25, 'Ceramic minimalist hostel mug', 'Generic', '350ml', 'Box', FALSE, 4.4, 400, 'Durable', ARRAY['Hostel', 'Lifestyle']),
('Electric Kettle (1.5L)', 'KETTLE-1.5', 'Home Needs', 1200, 999, 8, 'Stainless steel rapid boil', 'Pigeon', '1.5L', 'Box', TRUE, 4.7, 4200, 'Durable', ARRAY['Tech', 'Hostel']),
('Corn Flakes (250g)', 'KELL-CORN', 'Dairy', 110, 100, 30, 'The Original breakfast cereal', 'Kellogg''s', '250g', 'Box', TRUE, 4.6, 1200, '12 Months', ARRAY['Breakfast', 'Veg']),
('Pringles (107g)', 'PRIN-SCR', 'Snacks', 105, 95, 40, 'Sour Cream & Onion classic', 'Pringles', '107g', 'Tube', TRUE, 4.8, 8500, '12 Months', ARRAY['Premium', 'Veg']),

-- Hostel Room Comfort & Others (25 items)
('Microfiber Pillow', 'PILLOW-MF', 'Home Needs', 350, 300, 15, 'Cloud comfort support - Standard', 'SleepyCat', '1 unit', 'Bag', TRUE, 4.7, 1200, 'Durable', ARRAY['Hostel', 'Comfort']),
('Cotton Bedsheet (S)', 'SHEET-S', 'Home Needs', 650, 599, 10, 'Single bed pure cotton pattern', 'Generic', 'Single', 'Bag', FALSE, 4.5, 400, 'Durable', ARRAY['Hostel', 'Comfort']),
('Towel Large (Cotton)', 'TOWEL-L', 'Home Needs', 450, 399, 20, 'High absorbance soft cotton', 'Generic', 'Large', 'Bag', FALSE, 4.4, 600, 'Durable', ARRAY['Hostel', 'Essential']),
('Door Mat (Anti-Skid)', 'MAT-DOOR', 'Home Needs', 150, 120, 25, 'Super absorbent micro-fiber', 'Generic', 'Small', 'Bag', FALSE, 4.2, 300, 'Durable', ARRAY['Hostel', 'Essential']),
('Wall Clock (Minimal)', 'CLOCK-MIN', 'Home Needs', 450, 399, 10, 'Silent quartz movement black', 'Generic', '10 inch', 'Box', FALSE, 4.5, 200, 'Durable', ARRAY['Hostel', 'Decor']),
('Plastic Stool (Med)', 'STOOL-MED', 'Home Needs', 250, 220, 12, 'Space saver robust plastic', 'Generic', 'Medium', 'Unit', FALSE, 4.3, 150, 'Durable', ARRAY['Hostel', 'Essential']),
('Floor Mop (Magic)', 'MOP-MAG', 'Home Needs', 850, 750, 8, 'Spin dry 360 cleaning system', 'Generic', 'Set', 'Box', TRUE, 4.6, 900, 'Durable', ARRAY['Hostel', 'Essential']),
('Mirror (Wall/Small)', 'MIRROR-W', 'Home Needs', 350, 300, 5, 'Standard clarity wall mirror', 'Generic', 'Small', 'Box', FALSE, 4.1, 120, 'Durable', ARRAY['Hostel', 'Essential']),
('Umbrella (Foldable)', 'UMB-FOLD', 'Home Needs', 350, 300, 15, 'Automatic open windproof black', 'Generic', 'Standard', 'Bag', TRUE, 4.5, 800, 'Durable', ARRAY['Hostel', 'Essential']),
('Raincoat (Trans)', 'RAIN-T', 'Home Needs', 150, 120, 30, 'Disposable urgent use clear', 'Generic', 'XL', 'Bag', FALSE, 3.8, 150, 'Temporary', ARRAY['Hostel', 'Essential'])
ON CONFLICT (sku_qr) DO NOTHING;

-- MOCK USERS & ROLES SEED
-- NOTE: Hardcoded mock profiles are disabled by default because they require 
-- corresponding entries in Supabase's internal auth.users table.
-- Please sign up via the mobile app to automatically create your profile.

/*
INSERT INTO public.profiles (id, full_name, role) VALUES 
('00000000-0000-0000-0000-000000000001', 'John Doe (Student)', 'hostel_student'),
('00000000-0000-0000-0000-000000000002', 'Manager Sam', 'hostel_manager'),
('00000000-0000-0000-0000-000000000003', 'Admin Alex', 'shop_admin'),
('00000000-0000-0000-0000-000000000004', 'Staff Sarah', 'staff')
ON CONFLICT (id) DO NOTHING;
*/
