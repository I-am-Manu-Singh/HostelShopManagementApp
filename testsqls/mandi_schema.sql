-- ====================================================================
-- MANDI MART & REUSED SHOP SCHEMA CONSOLIDATION
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ====================================================================

-- ────────────────────────────────────────────────────────────────────
-- 1. CONSOLIDATE PRODUCT DATA AND EXTEND SHOP_ITEMS TABLE
--    Add category-specific columns, dates, and settings to the existing table
-- ────────────────────────────────────────────────────────────────────
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'pcs';
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS rate_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS is_mandi BOOLEAN DEFAULT false;

-- Add check constraint for category to support both existing shop and new mandi categories
-- Existing: Snacks, Beverages, Stationery, Laundry, Toiletries, etc.
-- New: Sabji, Fruit, Kiryana
ALTER TABLE shop_items DROP CONSTRAINT IF EXISTS shop_items_category_check;

-- Seed initial Mandi Products directly into shop_items table so we reuse the model!
INSERT INTO shop_items (name, category, unit, description, price, stock_quantity, is_available, is_mandi, rate_date) VALUES
  ('Tomato', 'Sabji', 'kg', 'Fresh ripe farm tomatoes', 30.0, 1000, true, true, CURRENT_DATE),
  ('Onion', 'Sabji', 'kg', 'Premium quality red onions', 25.0, 2000, true, true, CURRENT_DATE),
  ('Potato', 'Sabji', 'kg', 'Farm fresh organic potatoes', 20.0, 1500, true, true, CURRENT_DATE),
  ('Spinach', 'Sabji', 'bundle', 'Green leafy palak bundles', 15.0, 500, true, true, CURRENT_DATE),
  ('Apple', 'Fruit', 'kg', 'Sweet juicykeep delivery consolidated for mandi and  Himachal apples', 120.0, 300, true, true, CURRENT_DATE),
  ('Banana', 'Fruit', 'dozen', 'Fresh yellow banana ripe dozen', 40.0, 200, true, true, CURRENT_DATE),
  ('Mango', 'Fruit', 'kg', 'Alphonso delicious mangoes', 80.0, 400, true, true, CURRENT_DATE),
  ('Basmati Rice', 'Kiryana', 'kg', 'Premium long grain aged basmati rice', 85.0, 1000, true, true, CURRENT_DATE),
  ('Wheat Flour', 'Kiryana', 'kg', 'Chakki fresh whole wheat atta', 38.0, 2000, true, true, CURRENT_DATE),
  ('Sugar', 'Kiryana', 'kg', 'Refined pure white sugar', 42.0, 1000, true, true, CURRENT_DATE)
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────────────────────────────────
-- 2. MANDI HISTORICAL/DATE-WISE DYNAMIC RATES TABLE
--    Keeps record of rates since vegetable/fruit prices vary daily
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mandi_rates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES shop_items(id) ON DELETE CASCADE,
  rate_date DATE NOT NULL DEFAULT CURRENT_DATE,
  price_per_unit DECIMAL(10,2) NOT NULL,
  min_qty DECIMAL(10,2) DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(product_id, rate_date)
);

-- Seed initial rates for the added items
INSERT INTO mandi_rates (product_id, rate_date, price_per_unit)
SELECT id, CURRENT_DATE, price
FROM shop_items
WHERE is_mandi = true
ON CONFLICT (product_id, rate_date) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────
-- 3. EXTEND PROFILE COLUMNS FOR MANDI USERS
--    Uses one single profiles table for Hostel/Shop + Mandi
-- ────────────────────────────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS delivery_location TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'domestic' CHECK (user_type IN ('domestic', 'commercial', 'not_set'));

-- Update check/role definitions logic:
-- Role values: 'hostel_student', 'mess_student', 'store_customer', 'staff', 'hostel_manager', 'owner', 'admin', 'farmer_seller', 'delivery_partner'

-- ────────────────────────────────────────────────────────────────────
-- 4. CONSOLIDATE ORDER TABLE WITH BOOKING DETAILS
--    Extend shop_orders with advance, cutting date, date-varied rates, etc.
-- ────────────────────────────────────────────────────────────────────
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS is_booking BOOLEAN DEFAULT false;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS booking_date DATE;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS advance_paid DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'domestic';
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS delivery_location TEXT;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS delivery_partner_id UUID REFERENCES auth.users(id);

-- ────────────────────────────────────────────────────────────────────
-- 5. MANDI PURCHASE ORDERS (Procurement by Admin from Farmer/Seller)
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mandi_purchase_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  seller_id UUID REFERENCES auth.users(id),
  seller_name TEXT,
  seller_phone TEXT,
  product_id UUID REFERENCES shop_items(id),
  product_name TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'kg',
  rate_per_unit DECIMAL(10,2) NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  photo_url TEXT,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'received', 'cancelled')),
  notes TEXT,
  order_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────────────
-- 6. ENABLE ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────────────
ALTER TABLE mandi_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE mandi_purchase_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mandi_rates_read_policy" ON mandi_rates FOR SELECT TO authenticated USING (true);
CREATE POLICY "mandi_po_read_policy" ON mandi_purchase_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "mandi_po_insert_policy" ON mandi_purchase_orders FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());
