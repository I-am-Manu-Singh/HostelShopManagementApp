-- ============================================================================
-- POS MODULE SCHEMA ENHANCEMENT & CONSTRAINTS FIX
-- Multi-Tenant / Branch POS Support, Item Tax Slabs, Hardware Registers & Shifts
-- ============================================================================

-- 1. Ensure shop_items has POS, HSN, Tax Rate, Cost Price, and Barcode columns
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS hsn_code TEXT;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS tax_rate NUMERIC DEFAULT 0.0;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS cost_price NUMERIC;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN DEFAULT true;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS min_stock_alert INT DEFAULT 5;

-- Create index on barcode and sku_qr for rapid keyboard wedge & USB/BT scanner lookup
CREATE INDEX IF NOT EXISTS idx_shop_items_barcode ON shop_items(barcode);
CREATE INDEX IF NOT EXISTS idx_shop_items_sku_qr ON shop_items(sku_qr);

-- 2. Ensure shop_orders supports POS terminal fields
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS invoice_number TEXT;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'cash'; -- 'cash', 'upi', 'khata', 'card'
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS subtotal NUMERIC;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS discount NUMERIC DEFAULT 0.0;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS cgst NUMERIC DEFAULT 0.0;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS sgst NUMERIC DEFAULT 0.0;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS tendered_amount NUMERIC;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS change_amount NUMERIC;
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS cashier_id UUID REFERENCES profiles(id);
ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS is_pos_order BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_shop_orders_invoice ON shop_orders(invoice_number);
CREATE INDEX IF NOT EXISTS idx_shop_orders_created_at ON shop_orders(created_at);

-- 3. Daily POS Cash Drawer / Shift Register Sessions (Z-Report Day-End Reconciliation)
CREATE TABLE IF NOT EXISTS pos_shift_registers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cashier_id UUID REFERENCES profiles(id),
    opening_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    closing_time TIMESTAMP WITH TIME ZONE,
    opening_cash NUMERIC NOT NULL DEFAULT 0.0,
    expected_closing_cash NUMERIC DEFAULT 0.0,
    actual_closing_cash NUMERIC,
    cash_difference NUMERIC, -- Discrepancy (actual - expected)
    total_sales NUMERIC DEFAULT 0.0,
    total_cash_sales NUMERIC DEFAULT 0.0,
    total_upi_sales NUMERIC DEFAULT 0.0,
    total_card_sales NUMERIC DEFAULT 0.0,
    total_khata_sales NUMERIC DEFAULT 0.0,
    orders_count INT DEFAULT 0,
    notes TEXT,
    status TEXT DEFAULT 'Open', -- 'Open', 'Closed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE pos_shift_registers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins and Cashiers can manage shift registers" ON pos_shift_registers;
CREATE POLICY "Admins and Cashiers can manage shift registers" ON pos_shift_registers FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'employee', 'staff'))
);

-- 4. Shop Hardware and Merchant Configuration Table (Sync across terminals)
CREATE TABLE IF NOT EXISTS pos_hardware_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_name TEXT NOT NULL DEFAULT 'Main Campus Counter',
    merchant_upi_vpa TEXT NOT NULL DEFAULT 'campusshop@upi',
    merchant_name TEXT NOT NULL DEFAULT 'Hostel SuperMart',
    paper_width INT DEFAULT 58, -- 58 or 80
    gstin TEXT,
    store_address TEXT,
    store_phone TEXT,
    footer_note TEXT DEFAULT 'Thank you for shopping with us! Visit again.',
    auto_print BOOLEAN DEFAULT true,
    cash_drawer_pulse BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE pos_hardware_configs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone authenticated can view POS config" ON pos_hardware_configs;
CREATE POLICY "Anyone authenticated can view POS config" ON pos_hardware_configs FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admins can update POS config" ON pos_hardware_configs;
CREATE POLICY "Admins can update POS config" ON pos_hardware_configs FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- 5. Safe Stock Decrement / Atomic Inward Stored Procedures (Prevents race conditions)
CREATE OR REPLACE FUNCTION pos_decrement_stock(p_item_id UUID, p_quantity INT)
RETURNS INT AS $$
DECLARE
    v_new_stock INT;
BEGIN
    UPDATE shop_items
    SET stock_quantity = GREATEST(0, stock_quantity - p_quantity)
    WHERE id = p_item_id
    RETURNING stock_quantity INTO v_new_stock;

    RETURN v_new_stock;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Enable Realtime Sync across POS Terminals, Customer App, and Admin
-- Ensures Supabase websocket streams immediately broadcast changes to shop_items and shop_orders
ALTER TABLE public.shop_items REPLICA IDENTITY FULL;
ALTER TABLE public.shop_orders REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'shop_items'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_items;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'shop_orders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_orders;
    END IF;
END $$;

-- 7. Ensure Storage Buckets for Product Photos, Documents, Receipts, and Avatars Exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('mandi-assets', 'mandi-assets', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
    ('documents', 'documents', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('receipts', 'receipts', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('profiles', 'profiles', true, 20971520, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- Ensure public storage read/write policies for buckets
DROP POLICY IF EXISTS "Public access to mandi-assets" ON storage.objects;
CREATE POLICY "Public access to mandi-assets" ON storage.objects FOR SELECT USING (bucket_id = 'mandi-assets');

DROP POLICY IF EXISTS "Authenticated users can upload to mandi-assets" ON storage.objects;
CREATE POLICY "Authenticated users can upload to mandi-assets" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'mandi-assets' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Authenticated users can update mandi-assets" ON storage.objects;
CREATE POLICY "Authenticated users can update mandi-assets" ON storage.objects FOR UPDATE USING (
    bucket_id = 'mandi-assets' AND auth.role() = 'authenticated'
);

-- Policies for documents bucket (Rent/Mess/UPI payment proofs & KYC docs)
DROP POLICY IF EXISTS "Public access to documents" ON storage.objects;
CREATE POLICY "Public access to documents" ON storage.objects FOR SELECT USING (bucket_id = 'documents');

DROP POLICY IF EXISTS "Authenticated users can upload to documents" ON storage.objects;
CREATE POLICY "Authenticated users can upload to documents" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'documents' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Authenticated users can update documents" ON storage.objects;
CREATE POLICY "Authenticated users can update documents" ON storage.objects FOR UPDATE USING (
    bucket_id = 'documents' AND auth.role() = 'authenticated'
);

-- Policies for receipts bucket
DROP POLICY IF EXISTS "Public access to receipts" ON storage.objects;
CREATE POLICY "Public access to receipts" ON storage.objects FOR SELECT USING (bucket_id = 'receipts');

DROP POLICY IF EXISTS "Authenticated users can upload to receipts" ON storage.objects;
CREATE POLICY "Authenticated users can upload to receipts" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'receipts' AND auth.role() = 'authenticated'
);

-- Policies for profiles bucket (User avatars & profile photos)
DROP POLICY IF EXISTS "Public access to profiles bucket" ON storage.objects;
CREATE POLICY "Public access to profiles bucket" ON storage.objects FOR SELECT USING (bucket_id = 'profiles');

DROP POLICY IF EXISTS "Authenticated users can upload to profiles" ON storage.objects;
CREATE POLICY "Authenticated users can upload to profiles" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'profiles' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Authenticated users can update profiles" ON storage.objects;
CREATE POLICY "Authenticated users can update profiles" ON storage.objects FOR UPDATE USING (
    bucket_id = 'profiles' AND auth.role() = 'authenticated'
);

-- 8. Ensure shop_orders RLS allows POS cashier inserts and admin/cashier selects
ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins and cashiers can view all shop orders" ON public.shop_orders;
CREATE POLICY "Admins and cashiers can view all shop orders" ON public.shop_orders FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'employee', 'staff'))
    OR auth.uid() = user_id
);

DROP POLICY IF EXISTS "Authenticated users and cashiers can insert shop orders" ON public.shop_orders;
CREATE POLICY "Authenticated users and cashiers can insert shop orders" ON public.shop_orders FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
);

DROP POLICY IF EXISTS "Admins and cashiers can update shop orders" ON public.shop_orders;
CREATE POLICY "Admins and cashiers can update shop orders" ON public.shop_orders FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'employee', 'staff'))
    OR auth.uid() = user_id
);

-- 9. Ensure payment_approvals table and RLS policies exist
CREATE TABLE IF NOT EXISTS public.payment_approvals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id),
    payment_type TEXT NOT NULL, -- 'Rent', 'Mess', 'Shop', 'Wallet'
    amount NUMERIC NOT NULL,
    screenshot_url TEXT,
    order_id UUID,
    status TEXT NOT NULL DEFAULT 'Pending', -- 'Pending', 'Approved', 'Rejected'
    admin_notes TEXT,
    reviewed_by UUID REFERENCES public.profiles(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- If payment_approvals already existed prior without some columns:
ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS admin_notes TEXT;
ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS screenshot_url TEXT;
ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id);
ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'Rent';
ALTER TABLE public.payment_approvals ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Pending';

-- Refresh schema cache for PostgREST
NOTIFY pgrst, 'reload schema';

ALTER TABLE public.payment_approvals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own payment approvals" ON public.payment_approvals;
CREATE POLICY "Users can view their own payment approvals" ON public.payment_approvals FOR SELECT USING (
    auth.uid() = user_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'employee', 'staff', 'hostel_manager'))
);

DROP POLICY IF EXISTS "Users can insert their own payment approvals" ON public.payment_approvals;
CREATE POLICY "Users can insert their own payment approvals" ON public.payment_approvals FOR INSERT WITH CHECK (
    auth.uid() = user_id
);

-- 10. Ensure blogs table has gallery column
ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS gallery TEXT[];
ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS read_time TEXT;
ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS image_url TEXT;

NOTIFY pgrst, 'reload schema';




