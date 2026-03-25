-- 11. FEE STRUCTURE TABLE
CREATE TABLE IF NOT EXISTS fee_structure (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_name TEXT NOT NULL,
    category TEXT NOT NULL, -- 'Hostel', 'Van', 'Mess', 'Power'
    price DECIMAL NOT NULL DEFAULT 0.0,
    unit TEXT DEFAULT 'Month',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed with basic plans if empty
INSERT INTO fee_structure (service_name, category, price, description)
SELECT 'Single Room', 'Hostel', 8500.0, 'Premium single occupancy'
WHERE NOT EXISTS (SELECT 1 FROM fee_structure WHERE service_name = 'Single Room');

INSERT INTO fee_structure (service_name, category, price, description)
SELECT 'Double Sharing', 'Hostel', 6500.0, 'Standard twin sharing'
WHERE NOT EXISTS (SELECT 1 FROM fee_structure WHERE service_name = 'Double Sharing');

INSERT INTO fee_structure (service_name, category, price, description)
SELECT 'Power', 'Power', 12.0, 'Rate per KWh'
WHERE NOT EXISTS (SELECT 1 FROM fee_structure WHERE service_name = 'Power');
