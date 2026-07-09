-- Insert 50 MORE Logically Useful Shop Items (Index 101 to 150)
-- Columns: id, name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, shelf_life, tags, ingredients, how_to_use, image_url, rating, total_reviews, nutritional_info, is_mandi, unit
INSERT INTO shop_items (
  id, name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, shelf_life, tags, ingredients, how_to_use, image_url, rating, total_reviews, nutritional_info, is_mandi, unit
) VALUES
-- Snacks & Ready to Eat (15 items)
(
  'a0000000-0000-0000-0000-000000000101', 'Bingo Mad Angles Achaari', 'SKU-SNACK-BING-101', 'Snacks', 20.00, 19.00, 140, 
  'Perfect triangle chips with the twist of spicy Indian pickles.', 'Bingo', '80g', 'Packet', false, '6 Months', 
  ARRAY['chips', 'spicy', 'bingo', 'namkeen'], 'Rice Grits, Corn Grits, Seasoning, Acidity Regulators', 'Ready to consume directly.', 
  'https://images.unsplash.com/photo-1566478989037-eec170784d20?w=500', 4.4, 150, 
  '{"Energy": "540 kcal", "Sodium": "750mg"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000102', 'Lipton Green Tea Honey Lemon', 'SKU-BEV-LIPT-102', 'Beverages', 150.00, 142.00, 60, 
  'Refreshing green tea bags with clean notes of honey and lemon.', 'Lipton', '25 Bags', 'Box', true, '12 Months', 
  ARRAY['green-tea', 'healthy', 'lemon', 'dietary'], 'Green Tea Leaves, Honey Lemon Flavoring', 'Dip in hot water for 2-3 minutes. Drink without milk.', 
  'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500', 4.6, 210, 
  '{"Energy": "2 kcal", "Vitamin C": "10%"}', false, 'box'
),
(
  'a0000000-0000-0000-0000-000000000103', 'MTR 3-Minute Poha Cup', 'SKU-SNACK-MTRP-103', 'Snacks', 45.00, 42.00, 100, 
  'Instant breakfast cup with standard flattened rice and spice mix.', 'MTR', '80g', 'Cup', false, '9 Months', 
  ARRAY['instant', 'poha', 'breakfast', 'ready-to-eat'], 'Rice Flakes, Edible Vegetable Fat, Peanuts, Raisins, Spices', 'Add boiling water up to the line, close lid for 3 minutes.', 
  'https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=500', 4.3, 115, 
  '{"Energy": "320 kcal", "Protein": "6g", "Total Fat": "8g"}', false, 'cup'
),
(
  'a0000000-0000-0000-0000-000000000104', 'Maggi Oats Masala Noodles', 'SKU-NOOD-OATS-104', 'Noodles', 25.00, 23.00, 120, 
  'Wholegrain oats instant noodles with rich veggie masala tastemaker.', 'Nestle', '73g', 'Packet', false, '9 Months', 
  ARRAY['noodles', 'instant', 'oats', 'healthy'], 'Oat Flour, Wheat Flour, Palm Oil, Spice Mix', 'Boil in water for 3-4 minutes.', 
  'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=500', 4.5, 190, 
  '{"Energy": "310 kcal", "Protein": "8.5g", "Dietary Fiber": "4.5g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000105', 'Bournvita Health Drink', 'SKU-BEV-BOUR-105', 'Beverages', 220.00, 210.00, 50, 
  'Nutrition drink mix with inner strength formula containing Vitamin D.', 'Cadbury', '500g', 'Jar', false, '12 Months', 
  ARRAY['health-drink', 'chocolate', 'bournvita', 'milk-addon'], 'Malt Extract, Sugar, Cocoa Powder, Milk Solids, Minerals', 'Add two teaspoons to hot or cold milk and stir.', 
  'https://images.unsplash.com/photo-1549007994-cb92ca71450a?w=500', 4.7, 340, 
  '{"Energy": "390 kcal", "Protein": "7g", "Vitamin D": "50%"}', false, 'jar'
),
(
  'a0000000-0000-0000-0000-000000000106', 'Little Hearts Biscuits', 'SKU-SNACK-HEAR-106', 'Snacks', 20.00, 19.00, 130, 
  'Puff pastry biscuits with sweet sugar glazing, classic favorite.', 'Britannia', '75g', 'Packet', true, '6 Months', 
  ARRAY['biscuits', 'sweet', 'hearts', 'britannia'], 'Wheat Flour, Sugar, Palm Oil, Raising Agents', 'Ready to eat.', 
  'https://images.unsplash.com/photo-1558961309-dbdf71799f14?w=500', 4.6, 280, 
  '{"Energy": "480 kcal", "Total Fat": "18g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000107', 'Ching Secret Schezwan Noodles', 'SKU-NOOD-CHIN-107', 'Noodles', 15.00, 14.50, 150, 
  'Spicy schezwan instant noodles for an authentic Chinese kick.', 'Chings', '60g', 'Packet', false, '9 Months', 
  ARRAY['noodles', 'instant', 'schezwan', 'spicy'], 'Wheat Flour, Palm Oil, Garlic, Red Chilli, Soy Sauce', 'Boil in water for 3 minutes.', 
  'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=500', 4.4, 210, 
  '{"Energy": "350 kcal", "Sodium": "990mg"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000108', 'Krunchex Potato Chips', 'SKU-SNACK-KRUN-108', 'Snacks', 30.00, 27.00, 90, 
  'Crunchy kettle-cooked spicy potato chips, extra thick.', 'Krunchex', '100g', 'Packet', false, '6 Months', 
  ARRAY['chips', 'potato', 'kettle-chips', 'spicy'], 'Potatoes, Rice Bran Oil, Chilli Seasoning, Salt', 'Eat directly.', 
  'https://images.unsplash.com/photo-1566478989037-eec170784d20?w=500', 4.2, 70, 
  '{"Energy": "510 kcal", "Total Fat": "28g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000109', 'Real Cranberry Fruit Juice', 'SKU-BEV-CRAN-109', 'Beverages', 130.00, 122.00, 60, 
  'Tangy and sweet cranberry juice nectar pack, rich in antioxidants.', 'Real Juice', '1L', 'Carton', false, '6 Months', 
  ARRAY['juice', 'cranberry', 'beverage', 'healthy'], 'Water, Cranberry Juice Concentrate, Sugar, Acidity Regulator', 'Shake well, serve ice cold.', 
  'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=500', 4.5, 110, 
  '{"Energy": "54 kcal", "Sugars": "13g"}', false, 'carton'
),
(
  'a0000000-0000-0000-0000-000000000110', 'Paper Boat Jaljeera Pouch', 'SKU-BEV-JALJ-110', 'Beverages', 35.00, 32.00, 100, 
  'Traditional refreshing spicy and sour cumin seed digestive drink.', 'Paper Boat', '250ml', 'Packet', false, '6 Months', 
  ARRAY['jaljeera', 'cumin', 'beverage', 'digestive'], 'Water, Lemon Juice, Sugar, Cumin, Black Salt, Mint', 'Serve chilled.', 
  'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=500', 4.6, 130, 
  '{"Energy": "80 kcal", "Sodium": "320mg"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000111', 'Snickers Peanut Chocolate', 'SKU-CHOC-SNIK-111', 'Chocolates', 50.00, 47.00, 150, 
  'Satisfying milk chocolate bar filled with peanuts, caramel and nougat.', 'Snickers', '50g', 'Bar', true, '12 Months', 
  ARRAY['chocolate', 'peanut', 'snickers', 'energy-bar'], 'Milk Chocolate, Peanuts, Glucose Syrup, Sugar, Milk Fat', 'Bite directly when hungry.', 
  'https://images.unsplash.com/photo-1549007994-cb92ca71450a?w=500', 4.8, 480, 
  '{"Energy": "250 kcal", "Protein": "4.5g", "Total Fat": "12g"}', false, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000112', 'Munch Chocolate Bar', 'SKU-CHOC-MUNC-112', 'Chocolates', 10.00, 9.50, 250, 
  'Crunchy wafer bar coated with rich cocoa layers.', 'Nestle', '18g', 'Bar', false, '9 Months', 
  ARRAY['wafer', 'chocolate', 'nestle', 'munch'], 'Sugar, Wheat Flour, Hydrogenated Vegetable Fats, Cocoa Solids', 'Break and enjoy.', 
  'https://images.unsplash.com/photo-1549007994-cb92ca71450a?w=500', 4.5, 340, 
  '{"Energy": "85 kcal", "Sugars": "7g"}', false, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000113', 'Haldirams Dry Fruit Mix', 'SKU-SNACK-DFRT-113', 'Snacks', 120.00, 114.00, 70, 
  'Premium blend of spicy dry fruits, almonds, cashews and raisins.', 'Haldiram', '150g', 'Packet', false, '6 Months', 
  ARRAY['dry-fruits', 'cashew', 'almond', 'namkeen'], 'Almonds, Cashews, Raisins, Besan Sev, Spices, Salt', 'Serve with hot tea or drinks.', 
  'https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=500', 4.6, 120, 
  '{"Energy": "520 kcal", "Protein": "14g", "Total Fat": "32g"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000114', 'Tang Orange Instant Powder', 'SKU-BEV-TANG-114', 'Beverages', 140.00, 132.00, 80, 
  'Instant orange flavored soft drink concentrate powder, loaded with Vitamin C.', 'Tang', '500g', 'Packet', false, '18 Months', 
  ARRAY['juice-powder', 'orange', 'tang', 'beverage'], 'Sugar, Acidity Regulator, Vitamin C, Orange Flavor', 'Mix 2 tablespoons in cold water and stir.', 
  'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=500', 4.4, 185, 
  '{"Energy": "380 kcal", "Vitamin C": "100mg"}', false, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000115', 'Kelloggs Corn Flakes', 'SKU-SNACK-CFLK-115', 'Snacks', 180.00, 169.00, 50, 
  'Original golden toasted corn flakes breakfast cereal.', 'Kelloggs', '475g', 'Box', false, '12 Months', 
  ARRAY['cereal', 'cornflakes', 'breakfast', 'healthy'], 'Milled Corn, Sugar, Malt Extract, Iodized Salt, Vitamins', 'Serve with cold or warm milk.', 
  'https://images.unsplash.com/photo-1521483137712-75bd500a4f6a?w=500', 4.5, 290, 
  '{"Energy": "378 kcal", "Protein": "7g", "Iron": "8.5mg"}', false, 'packet'
),

-- Personal Care & Hygiene (10 items)
(
  'a0000000-0000-0000-0000-000000000116', 'Sensodyne Fresh Gel', 'SKU-HYG-SENS-116', 'Hygiene', 120.00, 114.00, 90, 
  'Daily sensitivity protection toothpaste gel with fresh mint flavor.', 'Sensodyne', '100g', 'Tube', true, '24 Months', 
  ARRAY['toothpaste', 'sensitivity', 'sensodyne', 'oral'], 'Potassium Nitrate, Sodium Fluoride, Silica, Menthol', 'Brush twice daily, do not swallow.', 
  'https://images.unsplash.com/photo-1559599189-fe84dea4eb79?w=500', 4.7, 410, 
  null, false, 'tube'
),
(
  'a0000000-0000-0000-0000-000000000117', 'Clinic Plus Strong Hair', 'SKU-PC-CLIN-117', 'Personal Care', 90.00, 85.00, 110, 
  'Egg protein formula daily strengthening hair shampoo.', 'Unilever', '175ml', 'Bottle', false, '36 Months', 
  ARRAY['shampoo', 'hair', 'clinic-plus', 'protein'], 'Water, Sodium Laureth Sulfate, Egg Powder, Perfume', 'Apply to wet hair, lather and rinse.', 
  'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=500', 4.4, 280, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000118', 'Ponds White Beauty Cream', 'SKU-PC-POND-118', 'Personal Care', 150.00, 142.00, 60, 
  'Daily anti-spot fairness face cream with SPF 15 protection.', 'Ponds', '50g', 'Tube', false, '36 Months', 
  ARRAY['face-cream', 'ponds', 'fairness', 'spf'], 'Water, Palmitic Acid, Niacinamide, Glycerin, Titanium Dioxide', 'Apply dots on cleansed face and neck, massage gently.', 
  'https://images.unsplash.com/photo-1556229174-5e42a09e45af?w=500', 4.5, 195, 
  null, false, 'tube'
),
(
  'a0000000-0000-0000-0000-000000000119', 'Loreal Total Repair Hair Mask', 'SKU-PC-LORE-119', 'Personal Care', 349.00, 329.00, 30, 
  'Deep conditioning repair mask for dry and damaged hair.', 'Loreal', '200ml', 'Jar', false, '36 Months', 
  ARRAY['hair-mask', 'repair', 'loreal', 'damaged-hair'], 'Water, Cetearyl Alcohol, Salicylic Acid, Ceramide', 'Apply to towel-dried hair length, leave for 5 minutes, rinse.', 
  'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=500', 4.6, 85, 
  null, false, 'jar'
),
(
  'a0000000-0000-0000-0000-000000000120', 'Dettol Instant Hand Sanitizer', 'SKU-HYG-SANI-120', 'Hygiene', 50.00, 48.00, 150, 
  'Rinse-free instant hand sanitizer gel kills 99.9% germs.', 'Dettol', '50ml', 'Bottle', false, '24 Months', 
  ARRAY['sanitizer', 'dettol', 'hygiene', 'germ-protection'], 'Ethyl Alcohol 70%, Water, Glycerin, Fragrance', 'Apply small coin-sized drop on palms, rub until dry.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.8, 620, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000121', 'Parachute Pure Coconut Oil', 'SKU-PC-PARA-121', 'Personal Care', 90.00, 85.00, 100, 
  '100% pure edible grade coconut hair oil.', 'Parachute', '200ml', 'Bottle', false, '18 Months', 
  ARRAY['coconut-oil', 'hair-oil', 'parachute', 'essential'], '100% Pure Coconut Oil', 'Apply to hair scalp, massage gently.', 
  'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=500', 4.7, 450, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000122', 'Lizol Floor Cleaner 1L', 'SKU-HYG-LIZO-122', 'Hygiene', 170.00, 159.00, 50, 
  'Disinfectant citrus floor cleaner liquid kills germs, removes stains.', 'Lizol', '1L', 'Bottle', false, '24 Months', 
  ARRAY['floor-cleaner', 'lizol', 'disinfectant', 'hygiene'], 'Benzalkonium Chloride, Surfactant, Fragrance', 'Dilute one cap in half bucket water to mop floor.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.5, 190, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000123', 'Vim Dishwash Liquid Gel', 'SKU-HYG-VIMD-123', 'Hygiene', 55.00, 52.00, 120, 
  'Power of 100 lemons concentrated dishwashing liquid gel.', 'Vim', '250ml', 'Bottle', false, '24 Months', 
  ARRAY['dishwash', 'vim', 'gel', 'cleaning'], 'Sodium Linear Alkyl Benzene Sulfonate, Lemon Extracts', 'Mix one teaspoon gel in small bowl of water, apply with scrub.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.6, 310, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000124', 'Harpic Power Toilet Cleaner', 'SKU-HYG-HARP-124', 'Hygiene', 95.00, 89.00, 80, 
  'Disinfectant blue toilet bowl cleaner gel kills pathogens.', 'Harpic', '500ml', 'Bottle', false, '24 Months', 
  ARRAY['toilet-cleaner', 'harpic', 'disinfectant', 'hygiene'], 'Hydrochloric Acid 10.5%, Surfactant', 'Pour around rim, leave for 20 minutes, brush and flush.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.7, 430, 
  null, false, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000125', 'Dettol Hand Sanitizer Spray', 'SKU-HYG-DETP-125', 'Hygiene', 80.00, 75.00, 90, 
  'On-the-go pocket instant disinfectant hand sanitizer spray.', 'Dettol', '30ml', 'Can', false, '24 Months', 
  ARRAY['sanitizer', 'spray', 'dettol', 'pocket-sanitizer'], 'Alcohol 70%, Aqua, Propylene Glycol', 'Spray directly on hands and rub.', 
  'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500', 4.4, 95, 
  null, false, 'can'
),

-- Mandi Veg & Fruits (15 items)
(
  'a0000000-0000-0000-0000-000000000126', 'Fresh Green Cabbage', 'SKU-MANDI-CABB-126', 'Vegetables', 35.00, 30.00, 80, 
  'Compact round green cabbage head sourced fresh from farms.', 'Local Farm', '1 Unit', 'Crate', false, '5 Days', 
  ARRAY['cabbage', 'patta-gobhi', 'vegetables', 'fresh'], 'Fresh Cabbage Head', 'Shred leaves and wash in warm water.', 
  'https://images.unsplash.com/photo-1568584711271-6c9aa9dc6063?w=500', 4.3, 70, 
  '{"Energy": "25 kcal", "Vitamin C": "60%"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000127', 'Fresh Mint Bunches', 'SKU-MANDI-MINT-127', 'Vegetables', 15.00, 12.00, 110, 
  'Cooling fresh mint leaves bundle for native chutney preparation.', 'Local Farm', '1 Bunch', 'Bundle', false, '3 Days', 
  ARRAY['mint', 'pudina', 'greens', 'chutney'], 'Fresh Mint Leaves', 'Wash and grind with coriander and green chillies.', 
  'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=500', 4.6, 95, 
  null, true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000128', 'Farm Fresh Radish (Mooli)', 'SKU-MANDI-RADS-128', 'Vegetables', 30.00, 27.00, 100, 
  'Crispy white radish roots with green leafy heads.', 'Local Farm', '1kg', 'Bag', false, '6 Days', 
  ARRAY['radish', 'mooli', 'salad', 'vegetables'], 'Fresh Radish Roots', 'Wash, peel skin and grate for salad or parathas.', 
  'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=500', 4.4, 85, 
  '{"Energy": "16 kcal", "Dietary Fiber": "1.6g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000129', 'Hybrid Green Capsicums', 'SKU-MANDI-HCAP-129', 'Vegetables', 55.00, 50.00, 90, 
  'Large crispy hybrid green bell peppers, daily harvest.', 'Local Farm', '1kg', 'Bag', false, '5 Days', 
  ARRAY['capsicum', 'bell-pepper', 'vegetables', 'mandi'], 'Fresh Green Capsicum Grains', 'Wash, chop and sauté.', 
  'https://images.unsplash.com/photo-1563565080-6c905b4b1a45?w=500', 4.5, 115, 
  '{"Energy": "20 kcal", "Vitamin C": "130%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000130', 'Sweet Golden Papayas', 'SKU-MANDI-PAPG-130', 'Fruits', 60.00, 55.00, 60, 
  'Orchard fresh yellow pulpy papayas, rich in natural enzymes.', 'Local Farm', '1 Unit', 'Crate', false, '5 Days', 
  ARRAY['papaya', 'papeeta', 'fruits', 'sweet'], 'Sweet Ripe Papaya', 'Slice, remove seeds and peel skin.', 
  'https://images.unsplash.com/photo-1610832958506-ee5633613ab2?w=500', 4.5, 90, 
  '{"Energy": "43 kcal", "Vitamin A": "20%"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000131', 'Green Coriander Bunches', 'SKU-MANDI-CORN-131', 'Vegetables', 12.00, 10.00, 150, 
  'Organic green coriander bundles with roots, aromatic garnish.', 'Local Farm', '1 Bunch', 'Bundle', false, '2 Days', 
  ARRAY['coriander', 'dhaniya', 'greens', 'garnish'], 'Fresh Coriander Leaves', 'Wash thoroughly in cold water to remove dirt.', 
  'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=500', 4.7, 340, 
  null, true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000132', 'Sweet Pineapple Whole', 'SKU-MANDI-PINE-132', 'Fruits', 80.00, 75.00, 50, 
  'Juicy sweet tropical pineapples with crown leaves.', 'Local Farm', '1 Unit', 'Crate', false, '7 Days', 
  ARRAY['pineapple', 'ananas', 'fruits', 'sweet'], 'Sweet Ripe Pineapple', 'Cut crown and tough skin, slice flesh.', 
  'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?w=500', 4.6, 80, 
  '{"Energy": "50 kcal", "Vitamin C": "80%"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000133', 'Nashik Black Grapes', 'SKU-MANDI-BGRP-133', 'Fruits', 110.00, 99.00, 70, 
  'Sweet and juicy seedless black grapes directly from vineyards.', 'Nashik Farms', '500g', 'Crate', true, '4 Days', 
  ARRAY['grapes', 'black-grapes', 'seedless', 'sweet'], 'Seedless Black Grapes', 'Wash grapes thoroughly before eating.', 
  'https://images.unsplash.com/photo-1537084642907-629340c7e59c?w=500', 4.7, 190, 
  '{"Energy": "69 kcal", "Antioxidants": "High"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000134', 'Organic Bottle Gourd (Lauki)', 'SKU-MANDI-LAUK-134', 'Vegetables', 30.00, 26.00, 80, 
  'Tender light green bottle gourds, easy to digest vegetable.', 'Local Farm', '1 Unit', 'Crate', false, '5 Days', 
  ARRAY['bottle-gourd', 'lauki', 'ghia', 'vegetables'], 'Fresh Bottle Gourd', 'Peel, wash, slice and pressure cook.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.3, 90, 
  '{"Energy": "15 kcal", "Water": "96%"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000135', 'Organic Bitter Gourd (Karela)', 'SKU-MANDI-KARE-135', 'Vegetables', 45.00, 40.00, 60, 
  'Fresh bumpy dark green bitter gourds, rich in vitamins.', 'Local Farm', '500g', 'Packet', false, '6 Days', 
  ARRAY['bitter-gourd', 'karela', 'vegetables', 'diabetic-friendly'], 'Organic Bitter Gourd', 'Slice, rub with salt to reduce bitterness, cook.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.2, 50, 
  '{"Charantin": "Active"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000136', 'Fresh Ridge Gourd (Turi)', 'SKU-MANDI-TURI-136', 'Vegetables', 40.00, 36.00, 70, 
  'Tender green ridge gourds sourced fresh from local climbers.', 'Local Farm', '1kg', 'Bag', false, '5 Days', 
  ARRAY['ridge-gourd', 'turi', 'torai', 'vegetables'], 'Ridge Gourd', 'Scrape ridges, peel skin, wash and cook.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.4, 40, 
  '{"Energy": "17 kcal"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000137', 'Fresh Lady Finger (Bhindi)', 'SKU-MANDI-OKRA-137', 'Vegetables', 48.00, 44.00, 100, 
  'Tender green okra pods directly harvested from local farms.', 'Local Farm', '1kg', 'Bag', true, '4 Days', 
  ARRAY['lady-finger', 'bhindi', 'okra', 'vegetables'], 'Fresh Green Okra Grains', 'Wash, dry completely, slice and stir fry.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.6, 210, 
  '{"Energy": "33 kcal", "Dietary Fiber": "3.2g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000138', 'Kashmiri Golden Apples', 'SKU-MANDI-GAPP-138', 'Fruits', 140.00, 129.00, 50, 
  'Sweet and crisp golden-yellow Kashmiri apples, organic.', 'Kashmiri Farms', '1kg', 'Box', true, '15 Days', 
  ARRAY['apple', 'golden-apple', 'sweet', 'fruits'], 'Selected Golden Apples', 'Wash skin and consume directly.', 
  'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500', 4.8, 310, 
  '{"Energy": "52 kcal", "Dietary Fiber": "2.4g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000139', 'Fresh Beetroot (Chukandar)', 'SKU-MANDI-BEET-139', 'Vegetables', 40.00, 36.00, 120, 
  'Deep red sweet beetroots rich in iron, perfect for salads.', 'Local Farm', '1kg', 'Bag', false, '15 Days', 
  ARRAY['beetroot', 'chukandar', 'iron-rich', 'salad'], 'Fresh Beetroot Roots', 'Wash, peel skin and grate for salad.', 
  'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=500', 4.5, 140, 
  '{"Energy": "43 kcal", "Iron": "6%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000140', 'Sweet Ripe Mangoes (Safeda)', 'SKU-MANDI-MSAF-140', 'Fruits', 110.00, 99.00, 150, 
  'Deliciously sweet yellow ripe Safeda mangoes sourced from local orchards.', 'Local Orchards', '1kg', 'Crate', true, '4 Days', 
  ARRAY['mango', 'safeda-mango', 'fruits', 'seasonal'], 'Safeda Mangoes', 'Wash skin, peel, slice and enjoy.', 
  'https://images.unsplash.com/photo-1553279768-865429fa0078?w=500', 4.9, 620, 
  '{"Energy": "60 kcal", "Sugars": "14g"}', true, 'kg'
),

-- Dairy Additions (10 items)
(
  'a0000000-0000-0000-0000-000000000141', 'Amul Taaza Milk 500ml Pouch', 'SKU-DAIRY-AMUL-141', 'Dairy', 27.00, 26.50, 300, 
  'Fresh pasteurized double homogenized toned milk pouch.', 'Amul', '500ml', 'Packet', true, '2 Days', 
  ARRAY['milk', 'dairy', 'toned-milk', 'amul'], 'Homogenized Toned Milk, Vitamin A, Vitamin D', 'Boil before consumption. Keep refrigerated.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.8, 980, 
  '{"Energy": "58 kcal", "Total Fat": "3g", "Protein": "3.2g", "Calcium": "120mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000142', 'Amul Paneer Block 200g', 'SKU-DAIRY-PANE-142', 'Dairy', 90.00, 85.00, 100, 
  'Soft and rich cottage cheese block perfect for paneer curries.', 'Amul', '200g', 'Packet', true, '10 Days', 
  ARRAY['paneer', 'cottage-cheese', 'dairy', 'amul'], 'Pasteurized Cottage Cheese', 'Cut into cubes and shallow fry or add directly to gravy.', 
  'https://images.unsplash.com/photo-1628294895950-9805252327bc?w=500', 4.7, 450, 
  '{"Energy": "289 kcal", "Total Fat": "22g", "Protein": "18g", "Calcium": "480mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000143', 'Amul Butter Block 100g', 'SKU-DAIRY-BUTT-143', 'Dairy', 58.00, 56.00, 120, 
  'Classic salted yellow table butter block, the favorite toast partner.', 'Amul', '100g', 'Box', true, '180 Days', 
  ARRAY['butter', 'salted-butter', 'dairy', 'amul'], 'Milk Fat, Salt, Beta Carotene Color', 'Spread on toast, use in frying or baking.', 
  'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500', 4.8, 670, 
  '{"Energy": "722 kcal", "Total Fat": "80g", "Sodium": "830mg"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000144', 'Mother Dairy Plain Dahi 400g', 'SKU-DAIRY-DAHI-144', 'Dairy', 35.00, 33.00, 150, 
  'Thick set pasteurized cup curd, rich in gut-healthy probiotics.', 'Mother Dairy', '400g', 'Cup', false, '7 Days', 
  ARRAY['curd', 'dahi', 'dairy', 'healthy'], 'Standardised Milk, Active Lactic Cultures', 'Consume directly or prepare buttermilk.', 
  'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500', 4.5, 230, 
  '{"Energy": "60 kcal", "Total Fat": "3g", "Protein": "3.5g", "Calcium": "140mg"}', true, 'cup'
),
(
  'a0000000-0000-0000-0000-000000000145', 'Amul Cheese Slices 200g', 'SKU-DAIRY-CHEE-145', 'Dairy', 140.00, 135.00, 75, 
  'Processed cheddar cheese slices pack perfect for sandwiches and burgers.', 'Amul', '200g', 'Packet', true, '120 Days', 
  ARRAY['cheese', 'cheese-slices', 'dairy', 'cheddar'], 'Cheese, Milk Solids, Emulsifiers, Common Salt', 'Place slice inside bread and toast.', 
  'https://images.unsplash.com/photo-1528287942911-41584a371cee?w=500', 4.7, 310, 
  '{"Energy": "310 kcal", "Total Fat": "24g", "Protein": "20g", "Sodium": "1300mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000146', 'Amul Fresh Cream 250ml', 'SKU-DAIRY-CREA-146', 'Dairy', 65.00, 62.00, 80, 
  'Rich low-fat fresh dairy cream for food and dessert enhancements.', 'Amul', '250ml', 'Carton', false, '120 Days', 
  ARRAY['cream', 'fresh-cream', 'dairy', 'amul'], 'Fresh Dairy Milk Fat Solids', 'Whisk or pour directly on top of curries.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.6, 190, 
  '{"Energy": "246 kcal", "Total Fat": "25g", "Protein": "2g"}', true, 'carton'
),
(
  'a0000000-0000-0000-0000-000000000147', 'Yakult Probiotic Drink 5x', 'SKU-DAIRY-YAKU-147', 'Dairy', 80.00, 76.00, 50, 
  'Fermented probiotic milk drink wellness pack for gut health.', 'Yakult', '5 Pcs', 'Pack', false, '40 Days', 
  ARRAY['probiotic', 'yakult', 'healthy', 'dairy'], 'Water, Skimmed Milk Powder, Glucose, Lactobacillus Casei Shirota', 'Drink one bottle daily.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.7, 145, 
  '{"Energy": "50 kcal", "Protein": "0.8g", "Sugars": "12g"}', true, 'pack'
),
(
  'a0000000-0000-0000-0000-000000000148', 'Nandini Pure Cow Ghee', 'SKU-DAIRY-GHEE-148', 'Dairy', 350.00, 339.00, 40, 
  'Aromatic clarified pure butter cow ghee tin for cooking and flavoring.', 'Nandini', '500ml', 'Bottle', false, '360 Days', 
  ARRAY['ghee', 'cow-ghee', 'clarified-butter', 'dairy'], 'Pure Clarified Cow Butter Fat', 'Use in cooking or add on hot rotis.', 
  'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500', 4.8, 120, 
  '{"Energy": "897 kcal", "Total Fat": "99.7g"}', true, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000149', 'Fresh Country Eggs 12x', 'SKU-DAIRY-EGGS-149', 'Dairy', 80.00, 76.00, 100, 
  'Farm fresh protein-rich country brown eggs tray.', 'Local Farm', '12 Pcs', 'Tray', true, '15 Days', 
  ARRAY['eggs', 'brown-eggs', 'breakfast', 'protein'], 'Fresh Poultry Country Eggs', 'Boil, scramble or make omelettes.', 
  'https://images.unsplash.com/photo-1516448620398-c5f44bf9f441?w=500', 4.7, 520, 
  '{"Energy": "70 kcal", "Total Fat": "5g", "Protein": "6g"}', true, 'tray'
),
(
  'a0000000-0000-0000-0000-000000000150', 'Amul Spiced Buttermilk', 'SKU-DAIRY-LASS-150', 'Dairy', 20.00, 19.00, 200, 
  'Refreshing spiced salted buttermilk drink pouch, perfect digestive companion.', 'Amul', '250ml', 'Packet', true, '7 Days', 
  ARRAY['buttermilk', 'lassi', 'refresher', 'amul'], 'Curd, Water, Spices (Ginger, Coriander, Green Chilli), Salt', 'Shake well, serve ice cold.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.6, 250, 
  '{"Energy": "30 kcal", "Total Fat": "1.5g", "Sodium": "280mg"}', true, 'packet'
);
