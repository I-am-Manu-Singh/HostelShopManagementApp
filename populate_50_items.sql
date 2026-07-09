-- Truncate existing shop items (will cascade if foreign keys exist)
DELETE FROM shop_items;

-- Insert 50 Logically Useful Shop Items with all fields synchronized to Edit Product Screen attributes
-- UUIDs are dynamically generated using extensions to fit standard UUID columns
-- PostgreSQL Array syntax (e.g. ARRAY['potato', 'salted']) is used for the tags column (text[])
-- Columns: id, name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, shelf_life, tags, ingredients, how_to_use, image_url, rating, total_reviews, nutritional_info, is_mandi, unit
INSERT INTO shop_items (
  id, name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, shelf_life, tags, ingredients, how_to_use, image_url, rating, total_reviews, nutritional_info, is_mandi, unit
) VALUES
-- Snacks & Munchies (10 items)
(
  'a0000000-0000-0000-0000-000000000001', 'Lays Classic Salted', 'SKU-SNACK-LAYS-001', 'Snacks', 20.00, 18.00, 150, 
  'Crispy classic salted potato chips, perfect for study breaks or late-night cravings.', 'Lays', '52g', 'Packet', true, '4 Months', 
  ARRAY['potato', 'salted', 'crispy', 'snack'], 'Fresh Potatoes, Vegetable Oil, Iodized Salt', 'Ready to consume directly from the pack.', 
  'https://images.unsplash.com/photo-1566478989037-eec170784d20?w=500', 4.5, 320, 
  '{"Energy": "160 kcal", "Total Fat": "10g", "Sodium": "170mg", "Total Carbohydrates": "15g", "Protein": "2g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000002', 'Kurkure Masala Munch', 'SKU-SNACK-KURK-002', 'Snacks', 20.00, 19.00, 120, 
  'Spicy crunchy puffcorn snack, classic Indian flavor with a great crunch.', 'Kurkure', '82g', 'Packet', false, '4 Months', 
  ARRAY['spicy', 'crunchy', 'corn', 'namkeen'], 'Rice Meal, Corn Meal, Edible Vegetable Oil, Spices & Condiments', 'Open packet and enjoy.', 
  'https://images.unsplash.com/photo-1600952841323-b757bbeeff01?w=500', 4.3, 210, 
  '{"Energy": "558 kcal", "Total Fat": "34g", "Sodium": "843mg", "Total Carbohydrates": "56g", "Protein": "6g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000003', 'Oreo Chocolate Biscuits', 'SKU-SNACK-OREO-003', 'Snacks', 35.00, 32.00, 80, 
  'Rich chocolate sandwich cookies with sweet vanilla cream filling inside.', 'Oreo', '120g', 'Packet', true, '6 Months', 
  ARRAY['cookies', 'chocolate', 'vanilla', 'sweet'], 'Wheat Flour, Sugar, Palm Oil, Cocoa Powder, Fructose Syrup', 'Twist, Lick and Dunk in milk.', 
  'https://images.unsplash.com/photo-1558961309-dbdf71799f14?w=500', 4.7, 450, 
  '{"Energy": "480 kcal", "Total Fat": "20g", "Sugars": "38g", "Total Carbohydrates": "70g", "Protein": "5g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000004', 'Hide & Seek Chocolate Chips', 'SKU-SNACK-HIDE-004', 'Snacks', 30.00, 28.00, 90, 
  'Premium real chocolate chip cookies with a crunchy texture in every bite.', 'Parle', '100g', 'Packet', false, '6 Months', 
  ARRAY['cookies', 'chocolate-chip', 'sweet', 'parle'], 'Wheat Flour, Chocolate Chips, Sugar, Vegetable Oil', 'Serve with hot tea or milk.', 
  'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=500', 4.6, 180, 
  '{"Energy": "495 kcal", "Total Fat": "21g", "Sugars": "32g", "Total Carbohydrates": "70g", "Protein": "6g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000005', 'Maggi 2-Minute Noodles', 'SKU-NOOD-MAGG-005', 'Noodles', 14.00, 13.50, 300, 
  'Instant masala noodles, the ultimate hostel survival food.', 'Nestle', '70g', 'Packet', true, '8 Months', 
  ARRAY['noodles', 'instant', 'spicy', 'maggi'], 'Wheat Flour, Palm Oil, Salt, Masala Tastemaker Spice Mix', 'Boil in water with tastemaker for 2 minutes.', 
  'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=500', 4.8, 1200, 
  '{"Energy": "389 kcal", "Total Fat": "13.5g", "Sodium": "1000mg", "Total Carbohydrates": "58g", "Protein": "8g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000006', 'Yippee Magic Masala', 'SKU-NOOD-YIPP-006', 'Noodles', 15.00, 14.00, 180, 
  'Non-sticky round instant noodles with a blend of natural spices and veggies.', 'ITC', '70g', 'Packet', false, '8 Months', 
  ARRAY['noodles', 'instant', 'itc', 'masala'], 'Wheat Flour, Refined Palm Oil, Vegetable Dehydrates, Spices', 'Cook in boiling water for 3 minutes.', 
  'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=500', 4.4, 340, 
  '{"Energy": "372 kcal", "Total Fat": "14g", "Sodium": "950mg", "Total Carbohydrates": "54g", "Protein": "7.5g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000007', 'Haldirams Bhujia Sev', 'SKU-SNACK-HALD-007', 'Snacks', 40.00, 38.00, 110, 
  'Crispy gram flour spicy sticks, ideal evening tea companion.', 'Haldiram', '150g', 'Packet', false, '6 Months', 
  ARRAY['bhujia', 'sev', 'namkeen', 'spicy'], 'Tepary Beans Flour, Gram Flour, Vegetable Oil, Spices & Condiments', 'Ready to eat as a crispy snack.', 
  'https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=500', 4.5, 290, 
  '{"Energy": "578 kcal", "Total Fat": "42g", "Sodium": "780mg", "Total Carbohydrates": "38g", "Protein": "12g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000008', 'Act II Salted Popcorn', 'SKU-SNACK-ACT-008', 'Snacks', 30.00, 27.00, 130, 
  'Instant home-style salted yellow butter popcorn ready in minutes.', 'Act II', '90g', 'Packet', false, '12 Months', 
  ARRAY['popcorn', 'salted', 'butter', 'instant'], 'Popping Corn, Vegetable Oil, Iodized Salt, Beta Carotene Color', 'Microwave or heat in a covered cooker pan.', 
  'https://images.unsplash.com/photo-1578849278619-e73505e9610f?w=500', 4.2, 190, 
  '{"Energy": "450 kcal", "Total Fat": "22g", "Sodium": "650mg", "Total Carbohydrates": "54g", "Protein": "9g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000009', 'Dairy Milk Silk Classic', 'SKU-CHOC-CADB-009', 'Chocolates', 80.00, 75.00, 60, 
  'Rich, smooth and creamy classic milk chocolate bar.', 'Cadbury', '60g', 'Bar', true, '12 Months', 
  ARRAY['chocolate', 'sweet', 'cadbury', 'silk'], 'Sugar, Milk Solids, Cocoa Butter, Cocoa Solids, Emulsifiers', 'Unwrap and bite directly.', 
  'https://images.unsplash.com/photo-1549007994-cb92ca71450a?w=500', 4.8, 620, 
  '{"Energy": "534 kcal", "Total Fat": "30g", "Sugars": "55g", "Total Carbohydrates": "59g", "Protein": "7g"}', false, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000010', 'KitKat 4-Finger Bar', 'SKU-CHOC-KITK-010', 'Chocolates', 25.00, 23.00, 100, 
  'Crispy wafer fingers covered with smooth milk chocolate.', 'Nestle', '38g', 'Bar', false, '9 Months', 
  ARRAY['wafer', 'chocolate', 'nestle', 'kitkat'], 'Sugar, Wheat Flour, Cocoa Butter, Milk Powder, Cocoa Solids', 'Break a finger and enjoy.', 
  'https://images.unsplash.com/photo-1549007994-cb92ca71450a?w=500', 4.6, 310, 
  '{"Energy": "198 kcal", "Total Fat": "9g", "Sugars": "18g", "Total Carbohydrates": "23g", "Protein": "2g"}', false, 'piece'
),

-- Beverages (10 items)
(
  'a0000000-0000-0000-0000-000000000011', 'Coca-Cola Soft Can', 'SKU-BEV-COKE-011', 'Beverages', 40.00, 38.00, 200, 
  'Chilled carbonated soft drink to refresh your mind and active state.', 'Coca Cola', '330ml', 'Can', true, '6 Months', 
  ARRAY['soda', 'coke', 'beverage', 'chilled'], 'Carbonated Water, Sugar, Acidity Regulator, Caffeine', 'Best served chilled.', 
  'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500', 4.4, 580, 
  '{"Energy": "140 kcal", "Sugars": "35g", "Sodium": "45mg", "Total Carbohydrates": "35g", "Protein": "0g"}', false, 'can'
),
(
  'a0000000-0000-0000-0000-000000000012', 'Red Bull Energy Can', 'SKU-BEV-REDB-012', 'Beverages', 125.00, 119.00, 90, 
  'Vitalizes body and mind during exam preparation and coding sprints.', 'Red Bull', '250ml', 'Can', true, '12 Months', 
  ARRAY['energy', 'caffeine', 'taurine', 'redbull'], 'Water, Sucrose, Glucose, Citric Acid, Taurine, Caffeine, Vitamins', 'Drink ice cold before workout or study.', 
  'https://images.unsplash.com/photo-1622543953490-0b70039a4b19?w=500', 4.6, 420, 
  '{"Energy": "112 kcal", "Sugars": "26g", "Sodium": "200mg", "Total Carbohydrates": "28g", "Protein": "0.3g"}', false, 'can'
),
(
  'a0000000-0000-0000-0000-000000000013', 'Nescafe Instant Coffee', 'SKU-BEV-NESC-013', 'Beverages', 150.00, 145.00, 45, 
  'Rich and aromatic coffee powder jar made from chosen Robusta beans.', 'Nescafe', '50g', 'Jar', false, '18 Months', 
  ARRAY['coffee', 'caffeine', 'nescafe', 'beverage'], '100% Pure Coffee Beans Powder', 'Add a teaspoon to hot milk or water with sugar.', 
  'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=500', 4.7, 280, 
  '{"Energy": "5 kcal", "Sodium": "2mg", "Total Carbohydrates": "1g", "Protein": "0.5g"}', false, 'jar'
),
(
  'a0000000-0000-0000-0000-000000000014', 'Taj Mahal Tea Bags', 'SKU-BEV-TAJM-014', 'Beverages', 110.00, 105.00, 50, 
  'Premium black tea blend bags for quick and rich brewing experience.', 'Brooke Bond', '25g', 'Box', false, '12 Months', 
  ARRAY['tea', 'chai', 'black-tea', 'beverage'], 'Selected Premium Black CTC Tea Leaves', 'Dip in hot water or milk for 2 minutes.', 
  'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500', 4.5, 140, 
  '{"Energy": "0 kcal", "Sodium": "0mg", "Total Carbohydrates": "0g", "Protein": "0g"}', false, 'box'
),
(
  'a0000000-0000-0000-0000-000000000015', 'Real Mixed Fruit Juice', 'SKU-BEV-REAL-015', 'Beverages', 120.00, 110.00, 75, 
  'No added preservatives mixed fruit nectar loaded with rich nutrients.', 'Real Juice', '1L', 'Carton', false, '6 Months', 
  ARRAY['juice', 'fruit', 'beverage', 'healthy'], 'Water, Mixed Fruit Concentrates (Apple, Orange, Guava, Pineapple)', 'Shake well and serve chilled.', 
  'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=500', 4.3, 190, 
  '{"Energy": "60 kcal", "Sugars": "14g", "Vitamin C": "40mg", "Total Carbohydrates": "15g", "Protein": "0.4g"}', false, 'carton'
),
(
  'a0000000-0000-0000-0000-000000000016', 'Paper Boat Aam Panna', 'SKU-BEV-PAPB-016', 'Beverages', 35.00, 32.00, 100, 
  'Tangy green mango refreshing native Indian summer drink.', 'Paper Boat', '250ml', 'Packet', false, '6 Months', 
  ARRAY['mango', 'aam-panna', 'beverage', 'native'], 'Water, Raw Mango Pulp, Sugar, Spices, Black Salt', 'Ready to consume drink.', 
  'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=500', 4.4, 150, 
  '{"Energy": "120 kcal", "Sugars": "28g", "Total Carbohydrates": "30g", "Protein": "0.1g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000017', 'Amul Kool Cafe', 'SKU-BEV-AMUL-017', 'Beverages', 30.00, 28.00, 120, 
  'Sterilized dynamic coffee milk beverage in a handy bottle.', 'Amul', '200ml', 'Bottle', false, '6 Months', 
  ARRAY['milk-shake', 'coffee', 'amul', 'beverage'], 'Standardised Milk, Sugar, Coffee Powder', 'Serve chilled. Shake before opening.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.5, 270, 
  '{"Energy": "180 kcal", "Total Fat": "3.5g", "Sugars": "16g", "Total Carbohydrates": "20g", "Protein": "4.5g"}', false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000018', 'Sprite Lemon Drink Can', 'SKU-BEV-SPRI-018', 'Beverages', 40.00, 38.00, 150, 
  'Crispy lemon-lime clear carbonated soft drink for direct refreshment.', 'Sprite', '330ml', 'Can', false, '6 Months', 
  ARRAY['soda', 'sprite', 'lemon', 'chilled'], 'Carbonated Water, Sugar, Citric Acid, Acidity Regulators', 'Serve cold.', 
  'https://images.unsplash.com/photo-1625772290748-160b240e90ac?w=500', 4.3, 310, 
  '{"Energy": "130 kcal", "Sugars": "32g", "Total Carbohydrates": "32g", "Protein": "0g"}', false, 'can'
),
(
  'a0000000-0000-0000-0000-000000000019', 'Bisleri Mineral Water 1L', 'SKU-BEV-BISL-019', 'Beverages', 20.00, 19.50, 500, 
  'Purified drinking mineral water bottle with added minerals.', 'Bisleri', '1L', 'Bottle', true, '12 Months', 
  ARRAY['water', 'mineral-water', 'hydrate', 'pure'], 'Ozonated Water, Minerals (Magnesium Sulphate, Potassium Bicarbonate)', 'Store in a clean and dry place.', 
  'https://images.unsplash.com/photo-1608885898957-a599fb1b467b?w=500', 4.9, 1500, 
  '{"Energy": "0 kcal", "Sodium": "0mg", "Calcium": "1.2mg", "Magnesium": "0.8mg"}', false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000020', 'Gatorade Blue Bolt Bottle', 'SKU-BEV-GATO-020', 'Beverages', 50.00, 47.00, 60, 
  'Isotonic sports drink for quick recovery and rehydration.', 'Gatorade', '500ml', 'Bottle', false, '9 Months', 
  ARRAY['sports-drink', 'electrolyte', 'gatorade', 'beverage'], 'Water, Sugar, Dextrose, Mineral Salts, Flavorings', 'Consume during or after sports activities.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.5, 120, 
  '{"Energy": "120 kcal", "Sodium": "240mg", "Potassium": "60mg", "Total Carbohydrates": "30g", "Protein": "0g"}', false, 'bottle'
),

-- Personal Care & Hygiene (10 items)
(
  'a0000000-0000-0000-0000-000000000021', 'Dettol Handwash Refill', 'SKU-HYG-DETT-021', 'Hygiene', 99.00, 95.00, 65, 
  'Antibacterial protection dynamic liquid handwash refill pack.', 'Dettol', '175ml', 'Packet', false, '24 Months', 
  ARRAY['handwash', 'soap', 'dettol', 'germ-protection'], 'Water, Sodium Laureth Sulfate, Glycerin, Salicylic Acid', 'Pour into bottle, use with water to wash hands.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.6, 280, 
  null, false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000022', 'Colgate MaxFresh Gel', 'SKU-HYG-COLG-022', 'Hygiene', 85.00, 79.00, 80, 
  'Spicy fresh mint toothpaste gel with cooling crystals.', 'Colgate', '150g', 'Tube', false, '24 Months', 
  ARRAY['toothpaste', 'mint', 'oral', 'colgate'], 'Sorbitol, Silica, Sodium Lauryl Sulfate, Menthol Crystals', 'Brush twice daily under adult supervision.', 
  'https://images.unsplash.com/photo-1559599189-fe84dea4eb79?w=500', 4.5, 390, 
  null, false, 'tube'
),
(
  'a0000000-0000-0000-0000-000000000023', 'Head & Shoulders Menthol', 'SKU-PC-HEAD-023', 'Personal Care', 140.00, 129.00, 45, 
  'Anti-dandruff refreshing scalp formula cool menthol shampoo.', 'P&G', '180ml', 'Bottle', false, '36 Months', 
  ARRAY['shampoo', 'hair', 'menthol', 'anti-dandruff'], 'Water, Sodium Lauryl Sulfate, Menthol, Zinc Pyrithione', 'Apply to wet hair, lather and rinse thoroughly.', 
  'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=500', 4.6, 220, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000024', 'Nivea Men Oil Control', 'SKU-PC-NIVE-024', 'Personal Care', 120.00, 115.00, 55, 
  'Effective oil control men face wash cream for clean skin.', 'Nivea', '100g', 'Tube', false, '30 Months', 
  ARRAY['facewash', 'men', 'nivea', 'oil-control'], 'Water, Myristic Acid, Menthol, Carnitine, Licorice Extract', 'Massage over wet face and rinse off with water.', 
  'https://images.unsplash.com/photo-1556229174-5e42a09e45af?w=500', 4.4, 175, 
  null, false, 'tube'
),
(
  'a0000000-0000-0000-0000-000000000025', 'Fiama Peach Soap Gel Bar', 'SKU-HYG-FIAM-025', 'Hygiene', 45.00, 42.00, 120, 
  'Exotic peach and avocado moisture bathing soap bar.', 'ITC', '125g', 'Bar', false, '36 Months', 
  ARRAY['soap', 'bathing-bar', 'fiama', 'peach'], 'Sodium Laureth Sulfate, Peach Extract, Avocado Butter', 'Rub gently on wet skin to create rich lather.', 
  'https://images.unsplash.com/photo-1607006342411-9a336f7cf97f?w=500', 4.5, 140, 
  null, false, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000026', 'Park Avenue Signature Deo', 'SKU-PC-PARK-026', 'Personal Care', 199.00, 189.00, 40, 
  'Long lasting masculine body fragrance spray for absolute freshness.', 'Park Avenue', '150ml', 'Can', false, '36 Months', 
  ARRAY['deodorant', 'perfume', 'fragrance', 'men'], 'Propellant, Ethyl Alcohol, Fragrance, Diethyl Phthalate', 'Shake can, spray 15cm away from armpits.', 
  'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=500', 4.3, 110, 
  null, false, 'can'
),
(
  'a0000000-0000-0000-0000-000000000027', 'Wild Stone Code Steel Deo', 'SKU-PC-WILD-027', 'Personal Care', 249.00, 235.00, 30, 
  'Premium daily wear body perfume spray for long-lasting freshness.', 'Wild Stone', '120ml', 'Bottle', false, '36 Months', 
  ARRAY['perfume', 'fragrance', 'wild-stone', 'men'], 'Ethyl Alcohol, Fragrance, Aqua, Propylene Glycol', 'Spray directly on pulse points.', 
  'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=500', 4.6, 95, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000028', 'Dettol Original Soap', 'SKU-HYG-DETS-028', 'Hygiene', 35.00, 33.00, 150, 
  'Complete germ defence hygiene protection soap block.', 'Dettol', '75g', 'Bar', false, '24 Months', 
  ARRAY['soap', 'dettol', 'germ-protection', 'bathing'], 'Sodium Palmate, Talc, Aqua, Glycerin, Chloroxylenol', 'Lather on body, rinse thoroughly.', 
  'https://images.unsplash.com/photo-1607006342411-9a336f7cf97f?w=500', 4.6, 420, 
  null, false, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000029', 'Gillette Flexi Vibe Razor', 'SKU-PC-GILL-029', 'Personal Care', 70.00, 65.00, 50, 
  'Smooth skin contour manual shaving razor handle.', 'Gillette', '1 Unit', 'Packet', false, '60 Months', 
  ARRAY['razor', 'shaving', 'blade', 'gillette'], 'Plastic Handle, Platinum Coated Blades', 'Apply shaving foam and slide razor along hair grain.', 
  'https://images.unsplash.com/photo-1626294336769-ab4b0b14b301?w=500', 4.4, 85, 
  null, false, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000030', 'Oral-B CrossAction Brush', 'SKU-HYG-ORAL-030', 'Hygiene', 50.00, 48.00, 100, 
  'Deep cleaning anti-plaque soft bristle manual toothbrush.', 'Oral-B', '1 Unit', 'Packet', false, '36 Months', 
  ARRAY['toothbrush', 'brush', 'oral-b', 'hygiene'], 'Nylon Bristles, Synthetic Handle', 'Brush teeth twice daily, replace every 3 months.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.5, 130, 
  null, false, 'piece'
),

-- Mandi & Dairy Mart (is_mandi = true)
-- Fresh Produce (10 items)
(
  'a0000000-0000-0000-0000-000000000031', 'Fresh Local Tomatoes', 'SKU-MANDI-TOM-031', 'Vegetables', 40.00, 35.00, 100, 
  'Juicy red ripe farm fresh country tomatoes sourced daily.', 'Local Farm', '1kg', 'Crate', true, '3 Days', 
  ARRAY['tomato', 'vegetables', 'fresh', 'mandi'], '100% Organic Tomatoes', 'Wash thoroughly before cooking or eating raw.', 
  'https://images.unsplash.com/photo-1595855759920-86582396756a?w=500', 4.5, 90, 
  '{"Vitamin C": "25%", "Iron": "2%", "Calcium": "1%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000032', 'Red Onions (Pyaaz)', 'SKU-MANDI-ONIO-032', 'Vegetables', 35.00, 32.00, 150, 
  'Crispy red pungent onions directly procured from local fields.', 'Local Farm', '1kg', 'Bag', false, '10 Days', 
  ARRAY['onion', 'pyaaz', 'vegetables', 'mandi'], '100% Organic Red Onions', 'Peel and chop as desired.', 
  'https://images.unsplash.com/photo-1508747703725-719777637510?w=500', 4.4, 75, 
  '{"Energy": "40 kcal", "Sodium": "4mg", "Potassium": "146mg"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000033', 'Organic Potatoes (Aloo)', 'SKU-MANDI-POTA-033', 'Vegetables', 30.00, 28.00, 200, 
  'Fresh gold potatoes, dynamic kitchen pantry staple.', 'Local Farm', '1kg', 'Bag', true, '15 Days', 
  ARRAY['potato', 'aloo', 'vegetables', 'fresh'], '100% Farm Potatoes', 'Peel, wash and boil or fry.', 
  'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=500', 4.6, 115, 
  '{"Energy": "77 kcal", "Total Fat": "0.1g", "Total Carbohydrates": "17g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000034', 'Green Cauliflower', 'SKU-MANDI-CAUL-034', 'Vegetables', 45.00, 40.00, 60, 
  'Crispy white field cauliflower head with green protective stems.', 'Local Farm', '1 Unit', 'Crate', false, '5 Days', 
  ARRAY['cauliflower', 'vegetables', 'fresh', 'organic'], '100% Organic Cauliflower Head', 'Chop florets and wash in hot saline water before cooking.', 
  'https://images.unsplash.com/photo-1568584711271-6c9aa9dc6063?w=500', 4.2, 50, 
  '{"Energy": "25 kcal", "Vitamin C": "80%", "Dietary Fiber": "2g"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000035', 'Fresh Green Spinach', 'SKU-MANDI-SPIN-035', 'Vegetables', 25.00, 22.00, 50, 
  'Organic leafy green spinach bunches rich in vitamins and iron.', 'Local Farm', '1 Bunch', 'Bundle', true, '2 Days', 
  ARRAY['spinach', 'palak', 'greens', 'leafy'], '100% Fresh Green Spinach Leaves', 'Wash thoroughly in cold water to remove dirt.', 
  'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=500', 4.7, 85, 
  '{"Energy": "23 kcal", "Iron": "15%", "Vitamin A": "180%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000036', 'Shimla Capsicum (Bell Pepper)', 'SKU-MANDI-CAPS-036', 'Vegetables', 60.00, 55.00, 70, 
  'Crunchy fresh bell peppers ideal for pizzas, pastas or frying.', 'Local Farm', '500g', 'Packet', false, '5 Days', 
  ARRAY['capsicum', 'bell-pepper', 'vegetables', 'fresh'], '100% Fresh Bell Peppers', 'Remove inner seeds and slice.', 
  'https://images.unsplash.com/photo-1563565080-6c905b4b1a45?w=500', 4.3, 40, 
  '{"Energy": "20 kcal", "Vitamin C": "130%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000037', 'Golden Cavendish Bananas', 'SKU-MANDI-BANA-037', 'Fruits', 50.00, 45.00, 120, 
  'Naturally sweet yellow fresh Cavendish bananas.', 'Local Farm', '1 Dozen', 'Bundle', true, '4 Days', 
  ARRAY['banana', 'fruits', 'sweet', 'potassium'], 'Fresh Yellow Bananas', 'Peel and consume directly.', 
  'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500', 4.6, 210, 
  '{"Energy": "89 kcal", "Potassium": "358mg", "Sugars": "12g"}', true, 'dozen'
),
(
  'a0000000-0000-0000-0000-000000000038', 'Kashmiri Red Apples', 'SKU-MANDI-APPL-038', 'Fruits', 120.00, 110.00, 80, 
  'Sweet and crisp organic Kashmiri red apples sourced from local orchards.', 'Kashmiri Farms', '1kg', 'Box', true, '15 Days', 
  ARRAY['apple', 'fruits', 'kashmiri', 'sweet'], 'Selected Premium Red Apples', 'Wash skin and consume directly.', 
  'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500', 4.7, 340, 
  '{"Energy": "52 kcal", "Dietary Fiber": "2.4g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000039', 'Fresh Citrus Lemons', 'SKU-MANDI-LEMO-039', 'Fruits', 20.00, 18.00, 100, 
  'Tangy green-yellow juicy lemons pack for daily dietary intake.', 'Local Farm', '6 Pcs', 'Packet', false, '10 Days', 
  ARRAY['lemon', 'citrus', 'tangy', 'beverage'], 'Fresh Organic Lemons', 'Cut and squeeze juice.', 
  'https://images.unsplash.com/photo-1590502593747-42a996133562?w=500', 4.4, 65, 
  '{"Vitamin C": "53mg"}', true, 'dozen'
),
(
  'a0000000-0000-0000-0000-000000000040', 'Salad Cucumber (Kheera)', 'SKU-MANDI-CUCU-040', 'Vegetables', 30.00, 27.00, 90, 
  'Hydrating organic fresh green cucumbers for cool summer salads.', 'Local Farm', '1kg', 'Bag', false, '5 Days', 
  ARRAY['cucumber', 'kheera', 'salad', 'vegetables'], 'Fresh Farm Cucumbers', 'Wash, peel optionally and slice.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.3, 80, 
  '{"Energy": "15 kcal", "Water": "95%"}', true, 'kg'
),

-- Dairy & Essentials (10 items)
(
  'a0000000-0000-0000-0000-000000000041', 'Amul Taaza Milk Pouch', 'SKU-DAIRY-AMUL-041', 'Dairy', 27.00, 26.50, 300, 
  'Fresh pasteurized double homogenized toned milk pouch.', 'Amul', '500ml', 'Packet', true, '2 Days', 
  ARRAY['milk', 'dairy', 'toned-milk', 'amul'], 'Homogenized Toned Milk, Vitamin A, Vitamin D', 'Boil before consumption. Keep refrigerated.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.8, 980, 
  '{"Energy": "58 kcal", "Total Fat": "3g", "Protein": "3.2g", "Calcium": "120mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000042', 'Amul Paneer Block 200g', 'SKU-DAIRY-PANE-042', 'Dairy', 90.00, 85.00, 100, 
  'Soft and rich cottage cheese block perfect for paneer curries.', 'Amul', '200g', 'Packet', true, '10 Days', 
  ARRAY['paneer', 'cottage-cheese', 'dairy', 'amul'], 'Pasteurized Cottage Cheese', 'Cut into cubes and shallow fry or add directly to gravy.', 
  'https://images.unsplash.com/photo-1628294895950-9805252327bc?w=500', 4.7, 450, 
  '{"Energy": "289 kcal", "Total Fat": "22g", "Protein": "18g", "Calcium": "480mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000043', 'Amul Butter Block 100g', 'SKU-DAIRY-BUTT-043', 'Dairy', 58.00, 56.00, 120, 
  'Classic salted yellow table butter block, the favorite toast partner.', 'Amul', '100g', 'Box', true, '180 Days', 
  ARRAY['butter', 'salted-butter', 'dairy', 'amul'], 'Milk Fat, Salt, Beta Carotene Color', 'Spread on toast, use in frying or baking.', 
  'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500', 4.8, 670, 
  '{"Energy": "722 kcal", "Total Fat": "80g", "Sodium": "830mg"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000044', 'Mother Dairy Plain Dahi', 'SKU-DAIRY-DAHI-044', 'Dairy', 35.00, 33.00, 150, 
  'Thick set pasteurized cup curd, rich in gut-healthy probiotics.', 'Mother Dairy', '400g', 'Cup', false, '7 Days', 
  ARRAY['curd', 'dahi', 'dairy', 'healthy'], 'Standardised Milk, Active Lactic Cultures', 'Consume directly or prepare buttermilk.', 
  'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500', 4.5, 230, 
  '{"Energy": "60 kcal", "Total Fat": "3g", "Protein": "3.5g", "Calcium": "140mg"}', true, 'cup'
),
(
  'a0000000-0000-0000-0000-000000000045', 'Amul Cheese Slices 200g', 'SKU-DAIRY-CHEE-045', 'Dairy', 140.00, 135.00, 75, 
  'Processed cheddar cheese slices pack perfect for sandwiches and burgers.', 'Amul', '200g', 'Packet', true, '120 Days', 
  ARRAY['cheese', 'cheese-slices', 'dairy', 'cheddar'], 'Cheese, Milk Solids, Emulsifiers, Common Salt', 'Place slice inside bread and toast.', 
  'https://images.unsplash.com/photo-1528287942911-41584a371cee?w=500', 4.7, 310, 
  '{"Energy": "310 kcal", "Total Fat": "24g", "Protein": "20g", "Sodium": "1300mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000046', 'Amul Fresh Cream 250ml', 'SKU-DAIRY-CREA-046', 'Dairy', 65.00, 62.00, 80, 
  'Rich low-fat fresh dairy cream for food and dessert enhancements.', 'Amul', '250ml', 'Carton', false, '120 Days', 
  ARRAY['cream', 'fresh-cream', 'dairy', 'amul'], 'Fresh Dairy Milk Fat Solids', 'Whisk or pour directly on top of curries.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.6, 190, 
  '{"Energy": "246 kcal", "Total Fat": "25g", "Protein": "2g"}', true, 'carton'
),
(
  'a0000000-0000-0000-0000-000000000047', 'Yakult Probiotic Drink 5x', 'SKU-DAIRY-YAKU-047', 'Dairy', 80.00, 76.00, 50, 
  'Fermented probiotic milk drink wellness pack for gut health.', 'Yakult', '5 Pcs', 'Pack', false, '40 Days', 
  ARRAY['probiotic', 'yakult', 'healthy', 'dairy'], 'Water, Skimmed Milk Powder, Glucose, Lactobacillus Casei Shirota', 'Drink one bottle daily.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.7, 145, 
  '{"Energy": "50 kcal", "Protein": "0.8g", "Sugars": "12g"}', true, 'pack'
),
(
  'a0000000-0000-0000-0000-000000000048', 'Nandini Pure Cow Ghee', 'SKU-DAIRY-GHEE-048', 'Dairy', 350.00, 339.00, 40, 
  'Aromatic clarified pure butter cow ghee tin for cooking and flavoring.', 'Nandini', '500ml', 'Bottle', false, '360 Days', 
  ARRAY['ghee', 'cow-ghee', 'clarified-butter', 'dairy'], 'Pure Clarified Cow Butter Fat', 'Use in cooking or add on hot rotis.', 
  'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500', 4.8, 120, 
  '{"Energy": "897 kcal", "Total Fat": "99.7g"}', true, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000049', 'Fresh Country Eggs 12x', 'SKU-DAIRY-EGGS-049', 'Dairy', 80.00, 76.00, 100, 
  'Farm fresh protein-rich country brown eggs tray.', 'Local Farm', '12 Pcs', 'Tray', true, '15 Days', 
  ARRAY['eggs', 'brown-eggs', 'breakfast', 'protein'], 'Fresh Poultry Country Eggs', 'Boil, scramble or make omelettes.', 
  'https://images.unsplash.com/photo-1516448620398-c5f44bf9f441?w=500', 4.7, 520, 
  '{"Energy": "70 kcal", "Total Fat": "5g", "Protein": "6g"}', true, 'tray'
),
(
  'a0000000-0000-0000-0000-000000000050', 'Amul Spiced Buttermilk', 'SKU-DAIRY-LASS-050', 'Dairy', 20.00, 19.00, 200, 
  'Refreshing spiced salted buttermilk drink pouch, perfect digestive companion.', 'Amul', '250ml', 'Packet', true, '7 Days', 
  ARRAY['buttermilk', 'lassi', 'refresher', 'amul'], 'Curd, Water, Spices (Ginger, Coriander, Green Chilli), Salt', 'Shake well, serve ice cold.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.6, 250, 
  '{"Energy": "30 kcal", "Total Fat": "1.5g", "Sodium": "280mg"}', true, 'packet'
);
