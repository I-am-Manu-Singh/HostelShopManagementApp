import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shop.dart';
import '../../services/cart_service.dart';
import 'shop_checkout_screen.dart';

/// Fast Food Menu Item Model representing cafe dishes from menu screenshots
class FastFoodItem {
  final String id;
  final String name;
  final String category;
  final double halfPrice;
  final double fullPrice;
  final bool hasHalf;
  final String? timeSlot;

  const FastFoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.fullPrice,
    this.halfPrice = 0.0,
    this.hasHalf = false,
    this.timeSlot,
  });

  /// Convert to a ShopItem representation for cart and checkout compatibility
  ShopItem toShopItem({bool isHalf = false}) {
    final double price = isHalf && hasHalf ? halfPrice : fullPrice;
    final String portionSuffix = hasHalf ? (isHalf ? ' (Half)' : ' (Full)') : '';
    final String uniqueId = isHalf ? '${id}_half' : id;

    return ShopItem(
      id: uniqueId,
      name: '$name$portionSuffix',
      category: 'Fast Food',
      price: price,
      stockQuantity: 999, // Prepared fresh on order
      isAvailable: true,
      unit: hasHalf ? (isHalf ? 'half' : 'full') : 'plate',
      description: 'Cafe Food Junction freshly prepared $name. Delicious taste and hygienic preparation.',
      isMandi: false,
    );
  }
}

/// Catalog extracted directly from the user's "The Cafe Food" & "Cafe Food Junction" menu cards
const List<FastFoodItem> kFastFoodCatalog = [
  // BREAKFAST
  FastFoodItem(id: 'ff_poha', name: 'Poha', category: 'Breakfast', halfPrice: 10, fullPrice: 15, hasHalf: true, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_tea', name: 'Tea (Special Chai)', category: 'Breakfast', halfPrice: 5, fullPrice: 10, hasHalf: true, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_samosa', name: 'Samosa with Chutney', category: 'Breakfast', fullPrice: 10, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_kachori', name: 'Kachori with Chutney / Sauce', category: 'Breakfast', fullPrice: 10, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_hot_coffee', name: 'Hot Coffee', category: 'Breakfast', halfPrice: 10, fullPrice: 15, hasHalf: true, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_bread_pakoda', name: 'Bread Pakoda', category: 'Breakfast', fullPrice: 15, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_plain_parantha', name: 'Plain Parantha with Sabzi', category: 'Breakfast', fullPrice: 25, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_pyaaz_parantha', name: 'Pyaaz Parantha with Achar', category: 'Breakfast', fullPrice: 20, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_aloo_parantha', name: 'Aloo Parantha with Achar', category: 'Breakfast', fullPrice: 20, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_paneer_parantha', name: 'Paneer Parantha', category: 'Breakfast', fullPrice: 30, timeSlot: '7:30 AM - 11:45 AM'),
  FastFoodItem(id: 'ff_pastry', name: 'Fresh Cream Pastry', category: 'Breakfast', halfPrice: 10, fullPrice: 15, hasHalf: true),

  // BURGERS
  FastFoodItem(id: 'ff_aloo_tikki_burger', name: 'Aloo Tikki Burger', category: 'Burgers', fullPrice: 25),
  FastFoodItem(id: 'ff_masala_burger', name: 'Masala Burger', category: 'Burgers', fullPrice: 30),
  FastFoodItem(id: 'ff_paneer_burger', name: 'Paneer Burger', category: 'Burgers', fullPrice: 40),
  FastFoodItem(id: 'ff_tandoori_burger', name: 'Tandoori Burger', category: 'Burgers', fullPrice: 40),
  FastFoodItem(id: 'ff_cheese_burger', name: 'Cheese Burger', category: 'Burgers', fullPrice: 40),
  FastFoodItem(id: 'ff_double_cheese_burger', name: 'Double Cheese Burger', category: 'Burgers', fullPrice: 50),

  // MAGGI
  FastFoodItem(id: 'ff_masala_maggi', name: 'Masala Maggi', category: 'Maggi', halfPrice: 25, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_cheese_maggi', name: 'Cheese Maggi', category: 'Maggi', halfPrice: 35, fullPrice: 70, hasHalf: true),
  FastFoodItem(id: 'ff_paneer_maggi', name: 'Paneer Maggi', category: 'Maggi', halfPrice: 30, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_tandoori_cheese_maggi', name: 'Tandoori Cheese Maggi', category: 'Maggi', halfPrice: 40, fullPrice: 80, hasHalf: true),
  FastFoodItem(id: 'ff_punjabi_tadka_maggi', name: 'Punjabi Tadka Maggi', category: 'Maggi', halfPrice: 40, fullPrice: 80, hasHalf: true),

  // PASTA
  FastFoodItem(id: 'ff_masala_pasta', name: 'Masala Pasta', category: 'Pasta', halfPrice: 25, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_white_cheese_pasta', name: 'White Cheese Pasta', category: 'Pasta', halfPrice: 30, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_red_cheese_pasta', name: 'Red Cheese Pasta', category: 'Pasta', halfPrice: 30, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_paneer_pasta', name: 'Paneer Pasta', category: 'Pasta', halfPrice: 40, fullPrice: 80, hasHalf: true),

  // SANDWICH & GARLIC BREAD
  FastFoodItem(id: 'ff_aloo_sandwich', name: 'Aloo Sandwich', category: 'Sandwich', halfPrice: 20, fullPrice: 30, hasHalf: true),
  FastFoodItem(id: 'ff_veg_masala_sandwich', name: 'Veg Masala Sandwich', category: 'Sandwich', halfPrice: 20, fullPrice: 30, hasHalf: true),
  FastFoodItem(id: 'ff_cheese_sandwich', name: 'Cheese Sandwich', category: 'Sandwich', halfPrice: 30, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_paneer_sandwich', name: 'Paneer Sandwich', category: 'Sandwich', halfPrice: 30, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_tandoori_sandwich', name: 'Tandoori Sandwich', category: 'Sandwich', halfPrice: 30, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_garlic_bread', name: 'Garlic Bread', category: 'Sandwich', halfPrice: 50, fullPrice: 90, hasHalf: true),

  // PATTIES
  FastFoodItem(id: 'ff_aloo_patties', name: 'Aloo Patties', category: 'Patties', fullPrice: 15),
  FastFoodItem(id: 'ff_masala_patties', name: 'Masala Patties', category: 'Patties', fullPrice: 20),
  FastFoodItem(id: 'ff_cheese_patties', name: 'Cheese Patties', category: 'Patties', fullPrice: 25),
  FastFoodItem(id: 'ff_paneer_patties', name: 'Paneer Patties', category: 'Patties', fullPrice: 30),
  FastFoodItem(id: 'ff_tandoori_patties', name: 'Tandoori Patties', category: 'Patties', fullPrice: 35),
  FastFoodItem(id: 'ff_paneer_cheese_patties', name: 'Paneer Cheese Patties', category: 'Patties', fullPrice: 40),
  FastFoodItem(id: 'ff_tandoori_cheese_patties', name: 'Tandoori Cheese Patties', category: 'Patties', fullPrice: 40),

  // PIZZA
  FastFoodItem(id: 'ff_onion_pizza', name: 'Onion Pizza', category: 'Pizza', fullPrice: 80),
  FastFoodItem(id: 'ff_margherita_pizza', name: 'Margherita Pizza', category: 'Pizza', fullPrice: 90),
  FastFoodItem(id: 'ff_onion_capsicum_pizza', name: 'Onion Capsicum Pizza', category: 'Pizza', fullPrice: 100),
  FastFoodItem(id: 'ff_paneer_burst_pizza', name: 'Paneer Burst Pizza', category: 'Pizza', fullPrice: 110),
  FastFoodItem(id: 'ff_hot_pepper_pizza', name: 'Hot Pepper Pizza', category: 'Pizza', fullPrice: 110),
  FastFoodItem(id: 'ff_cheese_burst_pizza', name: 'Cheese Burst Pizza', category: 'Pizza', fullPrice: 120),
  FastFoodItem(id: 'ff_double_cheese_pizza', name: 'Double Cheese Pizza', category: 'Pizza', fullPrice: 140),

  // ROLLS
  FastFoodItem(id: 'ff_veg_roll', name: 'Veg Roll', category: 'Rolls', halfPrice: 15, fullPrice: 30, hasHalf: true),
  FastFoodItem(id: 'ff_veg_paneer_roll', name: 'Veg Paneer Roll', category: 'Rolls', halfPrice: 20, fullPrice: 40, hasHalf: true),
  FastFoodItem(id: 'ff_veg_cheese_paneer_roll', name: 'Veg Cheese Paneer Roll', category: 'Rolls', halfPrice: 40, fullPrice: 70, hasHalf: true),
  FastFoodItem(id: 'ff_fried_spring_roll', name: 'Fried Spring Roll', category: 'Rolls', halfPrice: 25, fullPrice: 40, hasHalf: true),

  // MOMOS
  FastFoodItem(id: 'ff_steam_momos', name: 'Steam Momos', category: 'Momos', halfPrice: 20, fullPrice: 40, hasHalf: true),
  FastFoodItem(id: 'ff_fried_momos', name: 'Fried Momos', category: 'Momos', halfPrice: 25, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_chinese_momos', name: 'Chinese Momos', category: 'Momos', halfPrice: 35, fullPrice: 70, hasHalf: true),
  FastFoodItem(id: 'ff_tandoori_momos', name: 'Tandoori Momos', category: 'Momos', halfPrice: 40, fullPrice: 80, hasHalf: true),
  FastFoodItem(id: 'ff_paneer_momos', name: 'Paneer Momos', category: 'Momos', halfPrice: 40, fullPrice: 80, hasHalf: true),

  // SHAKES, JUICES & BEVERAGES
  FastFoodItem(id: 'ff_mango_shake', name: 'Mango Shake', category: 'Shakes & Juices', halfPrice: 40, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_banana_shake', name: 'Banana Shake', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 40, hasHalf: true),
  FastFoodItem(id: 'ff_papita_shake', name: 'Papita Shake', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 40, hasHalf: true),
  FastFoodItem(id: 'ff_strawberry_shake', name: 'Strawberry Flavoured Shake', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_chocolate_shake', name: 'Chocolate Shake', category: 'Shakes & Juices', halfPrice: 40, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_cold_coffee', name: 'Cold Coffee', category: 'Shakes & Juices', halfPrice: 40, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_black_current', name: 'Black Current Shake', category: 'Shakes & Juices', halfPrice: 40, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_pineapple_juice', name: 'Pineapple Juice', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 40, hasHalf: true),
  FastFoodItem(id: 'ff_mosambi_juice', name: 'Mosambi Juice', category: 'Shakes & Juices', halfPrice: 40, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_vanilla_shake', name: 'Vanilla Shake', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_kitkat_shake', name: 'Kit Kat Shake', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 60, hasHalf: true),
  FastFoodItem(id: 'ff_oreo_shake', name: 'Oreo Shake', category: 'Shakes & Juices', halfPrice: 30, fullPrice: 60, hasHalf: true),

  // CHINESE & RICE
  FastFoodItem(id: 'ff_veg_fried_rice', name: 'Veg Fried Rice', category: 'Chinese & Meals', halfPrice: 40, fullPrice: 80, hasHalf: true),
  FastFoodItem(id: 'ff_paneer_fried_rice', name: 'Paneer Fried Rice', category: 'Chinese & Meals', halfPrice: 50, fullPrice: 100, hasHalf: true),
  FastFoodItem(id: 'ff_manchurian_rice', name: 'Paneer Manchurian Rice', category: 'Chinese & Meals', halfPrice: 60, fullPrice: 120, hasHalf: true),
  FastFoodItem(id: 'ff_veg_chowmein', name: 'Veg Chowmein', category: 'Chinese & Meals', halfPrice: 30, fullPrice: 50, hasHalf: true),
  FastFoodItem(id: 'ff_haka_noodles', name: 'Hakka Noodles', category: 'Chinese & Meals', halfPrice: 40, fullPrice: 70, hasHalf: true),
  FastFoodItem(id: 'ff_chilli_paneer_dry', name: 'Chilli Paneer (Dry)', category: 'Chinese & Meals', halfPrice: 50, fullPrice: 100, hasHalf: true),
  FastFoodItem(id: 'ff_chilli_paneer_gravy', name: 'Chilli Paneer (Gravy)', category: 'Chinese & Meals', halfPrice: 60, fullPrice: 120, hasHalf: true),
  FastFoodItem(id: 'ff_manchurian_dry', name: 'Veg Manchurian (Dry)', category: 'Chinese & Meals', halfPrice: 30, fullPrice: 60, hasHalf: true),

  // THALI & CANTEEN MEALS
  FastFoodItem(id: 'ff_lunch_thali', name: 'Special Lunch Thali', category: 'Thali & Meals', fullPrice: 70, timeSlot: '12:30 PM - 2:00 PM'),
  FastFoodItem(id: 'ff_dinner_thali', name: 'Special Dinner Thali', category: 'Thali & Meals', fullPrice: 70, timeSlot: '8:00 PM - 9:30 PM'),
];

class FastFoodScreen extends StatefulWidget {
  const FastFoodScreen({super.key});

  @override
  State<FastFoodScreen> createState() => _FastFoodScreenState();
}

class _FastFoodScreenState extends State<FastFoodScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<FastFoodItem> _items = kFastFoodCatalog;

  List<String> get _categories {
    final Set<String> cats = {'All'};
    for (final it in _items) {
      if (it.category.isNotEmpty) cats.add(it.category);
    }
    return cats.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final res = await Supabase.instance.client
          .from('shop_items')
          .select()
          .ilike('category', '%fast food%');
      final list = res as List;
      if (list.isNotEmpty) {
        final List<FastFoodItem> dbItems = list.map((row) {
          final name = row['name']?.toString() ?? 'Fast Food Item';
          final subCat = row['brand'] ?? 'Breakfast';
          final price = (row['price'] as num?)?.toDouble() ?? 30.0;
          final cost = (row['cost_price'] as num?)?.toDouble() ?? (price * 0.6);
          final desc = row['description']?.toString() ?? '';
          String? timeSlot;
          if (desc.contains('Time: ')) {
            final parts = desc.split('Time: ');
            if (parts.length > 1) {
              timeSlot = parts[1].replaceAll(')', '').trim();
            }
          }
          return FastFoodItem(
            id: row['id']?.toString() ?? 'ff_${row['barcode'] ?? name}',
            name: name,
            category: subCat,
            fullPrice: price,
            halfPrice: cost,
            hasHalf: cost > 0 && cost < price,
            timeSlot: timeSlot,
          );
        }).toList();

        if (mounted && dbItems.isNotEmpty) {
          setState(() {
            _items = dbItems;
          });
        }
      }
    } catch (_) {
      // Graceful fallback to kFastFoodCatalog
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);

    final filtered = _items.where((item) {
      final matchesCat = _selectedCategory == 'All' || item.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildCategoryFilter(isDark),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fastfood_outlined, size: 60, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 12),
                          Text("No fast food items found", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildFoodItemCard(filtered[index], isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.deepOrangeAccent, Colors.amber]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "FAST FOOD CAFE",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "The Cafe Food • Fresh & Hygienic Canteen",
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Cart Button
              Consumer<CartProvider>(
                builder: (context, cart, _) {
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.shopping_cart_outlined, color: isDark ? Colors.white : Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShopCheckoutScreen(isMandiMode: false)),
                          );
                        },
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.deepOrangeAccent, shape: BoxShape.circle),
                            child: Text(
                              "${cart.itemCount}",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search Input
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search burger, maggi, pasta, shakes...",
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
              prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.black38),
              filled: true,
              fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSel = _selectedCategory == cat;
          return ChoiceChip(
            selected: isSel,
            selectedColor: Colors.deepOrangeAccent,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            label: Text(
              cat,
              style: TextStyle(
                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onSelected: (_) => setState(() => _selectedCategory = cat),
          );
        },
      ),
    );
  }

  Widget _buildFoodItemCard(FastFoodItem item, bool isDark) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Food Category Icon Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getCategoryIcon(item.category), color: Colors.deepOrangeAccent, size: 22),
          ),
          const SizedBox(width: 12),
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (item.timeSlot != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.timeSlot!,
                          style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.hasHalf
                      ? "Half: ₹${item.halfPrice.toInt()}  •  Full: ₹${item.fullPrice.toInt()}"
                      : "Price: ₹${item.fullPrice.toInt()}",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons: If item has half/full, allow picking
          if (item.hasHalf) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(48, 30),
              ),
              onPressed: () {
                final shopItem = item.toShopItem(isHalf: true);
                cart.addItem(shopItem);
                _showAddedSnackbar(context, "${item.name} (Half)");
              },
              child: Text("Half ₹${item.halfPrice.toInt()}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(48, 30),
              ),
              onPressed: () {
                final shopItem = item.toShopItem(isHalf: false);
                cart.addItem(shopItem);
                _showAddedSnackbar(context, "${item.name} (Full)");
              },
              child: Text("Full ₹${item.fullPrice.toInt()}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 32),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: Text("₹${item.fullPrice.toInt()}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () {
                final shopItem = item.toShopItem(isHalf: false);
                cart.addItem(shopItem);
                _showAddedSnackbar(context, item.name);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showAddedSnackbar(BuildContext context, String title) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added to cart: $title"),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'burgers':
        return Icons.lunch_dining;
      case 'maggi':
        return Icons.ramen_dining;
      case 'pasta':
        return Icons.dinner_dining;
      case 'sandwich':
        return Icons.breakfast_dining;
      case 'patties':
        return Icons.bakery_dining;
      case 'pizza':
        return Icons.local_pizza;
      case 'rolls':
        return Icons.wrap_text_rounded;
      case 'momos':
        return Icons.cookie_rounded;
      case 'rolls & momos':
        return Icons.kebab_dining;
      case 'shakes & juices':
        return Icons.local_bar;
      case 'chinese & meals':
        return Icons.rice_bowl;
      case 'thali & meals':
        return Icons.set_meal;
      default:
        return Icons.fastfood;
    }
  }
}
