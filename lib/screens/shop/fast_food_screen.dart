import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shop.dart';
import '../../services/cart_service.dart';
import 'shop_checkout_screen.dart';

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

  ShopItem toShopItem({bool isHalf = false}) {
    final double price = isHalf && hasHalf ? halfPrice : fullPrice;
    final String portionSuffix = hasHalf ? (isHalf ? ' (Half)' : ' (Full)') : '';
    final String uniqueId = isHalf ? '${id}_half' : id;

    return ShopItem(
      id: uniqueId,
      name: '$name$portionSuffix',
      category: 'Fast Food',
      price: price,
      stockQuantity: 999,
      isAvailable: true,
      unit: hasHalf ? (isHalf ? 'half' : 'full') : 'plate',
      description: 'Freshly prepared $name. Delicious taste and hygienic preparation.',
      isMandi: false,
    );
  }
}

class FastFoodScreen extends StatefulWidget {
  const FastFoodScreen({super.key});

  @override
  State<FastFoodScreen> createState() => _FastFoodScreenState();
}

class _FastFoodScreenState extends State<FastFoodScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<FastFoodItem> _items = [];
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('shop_items')
          .select()
          .ilike('category', '%fast food%');
      final list = res as List;
      
      final List<FastFoodItem> dbItems = list.map((row) {
        final name = row['name']?.toString() ?? 'Fast Food Item';
        final subCat = row['brand'] ?? 'General';
        final price = (row['price'] as num?)?.toDouble() ?? 0.0;
        final cost = (row['cost_price'] as num?)?.toDouble() ?? 0.0;
        final desc = row['description']?.toString() ?? '';
        
        String? timeSlot;
        if (desc.contains('Time: ')) {
          final parts = desc.split('Time: ');
          if (parts.length > 1) {
            timeSlot = parts[1].replaceAll(')', '').trim();
          }
        }
        
        final bool hasHalfOption = cost > 0 && cost < price;

        return FastFoodItem(
          id: row['id']?.toString() ?? 'ff_${row['barcode'] ?? name}',
          name: name,
          category: subCat.toString().isEmpty ? 'General' : subCat.toString(),
          fullPrice: price,
          halfPrice: cost,
          hasHalf: hasHalfOption,
          timeSlot: timeSlot,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _items = dbItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching fast food items: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            if (!_isLoading && _items.isNotEmpty) _buildCategoryFilter(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
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
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
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
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getCategoryIcon(item.category), color: Colors.deepOrangeAccent, size: 22),
          ),
          const SizedBox(width: 12),
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
                          color: Colors.amber.withOpacity(0.15),
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