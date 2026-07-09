-- Insert 50 MORE Logically Useful Shop Items (Kiryana, Dairy, and Mandi vegetables/fruits)
-- Starts from ID suffix 051 to 100 to prevent collisions
-- Columns: id, name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, shelf_life, tags, ingredients, how_to_use, image_url, rating, total_reviews, nutritional_info, is_mandi, unit
INSERT INTO shop_items (
  id, name, sku_qr, category, price, discount_price, stock_quantity, description, brand, weight_ml, package_type, is_bestseller, shelf_life, tags, ingredients, how_to_use, image_url, rating, total_reviews, nutritional_info, is_mandi, unit
) VALUES
-- Kiryana Essentials (20 items)
(
  'a0000000-0000-0000-0000-000000000051', 'Fortune Basmati Rice', 'SKU-KIRY-RICE-051', 'Kiryana', 115.00, 108.00, 100, 
  'Premium long-grain basmati rice, perfect for biryani and daily meals.', 'Fortune', '1kg', 'Packet', true, '24 Months', 
  ARRAY['rice', 'basmati', 'kiryana', 'staple'], '100% Basmati Rice', 'Wash and soak for 30 minutes, boil in water.', 
  'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500', 4.7, 180, 
  '{"Energy": "350 kcal", "Protein": "8g", "Carbohydrates": "78g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000052', 'Aashirvaad Shudh Chakki Atta', 'SKU-KIRY-ATTA-052', 'Kiryana', 60.00, 56.00, 150, 
  '100% whole wheat chakki flour for soft and nutritious rotis.', 'Aashirvaad', '1kg', 'Packet', true, '3 Months', 
  ARRAY['atta', 'flour', 'wheat', 'kiryana'], 'Whole Wheat Grains', 'Knead with water to form soft dough for rotis.', 
  'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500', 4.8, 340, 
  '{"Energy": "362 kcal", "Dietary Fiber": "11g", "Protein": "12g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000053', 'Fortune Mustard Oil 1L', 'SKU-KIRY-OILM-053', 'Kiryana', 175.00, 168.00, 80, 
  'Pure cold-pressed mustard oil with strong aroma and high pungency.', 'Fortune', '1L', 'Bottle', false, '12 Months', 
  ARRAY['oil', 'mustard', 'cooking', 'kiryana'], 'Pure Mustard Seed Extract', 'Ideal for deep frying, sautéing and pickling.', 
  'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500', 4.6, 210, 
  '{"Energy": "898 kcal", "Total Fat": "99.8g"}', true, 'bottle'
),
(
  'a0000000-0000-0000-0000-000000000054', 'Tata Salt Lite', 'SKU-KIRY-SALT-054', 'Kiryana', 28.00, 26.00, 200, 
  'Iodized low-sodium salt, formulated to provide 15% less sodium.', 'Tata', '1kg', 'Packet', false, '36 Months', 
  ARRAY['salt', 'tata', 'low-sodium', 'kiryana'], 'Iodized Salt, Potassium Chloride', 'Use daily during cooking as per taste requirements.', 
  'https://images.unsplash.com/photo-1608885898957-a599fb1b467b?w=500', 4.7, 510, 
  '{"Sodium": "33.2g", "Potassium": "7.8g", "Iodine": "2mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000055', 'Madhur Pure Sugar', 'SKU-KIRY-SUGA-055', 'Kiryana', 52.00, 49.00, 120, 
  'Sulphur-free refined white sugar crystals, clean and hygienic.', 'Madhur', '1kg', 'Packet', false, '24 Months', 
  ARRAY['sugar', 'sweetener', 'refined', 'kiryana'], '100% Pure Cane Sugar', 'Add directly to hot beverages, desserts or dough.', 
  'https://images.unsplash.com/photo-1581447100599-35952c20aa90?w=500', 4.5, 130, 
  '{"Energy": "398 kcal", "Sucrose": "99.5g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000056', 'Tata Tea Premium', 'SKU-KIRY-TEAP-056', 'Kiryana', 140.00, 135.00, 90, 
  'Unique blend of big tea leaves for aroma and small leaves for strength.', 'Tata', '250g', 'Packet', false, '12 Months', 
  ARRAY['tea', 'chai', 'tata-tea', 'beverage'], 'Assam Tea CTC Blend', 'Boil with milk, water and sugar to prepare classic chai.', 
  'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500', 4.6, 290, 
  null, true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000057', 'Tata Sampann Toor Dal', 'SKU-KIRY-TDAL-057', 'Kiryana', 160.00, 152.00, 95, 
  'Unpolished, clean and protein-rich yellow split pigeon peas.', 'Tata', '1kg', 'Packet', true, '12 Months', 
  ARRAY['dal', 'toor-dal', 'pulses', 'staple'], 'Unpolished Toor Dal Grains', 'Pressure cook with water, turmeric and salt.', 
  'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500', 4.7, 180, 
  '{"Energy": "343 kcal", "Protein": "22g", "Dietary Fiber": "8g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000058', 'Tata Sampann Moong Dal', 'SKU-KIRY-MDAL-058', 'Kiryana', 150.00, 142.00, 100, 
  'Unpolished split yellow moong lentils, easy to digest.', 'Tata', '1kg', 'Packet', false, '12 Months', 
  ARRAY['dal', 'moong-dal', 'pulses', 'kiryana'], 'Unpolished Split Yellow Moong Grains', 'Cook or use in preparing dal khichdi.', 
  'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500', 4.5, 140, 
  '{"Energy": "348 kcal", "Protein": "24g", "Dietary Fiber": "7g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000059', 'Catch Turmeric Powder', 'SKU-KIRY-TURM-059', 'Kiryana', 35.00, 32.00, 110, 
  'Pure ground turmeric spice with high curcumin content.', 'Catch', '100g', 'Packet', false, '18 Months', 
  ARRAY['turmeric', 'haldi', 'spices', 'cooking'], 'Ground Turmeric Rhizomes', 'Add a pinch in curries for color and medicinal properties.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.6, 95, 
  '{"Curcumin": "3.5%"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000060', 'Catch Coriander Powder', 'SKU-KIRY-CORI-060', 'Kiryana', 42.00, 38.00, 100, 
  'Freshly ground dry coriander seeds for warm curry aroma.', 'Catch', '200g', 'Packet', false, '18 Months', 
  ARRAY['coriander', 'dhaniya', 'spices', 'kiryana'], 'Ground Coriander Seeds', 'Add to curries during frying.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.3, 75, 
  null, true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000061', 'Tata Sampann Kabuli Chana', 'SKU-KIRY-CHNA-061', 'Kiryana', 145.00, 138.00, 90, 
  'Selected big-sized white chickpeas, rich in protein and fiber.', 'Tata', '1kg', 'Packet', false, '12 Months', 
  ARRAY['chana', 'chickpeas', 'pulses', 'kiryana'], 'Cleaned Kabuli Chana Grains', 'Soak overnight, pressure cook and prepare spicy chole.', 
  'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500', 4.7, 195, 
  '{"Energy": "360 kcal", "Protein": "19g", "Dietary Fiber": "12g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000062', 'Fortune Refined Soyabean Oil', 'SKU-KIRY-OILS-062', 'Kiryana', 155.00, 148.00, 110, 
  'Light and healthy refined soyabean oil for daily frying.', 'Fortune', '1L', 'Pouch', false, '12 Months', 
  ARRAY['oil', 'soyabean', 'cooking', 'essential'], 'Refined Soyabean Oil, Vitamin A, Vitamin D', 'Use as standard medium for frying or baking.', 
  'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500', 4.5, 140, 
  '{"Energy": "900 kcal", "Saturated Fat": "16g"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000063', 'Catch Red Chilli Powder', 'SKU-KIRY-CHIL-063', 'Kiryana', 48.00, 44.00, 120, 
  'Hot ground red chillies for fiery color and taste.', 'Catch', '100g', 'Packet', false, '18 Months', 
  ARRAY['chilli', 'spices', 'spicy', 'essential'], 'Ground Dried Red Chillies', 'Add in small amounts to curries.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.4, 85, 
  '{"Capsaicin": "High"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000064', 'Maggi Masala-Ae-Magic', 'SKU-KIRY-MAEG-064', 'Kiryana', 60.00, 57.00, 300, 
  'Spice mix strip containing 10 sachets for ultimate curry enhancement.', 'Nestle', '60g', 'Strip', true, '12 Months', 
  ARRAY['masala', 'maggi', 'spices', 'instant'], 'Spices Blend, Iodized Salt, Flavor Enhancers', 'Tear sachet and sprinkle in cooked vegetable dishes.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.9, 580, 
  '{"Energy": "16 kcal", "Sodium": "450mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000065', 'Tata Sampann Rajma Red', 'SKU-KIRY-RAJM-065', 'Kiryana', 150.00, 144.00, 85, 
  'Unpolished red kidney beans sourced from best fields.', 'Tata', '1kg', 'Packet', false, '12 Months', 
  ARRAY['rajma', 'beans', 'pulses', 'kiryana'], 'Selected Red Kidney Beans', 'Soak overnight, cook with onion-tomato masala gravy.', 
  'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500', 4.6, 210, 
  '{"Energy": "333 kcal", "Protein": "23g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000066', 'MTR Garam Masala 100g', 'SKU-KIRY-GARM-066', 'Kiryana', 75.00, 70.00, 100, 
  'Classic aromatic hot Indian spice blend for dynamic flavoring.', 'MTR', '100g', 'Box', false, '12 Months', 
  ARRAY['garam-masala', 'spices', 'mtr', 'essential'], 'Cardamom, Cinnamon, Cloves, Cumin, Pepper', 'Add a teaspoon near the end of cooking.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.5, 115, 
  null, true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000067', 'Organic Premium Suji', 'SKU-KIRY-SUJI-067', 'Kiryana', 45.00, 42.00, 120, 
  'Fine granulated wheat semolina for halwa, upma or idlis.', 'Organic India', '500g', 'Packet', false, '9 Months', 
  ARRAY['suji', 'semolina', 'flour', 'kiryana'], 'Granulated Semolina Grains', 'Roast suji and boil with milk/water for upma or sweet halwa.', 
  'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500', 4.4, 90, 
  '{"Energy": "360 kcal", "Protein": "12g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000068', 'Everest Hing (Asafoetida)', 'SKU-KIRY-HING-068', 'Kiryana', 55.00, 52.00, 150, 
  'Strong compound asafoetida powder for digestive curry seasoning.', 'Everest', '50g', 'Jar', false, '24 Months', 
  ARRAY['hing', 'asafoetida', 'spices', 'digestive'], 'Wheat Flour, Asafoetida Gum', 'Add a pinch in hot oil/ghee during tadka preparation.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.7, 130, 
  null, true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000069', 'Catch Cumin Seeds (Jeera)', 'SKU-KIRY-JEER-069', 'Kiryana', 68.00, 64.00, 110, 
  'Handpicked clean aromatic cumin seeds for daily tempering.', 'Catch', '100g', 'Packet', false, '18 Months', 
  ARRAY['jeera', 'cumin', 'seeds', 'spices'], '100% Selected Cumin Seeds', 'Add to hot tempering medium.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.6, 175, 
  null, true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000070', 'Everest Sabji Masala', 'SKU-KIRY-SABJ-070', 'Kiryana', 58.00, 54.00, 130, 
  'Specially formulated curry powder to make standard vegetable dishes delicious.', 'Everest', '100g', 'Box', false, '12 Months', 
  ARRAY['sabji-masala', 'spices', 'everest', 'cooking'], 'Spices Blend (Turmeric, Chilli, Ginger, Nutmeg)', 'Add 2 teaspoons while cooking vegetables.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.5, 230, 
  null, true, 'packet'
),

-- Dairy Additions (15 items)
(
  'a0000000-0000-0000-0000-000000000071', 'Amul Taaza Milk 1L Tetra', 'SKU-DAIRY-AMUL-071', 'Dairy', 72.00, 70.00, 200, 
  'UHT treated long shelf life toned milk carton, ready to drink.', 'Amul', '1L', 'Carton', true, '180 Days', 
  ARRAY['milk', 'uht-milk', 'dairy', 'amul'], 'Standardised Homogenized Milk', 'Directly consume or boil as needed. Refrigerate after opening.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.8, 540, 
  '{"Energy": "58 kcal", "Total Fat": "3.1g", "Protein": "3.2g"}', true, 'carton'
),
(
  'a0000000-0000-0000-0000-000000000072', 'Amul Masti Spiced Chaas', 'SKU-DAIRY-CHAS-072', 'Dairy', 15.00, 14.50, 250, 
  'Chilled delicious spiced buttermilk pouch for hot summer afternoons.', 'Amul', '200ml', 'Packet', true, '5 Days', 
  ARRAY['chaas', 'buttermilk', 'amul', 'digestive'], 'Buttermilk, Salt, Spices Mix', 'Serve chilled, shake pouch before opening.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.7, 610, 
  '{"Energy": "25 kcal", "Sodium": "240mg"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000073', 'Amul Sweet Lassi Cup', 'SKU-DAIRY-LASS-073', 'Dairy', 25.00, 24.00, 180, 
  'Deliciously sweet thick set traditional Punjabi lassi in cup.', 'Amul', '200ml', 'Cup', false, '10 Days', 
  ARRAY['lassi', 'sweet-lassi', 'amul', 'dairy'], 'Standardised Milk, Sugar, Lactic Culture', 'Consume ice cold directly from cup.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.6, 290, 
  '{"Energy": "150 kcal", "Sugars": "22g", "Protein": "3g"}', true, 'cup'
),
(
  'a0000000-0000-0000-0000-000000000074', 'Mother Dairy Cheese Spread', 'SKU-DAIRY-SPREAD-074', 'Dairy', 95.00, 90.00, 80, 
  'Creamy plain cheese spread tub, easy to apply on toasts and rolls.', 'Mother Dairy', '200g', 'Tub', false, '120 Days', 
  ARRAY['cheese-spread', 'cheese', 'mother-dairy', 'spread'], 'Cheddar Cheese, Milk Solids, Emulsifying Salts', 'Spread on bread, roti or use as dip.', 
  'https://images.unsplash.com/photo-1528287942911-41584a371cee?w=500', 4.4, 115, 
  '{"Energy": "250 kcal", "Total Fat": "20g", "Protein": "10g"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000075', 'Amul Cow Milk Pouch', 'SKU-DAIRY-COW-075', 'Dairy', 28.00, 27.50, 150, 
  'Fresh pasteurized cow milk pouch, rich in natural vitamins.', 'Amul', '500ml', 'Packet', false, '2 Days', 
  ARRAY['cow-milk', 'fresh-milk', 'amul', 'dairy'], 'Pasteurized Cow Milk Grains', 'Boil before drinking. Refrigerate.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.6, 280, 
  '{"Energy": "62 kcal", "Total Fat": "3.5g", "Protein": "3.1g"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000076', 'Mother Dairy Probiotic Curd', 'SKU-DAIRY-CURD-076', 'Dairy', 50.00, 47.00, 100, 
  'Formulated probiotic set curd with extra active cultures for immunity.', 'Mother Dairy', '400g', 'Cup', true, '7 Days', 
  ARRAY['curd', 'dahi', 'probiotic', 'immunity'], 'Pasteurized Standardised Milk, BB-12 Culture', 'Consume with lunch or dinners.', 
  'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500', 4.7, 195, 
  '{"Energy": "60 kcal", "Calcium": "150mg"}', true, 'cup'
),
(
  'a0000000-0000-0000-0000-000000000077', 'Amul Mozzarella Cheese', 'SKU-DAIRY-MOZZ-077', 'Dairy', 135.00, 128.00, 60, 
  'Pizza cheese block with excellent melt and stretch dynamics.', 'Amul', '200g', 'Packet', false, '90 Days', 
  ARRAY['mozzarella', 'cheese-block', 'pizza-cheese', 'amul'], 'Mozzarella Cheese, Milk Solids, Salt', 'Grate over pizza base and bake.', 
  'https://images.unsplash.com/photo-1528287942911-41584a371cee?w=500', 4.5, 230, 
  '{"Energy": "290 kcal", "Total Fat": "22g", "Protein": "21g"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000078', 'Amul Garlic & Herbs Butter', 'SKU-DAIRY-GBUT-078', 'Dairy', 65.00, 62.00, 90, 
  'Delicious garlic and fine herb butter block for garlic bread.', 'Amul', '100g', 'Box', false, '180 Days', 
  ARRAY['garlic-butter', 'butter', 'amul', 'seasoning'], 'Milk Fat, Dehydrated Garlic, Oregano, Salt', 'Spread on sliced baguette and toast.', 
  'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500', 4.6, 175, 
  '{"Energy": "718 kcal", "Total Fat": "79g"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000079', 'Nestle Milkmaid Sweetened', 'SKU-DAIRY-MMAI-079', 'Dairy', 145.00, 138.00, 50, 
  'Rich sweetened condensed milk tin for instant desserts and cakes.', 'Nestle', '400g', 'Tin', false, '12 Months', 
  ARRAY['condensed-milk', 'milkmaid', 'sweet', 'nestle'], 'Milk Solids, Sugar', 'Pour into milk pudding, kheer or cake batters.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.8, 410, 
  '{"Energy": "325 kcal", "Sugars": "55g", "Protein": "8g"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000080', 'Amul Chocolate Milkshake', 'SKU-DAIRY-CSHK-080', 'Dairy', 40.00, 38.00, 120, 
  'Yummy rich chocolate flavored milk beverage in a can.', 'Amul', '200ml', 'Can', false, '6 Months', 
  ARRAY['milkshake', 'chocolate-drink', 'amul', 'beverage'], 'Standardised Milk, Cocoa Powder, Sugar', 'Shake well, drink cold.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.5, 310, 
  '{"Energy": "190 kcal", "Sugars": "18g", "Protein": "5g"}', true, 'can'
),
(
  'a0000000-0000-0000-0000-000000000081', 'Amul Whipping Cream', 'SKU-DAIRY-WCRE-081', 'Dairy', 120.00, 115.00, 40, 
  'High-fat whipping cream for cake frosting and dessert decoration.', 'Amul', '250ml', 'Carton', false, '120 Days', 
  ARRAY['whipping-cream', 'cream', 'amul', 'baking'], 'Cream Milk Fat 30%', 'Chill cream overnight, beat until soft peaks form.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.4, 90, 
  '{"Energy": "290 kcal", "Total Fat": "30g"}', true, 'carton'
),
(
  'a0000000-0000-0000-0000-000000000082', 'Epigamia Strawberry Yogurt', 'SKU-DAIRY-YOGU-082', 'Dairy', 45.00, 42.00, 80, 
  'Creamy Greek yogurt cup with real strawberry fruit pulp.', 'Epigamia', '90g', 'Cup', false, '15 Days', 
  ARRAY['yogurt', 'greek-yogurt', 'strawberry', 'epigamia'], 'Toned Milk, Strawberry Fruit Preparation, Cultures', 'Consume directly as healthy dessert.', 
  'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500', 4.5, 140, 
  '{"Energy": "98 kcal", "Protein": "6g", "Sugars": "10g"}', true, 'cup'
),
(
  'a0000000-0000-0000-0000-000000000083', 'Nandini GoodLife Milk', 'SKU-DAIRY-NAND-083', 'Dairy', 28.00, 27.00, 150, 
  'Fresh UHT treated toned milk pouch with 90 days shelf life.', 'Nandini', '500ml', 'Pouch', false, '90 Days', 
  ARRAY['milk', 'uht-milk', 'nandini', 'dairy'], 'Standardised Homogenized Milk', 'Drink directly or boil. Store in dry place.', 
  'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500', 4.6, 190, 
  '{"Energy": "58 kcal", "Total Fat": "3g"}', true, 'packet'
),
(
  'a0000000-0000-0000-0000-000000000084', 'Yakult Light Probiotic', 'SKU-DAIRY-YAKL-084', 'Dairy', 90.00, 85.00, 60, 
  'Probiotic milk drink pack with less sugar and added Vitamin D.', 'Yakult', '5 Pcs', 'Pack', false, '40 Days', 
  ARRAY['probiotic', 'yakult-light', 'healthy', 'dietary'], 'Water, Skimmed Milk Powder, Stevia, Lactobacillus Cultures', 'Drink 1 bottle cold daily.', 
  'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?w=500', 4.6, 85, 
  '{"Energy": "25 kcal", "Sugars": "5g"}', true, 'pack'
),
(
  'a0000000-0000-0000-0000-000000000085', 'Amul Gouda Cheese Block', 'SKU-DAIRY-GOUD-085', 'Dairy', 170.00, 162.00, 45, 
  'Premium Gouda cheese block, rich and aromatic table cheese.', 'Amul', '200g', 'Packet', false, '120 Days', 
  ARRAY['gouda-cheese', 'cheese', 'amul', 'premium'], 'Pasteurized Milk, Cultures, Salt', 'Slice and consume with crackers or fruits.', 
  'https://images.unsplash.com/photo-1528287942911-41584a371cee?w=500', 4.7, 105, 
  '{"Energy": "356 kcal", "Total Fat": "27g", "Protein": "25g"}', true, 'packet'
),

-- Mandi Fresh Produce (15 items)
(
  'a0000000-0000-0000-0000-000000000086', 'Green Cauliflower (Gobhi)', 'SKU-MANDI-GOBH-086', 'Vegetables', 40.00, 35.00, 80, 
  'Crispy farm cauliflower head with fresh green leaves.', 'Local Farm', '1 Unit', 'Crate', false, '5 Days', 
  ARRAY['cauliflower', 'gobhi', 'vegetables', 'mandi'], 'Fresh Cauliflower Head', 'Cut florets, rinse and cook.', 
  'https://images.unsplash.com/photo-1568584711271-6c9aa9dc6063?w=500', 4.4, 110, 
  '{"Energy": "25 kcal", "Vitamin C": "80%"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000087', 'Fresh Lady Finger (Bhindi)', 'SKU-MANDI-BHIN-087', 'Vegetables', 50.00, 45.00, 90, 
  'Tender green okra pods directly harvested from local farms.', 'Local Farm', '1kg', 'Bag', true, '4 Days', 
  ARRAY['lady-finger', 'bhindi', 'okra', 'vegetables'], 'Fresh Green Okra Grains', 'Wash, dry completely, slice and stir fry.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.5, 140, 
  '{"Energy": "33 kcal", "Dietary Fiber": "3.2g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000088', 'Fresh Green Beans', 'SKU-MANDI-BEAN-088', 'Vegetables', 60.00, 55.00, 70, 
  'Crispy organic green pods rich in plant protein and dietary fibers.', 'Local Farm', '500g', 'Packet', false, '6 Days', 
  ARRAY['beans', 'green-beans', 'vegetables', 'fresh'], '100% Organic Green Beans', 'Snap ends, chop and steam or stir-fry.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.3, 65, 
  '{"Energy": "31 kcal", "Protein": "1.8g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000089', 'Local Ginger (Adrak)', 'SKU-MANDI-GING-089', 'Vegetables', 80.00, 75.00, 50, 
  'Spicy pungent farm-fresh ginger root for tea and cooking.', 'Local Farm', '250g', 'Bag', false, '15 Days', 
  ARRAY['ginger', 'adrak', 'spices', 'tea-addon'], 'Fresh Ginger Root', 'Peel and grate into hot boiling tea or curry base.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.6, 125, 
  null, true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000090', 'Fresh Garlic (Lahsun)', 'SKU-MANDI-GARL-090', 'Vegetables', 90.00, 85.00, 60, 
  'Selected white garlic bulbs with strong aromatic cloves.', 'Local Farm', '250g', 'Bag', false, '30 Days', 
  ARRAY['garlic', 'lahsun', 'aromatic', 'spices'], 'Selected White Garlic Bulbs', 'Peel cloves, crush or mince and add to hot oil.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.7, 190, 
  null, true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000091', 'Green Chillies (Hari Mirch)', 'SKU-MANDI-GMIR-091', 'Vegetables', 30.00, 25.00, 80, 
  'Fiery hot slim green chillies, essential spice kick.', 'Local Farm', '250g', 'Packet', false, '7 Days', 
  ARRAY['green-chilli', 'mirch', 'spices', 'hot'], 'Fresh Green Chillies', 'Chop and add to dishes for hot tempering.', 
  'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500', 4.5, 310, 
  '{"Vitamin C": "240%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000092', 'Sweet Green Grapes', 'SKU-MANDI-GRAP-092', 'Fruits', 90.00, 85.00, 65, 
  'Juicy seedless green grapes directly procured from Nashik vineyards.', 'Nashik Farms', '500g', 'Crate', true, '5 Days', 
  ARRAY['grapes', 'fruits', 'seedless', 'sweet'], 'Premium Seedless Green Grapes', 'Wash thoroughly in saline water and consume.', 
  'https://images.unsplash.com/photo-1537084642907-629340c7e59c?w=500', 4.5, 140, 
  '{"Energy": "67 kcal", "Sugars": "16g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000093', 'Fresh Papaya (Papeeta)', 'SKU-MANDI-PAPA-093', 'Fruits', 50.00, 45.00, 75, 
  'Sweet yellow pulpy local papaya, excellent digestant fruit.', 'Local Farm', '1 Unit', 'Crate', false, '5 Days', 
  ARRAY['papaya', 'papeeta', 'fruits', 'digestive'], 'Fresh Yellow Papaya Grains', 'Cut, remove black seeds, slice and serve.', 
  'https://images.unsplash.com/photo-1610832958506-ee5633613ab2?w=500', 4.4, 95, 
  '{"Energy": "43 kcal", "Vitamin C": "70mg"}', true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000094', 'Nagpur Sweet Oranges', 'SKU-MANDI-ORAN-094', 'Fruits', 80.00, 75.00, 100, 
  'Juicy citrus oranges rich in natural Vitamin C and fiber.', 'Nagpur Orchards', '1kg', 'Bag', false, '10 Days', 
  ARRAY['orange', 'citrus', 'fruits', 'nagpur'], 'Nagpur Sweet Oranges', 'Peel and consume segments or squeeze for fresh juice.', 
  'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?w=500', 4.6, 210, 
  '{"Energy": "47 kcal", "Vitamin C": "88%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000095', 'Sweet Pomegranate (Anar)', 'SKU-MANDI-POME-095', 'Fruits', 140.00, 130.00, 50, 
  'Premium red sweet pomegranate filled with juicy ruby seeds.', 'Local Farm', '1kg', 'Box', true, '15 Days', 
  ARRAY['pomegranate', 'anar', 'fruits', 'blood-booster'], 'Selected Red Pomegranates', 'Cut outer skin, peel and consume ruby arils.', 
  'https://images.unsplash.com/photo-1595855759920-86582396756a?w=500', 4.7, 185, 
  '{"Energy": "83 kcal", "Iron": "4%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000096', 'Fresh Green Coriander', 'SKU-MANDI-CORL-096', 'Vegetables', 15.00, 12.00, 120, 
  'Aromatic fresh leafy green coriander bunch for kitchen garnishing.', 'Local Farm', '1 Bunch', 'Bundle', false, '2 Days', 
  ARRAY['coriander', 'dhaniya-leaves', 'leafy', 'aromatic'], 'Fresh Green Coriander Leaves', 'Wash thoroughly and chop for garnishing.', 
  'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=500', 4.8, 340, 
  null, true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000097', 'Fresh Mint Leaves (Pudina)', 'SKU-MANDI-MINT-097', 'Vegetables', 15.00, 12.00, 100, 
  'Cool aromatic fresh mint leaves bunch, perfect for chutneys.', 'Local Farm', '1 Bunch', 'Bundle', false, '3 Days', 
  ARRAY['mint', 'pudina', 'leafy', 'chutney'], 'Fresh Organic Mint Leaves', 'Wash leaves and crush for chutney or tea.', 
  'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=500', 4.6, 190, 
  null, true, 'piece'
),
(
  'a0000000-0000-0000-0000-000000000098', 'Fresh Green Peas (Matar)', 'SKU-MANDI-PEAS-098', 'Vegetables', 80.00, 74.00, 80, 
  'Sweet green peas pods harvested daily, fresh and tender.', 'Local Farm', '1kg', 'Bag', false, '5 Days', 
  ARRAY['peas', 'matar', 'vegetables', 'fresh'], 'Sweet Green Peas Pods', 'Shell peas from pods, wash and add to recipes.', 
  'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=500', 4.5, 110, 
  '{"Energy": "81 kcal", "Protein": "5.4g"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000099', 'Fresh Local Carrots', 'SKU-MANDI-CARR-099', 'Vegetables', 40.00, 36.00, 100, 
  'Sweet crunchy orange country carrots rich in Vitamin A.', 'Local Farm', '1kg', 'Bag', false, '7 Days', 
  ARRAY['carrot', 'gajar', 'vegetables', 'healthy'], 'Selected Sweet Country Carrots', 'Wash, peel and slice for salad or cook.', 
  'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=500', 4.7, 160, 
  '{"Energy": "41 kcal", "Vitamin A": "330%"}', true, 'kg'
),
(
  'a0000000-0000-0000-0000-000000000100', 'Sweet Ripe Mangoes (Safeda)', 'SKU-MANDI-MANR-100', 'Fruits', 120.00, 115.00, 150, 
  'Deliciously sweet yellow ripe Safeda mangoes sourced from orchards.', 'Local Orchards', '1kg', 'Crate', true, '4 Days', 
  ARRAY['mango', 'sweet-mango', 'fruits', 'seasonal'], 'Premium Safeda Mangoes', 'Wash skin, peel, slice and enjoy.', 
  'https://images.unsplash.com/photo-1553279768-865429fa0078?w=500', 4.9, 650, 
  '{"Energy": "60 kcal", "Sugars": "14g", "Vitamin A": "20%"}', true, 'kg'
);
