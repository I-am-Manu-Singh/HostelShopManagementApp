import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cart_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/shop.dart';
import '../../services/placeholder_service.dart';
import 'product_detail_screen.dart';
import 'shop_order_status_screen.dart';
import 'shop_checkout_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_of_service_screen.dart';
import '../profile/app_info_screen.dart';
import 'fast_food_screen.dart';
import '../../services/organization_settings_service.dart';
enum BrowseMode { shop, mandi, fastFood }


class ShopBrowseScreen extends StatefulWidget {
  final bool isMandiMode;
  const ShopBrowseScreen({super.key, this.isMandiMode = false});

  @override
  State<ShopBrowseScreen> createState() => _ShopBrowseScreenState();
}

class _ShopBrowseScreenState extends State<ShopBrowseScreen> {
  final _supabase = Supabase.instance.client;

  late BrowseMode _currentMode;
  String _dietFilter = 'ALL';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Popularity';
  bool _isLoading = true;
  bool _onlyInStock = false;

  List<ShopItem> _items = [];
  Map<String, dynamic>? _profile;
  int _activeOrdersCount = 0;
  Set<String> _wishlistIds = {};
  double _deliveryFee = 20.0;

  List<Map<String, dynamic>> get _categories {
    final Set<String> uniqueCats = {};

    for (var item in _items) {
      if (_currentMode == BrowseMode.fastFood) {
        final displayCat = (item.brand != null &&
                item.brand!.isNotEmpty &&
                item.brand != 'Campus')
            ? item.brand!
            : item.category;
        uniqueCats.add(displayCat);
      } else {
        uniqueCats.add(item.category);
      }
    }

    final List<Map<String, dynamic>> dynamicCats = [
      {'name': 'All', 'icon': Icons.grid_view_rounded},
    ];

    for (var cat in uniqueCats) {
      if (cat == 'All') continue;
      dynamicCats.add({
        'name': cat,
        'icon': PlaceholderService.getIcon(cat),
      });
    }
    return dynamicCats;
  }

  @override
  void initState() {
    super.initState();
    _currentMode = widget.isMandiMode ? BrowseMode.mandi : BrowseMode.shop;
    Future.microtask(() => _fetchItems());
  }

  Future<void> _fetchItems({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        try {
          final List<Future<dynamic>> futures = [
            _supabase.from('profiles').select().eq('id', user.id).maybeSingle(),
            _supabase
                .from('shop_orders')
                .select('id')
                .eq('user_id', user.id)
                .inFilter('order_status', ['Placed', 'Packing', 'Ready']),
          ];

          final results = await Future.wait(futures);

          if (mounted) {
            setState(() {
              _profile = results[0] as Map<String, dynamic>? ?? {};
              _activeOrdersCount = (results[1] as List).length;
            });
          }
        } catch (e) {
          debugPrint("❌ PROFILE FETCH ERROR: $e");
        }

        try {
          final wish = await _supabase
              .from('wishlist')
              .select('product_id')
              .eq('user_id', user.id);
          if (mounted) {
            setState(() {
              _wishlistIds =
                  (wish as List).map((e) => e['product_id'].toString()).toSet();
            });
          }
        } catch (e) {
          debugPrint("❌ WISHLIST FETCH ERROR: $e");
        }
      }

      PostgrestFilterBuilder builder = _supabase.from('shop_items').select();

      if (_currentMode == BrowseMode.mandi) {
        builder = builder.eq('is_mandi', true);
      } else if (_currentMode == BrowseMode.fastFood) {
        builder = builder.ilike('category', '%fast food%');
      } else {
        builder =
            builder.eq('is_mandi', false).not('category', 'ilike', '%fast food%');
      }

      final res = await builder;
      final parsed = (res as List).map((i) => ShopItem.fromJson(i)).toList();

      if (mounted) {
        // Sync logistics rules and festival offers
        context.read<CartProvider>().fetchLogisticsAndOffers();
      }

      double fee = 20.0;
      try {
        final settings = await _supabase
            .from('app_settings')
            .select('value')
            .eq('key', 'delivery_charge')
            .maybeSingle();
        if (settings != null) {
          fee = (settings['value'] as num? ?? 20.0).toDouble();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _items = parsed;
          _deliveryFee = fee;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _items = [];
        });
      }
    }
  }

  Future<void> _refreshUserSessionState() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final List<Future<dynamic>> futures = [
        _supabase.from('profiles').select().eq('id', user.id).maybeSingle(),
        _supabase.from('wishlist').select('product_id').eq('user_id', user.id),
        _supabase
            .from('shop_orders')
            .select('id')
            .eq('user_id', user.id)
            .inFilter('order_status', ['Placed', 'Packing', 'Ready']),
      ];
      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>? ?? {};
          _wishlistIds =
              (results[1] as List).map((e) => e['product_id'].toString()).toSet();
          _activeOrdersCount = (results[2] as List).length;
        });
      }
    } catch (e) {
      debugPrint('Session Refresh Error: $e');
    }
  }

  bool _checkAuthorized(BuildContext context) {
    if (_supabase.auth.currentUser == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Login Required',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: const Text(
              'Please login to your account to add items to cart, manage wishlists, or proceed to checkout.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text('GO TO LOGIN',
                  style: TextStyle(
                      color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _toggleWishlist(String pid) async {
    if (!_checkAuthorized(context)) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    bool isAdding = !_wishlistIds.contains(pid);
    try {
      if (isAdding) {
        await _supabase
            .from('wishlist')
            .insert({'user_id': user.id, 'product_id': pid});
        if (mounted) setState(() => _wishlistIds = {..._wishlistIds, pid});
      } else {
        await _supabase
            .from('wishlist')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', pid);
        if (mounted) setState(() => _wishlistIds = {..._wishlistIds}..remove(pid));
      }
    } catch (e) {
      debugPrint('Wishlist Toggle Error: $e');
    }
  }

  void _switchMode(BrowseMode newMode) {
    if (_currentMode == newMode) return;
    setState(() {
      _currentMode = newMode;
      _selectedCategory = 'All';
      _searchQuery = '';
      _dietFilter = 'ALL';
    });
    _fetchItems();
  }
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = Theme.of(context).scaffoldBackgroundColor;

  var filtered = _items.where((i) {
    // ------------------------------------------------------------
    // CATEGORY
    // ------------------------------------------------------------
    final effectiveCategory =
        (_currentMode == BrowseMode.fastFood &&
                i.brand != null &&
                i.brand!.isNotEmpty &&
                i.brand != 'Campus')
            ? i.brand!
            : i.category;

    final matchCat =
        _selectedCategory == 'All' ||
        effectiveCategory.toLowerCase() ==
            _selectedCategory.toLowerCase();

    // ------------------------------------------------------------
    // SEARCH
    // ------------------------------------------------------------
    final matchSearch =
        i.name.toLowerCase().contains(_searchQuery.toLowerCase());

    // ------------------------------------------------------------
    // STOCK
    // ------------------------------------------------------------
    final matchStock =
        !_onlyInStock || i.stockQuantity > 0;

    // ------------------------------------------------------------
    // DIET FILTER
    // Only applies to Fast Food mode
    // ------------------------------------------------------------
    final matchDiet =
        _currentMode != BrowseMode.fastFood ||
        _dietFilter == 'ALL' ||
        (_dietFilter == 'VEG' && !i.isNonVeg) ||
        (_dietFilter == 'NON_VEG' && i.isNonVeg);

    return matchCat &&
        matchSearch &&
        matchStock &&
        matchDiet;
  }).toList();

  // ------------------------------------------------------------
  // SORTING
  // ------------------------------------------------------------
  if (_sortBy == 'Price: Low to High') {
    filtered.sort(
      (a, b) => (a.discountPrice ?? a.price).compareTo(
        b.discountPrice ?? b.price,
      ),
    );
  } else if (_sortBy == 'Price: High to Low') {
    filtered.sort(
      (a, b) => (b.discountPrice ?? b.price).compareTo(
        a.discountPrice ?? a.price,
      ),
    );
  } else if (_sortBy == 'Rating') {
    filtered.sort(
      (a, b) => b.rating.compareTo(a.rating),
    );
  } else if (_sortBy == 'Name: A-Z') {
    filtered.sort(
      (a, b) => a.name.compareTo(b.name),
    );
  }

  // ------------------------------------------------------------
  // BODY
  // ------------------------------------------------------------
  final bodyContent = SafeArea(
    top: false,
    child: Column(
      children: [
        _buildRefinedFixedHeader(isDark),

        const SizedBox(height: 8),

        _buildCategoryStrip(isDark),

        _buildFilterAndSortBar(isDark),

        Expanded(
          child: _isLoading
              ? CustomScrollView(
                  slivers: [
                    _buildSliverSkeleton(),
                  ],
                )
              : filtered.isEmpty
                  ? CustomScrollView(
                      slivers: [
                        _buildEmptyState(isDark),
                      ],
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      cacheExtent: 3000.0,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            40,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 900
                                      ? 5
                                      : MediaQuery.of(context).size.width > 600
                                          ? 3
                                          : 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _buildPremiumProductCard(
                                  filtered[index],
                                  isDark,
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        ),

                        // Web footer
                        if (kIsWeb)
                          SliverToBoxAdapter(
                            child: _buildScrollEndWebFooter(isDark),
                          ),
                      ],
                    ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------
  // SYSTEM UI
  // ------------------------------------------------------------
  const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  // ------------------------------------------------------------
  // WEB
  // ------------------------------------------------------------
  if (kIsWeb) {
    return Material(
      color: bgColor,
      child: bodyContent,
    );
  }

  // ------------------------------------------------------------
  // MOBILE
  // ------------------------------------------------------------
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: overlayStyle,
    child: Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Container(
        color: bgColor,
        child: bodyContent,
      ),
    ),
  );
}

  Widget _buildRefinedFixedHeader(bool isDark) {
    final double topPadding = MediaQuery.of(context).padding.top;

    String headerTitle = 'CAMPUS MART';
    String headerSubtitle = 'Provisions';
    if (_currentMode == BrowseMode.mandi) {
      headerTitle = 'MANDI FRESH MART';
      headerSubtitle = 'Fruits & Sabji';
    } else if (_currentMode == BrowseMode.fastFood) {
      headerTitle = 'FAST FOOD CAFE';
      headerSubtitle = 'Snacks & Canteen';
    }

    return ClipPath(
      clipper: HeaderClipper(),
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 8, bottom: 14),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                        ),
                        Text(
                          headerSubtitle,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (_profile != null) ...[
                    _buildBalanceBadge(
                      '₹${(_profile?['balance'] ?? 0)}',
                      Colors.greenAccent,
                    ),
                    const SizedBox(width: 4),
                  ],
                  _buildCartAction(isDark),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildModeToggleSelector(),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _buildModernSearch(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggleSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleOption('Provisions', BrowseMode.shop),
          _buildToggleOption('Mandi Fresh', BrowseMode.mandi),
          _buildToggleOption('Fast Food', BrowseMode.fastFood),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, BrowseMode mode) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white70,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceBadge(String val, Color color) {
    final balance = double.tryParse(val.replaceAll('₹', '').trim()) ?? 0;
    final isZero = balance <= 0;
    final badgeColor = isZero ? Colors.redAccent : Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.payments_rounded,
            color: badgeColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            val,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearch(bool isDark) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: _currentMode == BrowseMode.mandi
                      ? 'Search fresh produce...'
                      : (_currentMode == BrowseMode.fastFood
                          ? 'Search burger, maggi, pasta...'
                          : 'Search provisions...'),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showSortModal(isDark),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );

  Widget _buildFilterAndSortBar(bool isDark) {
    final isFastFoodTab = _currentMode == BrowseMode.fastFood;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildFilterChip(
                _onlyInStock ? 'In Stock Only' : 'Show All Stock',
                _onlyInStock
                    ? Icons.inventory_2_rounded
                    : Icons.inventory_2_outlined,
                _onlyInStock,
                () => setState(() => _onlyInStock = !_onlyInStock),
                isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                _sortBy,
                Icons.sort_rounded,
                _sortBy != 'Popularity',
                () => _showSortModal(isDark),
                isDark,
              ),
              if (isFastFoodTab) ...[
                const Spacer(),
                _buildVegNonVegToggle(isDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVegNonVegToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDietOption(
            label: 'Veg',
            isVeg: true,
            isSelected: _dietFilter == 'VEG',
            isDark: isDark,
            onTap: () {
              setState(() {
                _dietFilter = _dietFilter == 'VEG' ? 'ALL' : 'VEG';
              });
            },
          ),
          const SizedBox(width: 2),
          _buildDietOption(
            label: 'Non-Veg',
            isVeg: false,
            isSelected: _dietFilter == 'NON_VEG',
            isDark: isDark,
            onTap: () {
              final newSelection =
                  _dietFilter == 'NON_VEG' ? 'ALL' : 'NON_VEG';
              setState(() {
                _dietFilter = newSelection;
              });

              if (newSelection == 'NON_VEG' && mounted) {
                _showNonVegKitchenToast(context, isDark);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDietOption({
    required String label,
    required bool isVeg,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.grey[850] : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVegNonVegSymbol(isVeg: isVeg, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegNonVegSymbol({required bool isVeg, double size = 14}) {
    final color = isVeg ? Colors.green : Colors.red;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          height: size * 0.45,
          width: size * 0.45,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _showNonVegKitchenToast(BuildContext context, bool isDark) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 4,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor:
            isDark ? const Color(0xFF2C1E1E) : const Color(0xFFFFF5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF8B0000), width: 1),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            _buildVegNonVegSymbol(isVeg: false, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Non-Veg Kitchen Disclosure',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF8B0000),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Prepared in a separate kitchen setup with dedicated utensils & staff.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool active,
      VoidCallback onTap, bool isDark) {
    final accent = Colors.indigoAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? accent.withOpacity(0.1)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? accent.withOpacity(0.4)
                  : (isDark ? Colors.white10 : Colors.black12)),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? accent
                    : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: active
                        ? accent
                        : (isDark ? Colors.white60 : Colors.black54),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showSortModal(bool isDark) {
    final options = [
      'Popularity',
      'Price: Low to High',
      'Price: High to Low',
      'Rating',
      'Name: A-Z'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SORT BY',
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.indigoAccent,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            ...options.map((opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(opt,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight:
                              _sortBy == opt ? FontWeight.w900 : FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black)),
                  trailing: _sortBy == opt
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _sortBy = opt);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStrip(bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['name'];

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['name']),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 62,
                    width: 62,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.indigoAccent
                          : (isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.indigoAccent
                            : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black12),
                      ),
                    ),
                    child: Icon(
                      cat['icon'],
                      size: 25,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? Colors.indigoAccent
                              : (isDark ? Colors.white60 : Colors.black45),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductImage(ShopItem item, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: PlaceholderService.getProductColor(item.id)
            .withOpacity(isDark ? 0.04 : 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: item.imageUrl != null &&
                  item.imageUrl!.isNotEmpty &&
                  !item.imageUrl!.contains('vjmqvymkquj')
              ? CachedNetworkImage(
                  key: ValueKey('img_${item.id}'),
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.contain,
                  memCacheWidth: 400,
                  placeholder: (context, url) => const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  errorWidget: (context, url, error) =>
                      PlaceholderService.buildPlaceholder(item.category, item.id,
                          isDark: isDark),
                )
              : PlaceholderService.buildPlaceholder(item.category, item.id,
                  isDark: isDark),
        ),
      ),
    );
  }

  Widget _buildPremiumProductCard(ShopItem item, bool isDark) {
    bool hasDiscount = item.discountPrice != null && item.discountPrice! > 0;
    double price = hasDiscount ? item.discountPrice! : item.price;

    final imageSection = _buildProductImage(item, isDark);

    return Consumer<CartProvider>(builder: (context, cart, _) {
      final qty = cart.items[item.id] ?? 0;

      return GestureDetector(
        key: ValueKey('gesture_${item.id}'),
        onTap: () async {
          if (!_checkAuthorized(context)) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                  product: item, isMandiMode: widget.isMandiMode),
            ),
          );
          _fetchItems(silent: true);
          _refreshUserSessionState();
        },
        child: Opacity(
          opacity: item.stockQuantity > 0 ? 1.0 : 0.4,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        imageSection,
                        Positioned(
                            top: 16,
                            right: 16,
                            child: _buildGlassWishlistBtn(item.id)),
                        if (item.isBestseller)
                          Positioned(
                            top: 14,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Colors.orangeAccent,
                                    Colors.redAccent
                                  ]),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Row(children: [
                                Icon(Icons.local_fire_department,
                                    color: Colors.black, size: 10),
                                SizedBox(width: 4),
                                Text('BESTSELLER',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900))
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.brand ?? 'Campus'} • ${item.weightMl ?? ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontWeight: FontWeight.w600)),
                            if (item.totalReviews > 0 && item.rating > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 8),
                                  const SizedBox(width: 4),
                                  Text('${item.rating}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
                                              fontWeight: FontWeight.w900)),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('₹${price.toInt()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.w900)),
                                  if (hasDiscount) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.greenAccent
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Text(
                                            '-${(((item.price - price) / item.price) * 100).toInt()}%',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                    color: Colors.greenAccent,
                                                    fontWeight:
                                                        FontWeight.w900)))
                                  ]
                                ]),
                                if (hasDiscount)
                                  Text('₹${item.price.toInt()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: isDark
                                                  ? Colors.white30
                                                  : Colors.black38,
                                              decoration:
                                                  TextDecoration.lineThrough)),
                              ],
                            ),
                            _buildAddButton(item, qty),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(bool isDark) => SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(
                'NO ITEMS FOUND',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildAddButton(ShopItem item, int count) {
    final cart = context.read<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (item.stockQuantity == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black12,
            borderRadius: BorderRadius.circular(24)),
        child: Text('OUT',
            style: TextStyle(
                color: isDark ? Colors.white24 : Colors.black26,
                fontWeight: FontWeight.w900,
                fontSize: 11)),
      );
    }

    if (count == 0) {
      return GestureDetector(
        onTap: () {
          if (!_checkAuthorized(context)) return;
          cart.addItem(item);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.indigoAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.indigoAccent.withOpacity(0.4))),
          child: const Text('ADD',
              style: TextStyle(
                  color: Colors.indigoAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigoAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.indigoAccent.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circleBtn(
            icon: Icons.remove,
            onTap: () => cart.removeItem(item.id),
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          _circleBtn(
            icon: Icons.add,
            onTap: () => cart.addItem(item),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          color: Colors.indigoAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.indigoAccent.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildCartAction(bool isDark) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final count = cart.itemCount;

        return GestureDetector(
          onTap: () {
            if (!_checkAuthorized(context)) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopCheckoutScreen(
                    isMandiMode: _currentMode == BrowseMode.mandi),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.indigoAccent, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.indigoAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassWishlistBtn(String pid) {
    final wish = _wishlistIds.contains(pid);
    return GestureDetector(
      onTap: () => _toggleWishlist(pid),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(
                wish ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: wish ? Colors.redAccent : Colors.white,
                size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollEndWebFooter(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08090A) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _footerAbout(isDark),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: _footerPlatform(isDark),
                    ),
                    Expanded(
                      child: _footerContact(isDark),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerAbout(isDark),
                    const SizedBox(height: 30),
                    _footerPlatform(isDark),
                    const SizedBox(height: 30),
                    _footerContact(isDark),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _footerAbout(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAMPUS CONNECT',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Campus Connect is India's next-generation Hostel & Campus Super App designed for students, wardens, administrators, stores, mess facilities, farmers, and delivery partners.",
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '© ${DateTime.now().year} Campus Connect Operations Platform.',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Developed by Manpreet Singh',
          style: TextStyle(
            color: isDark ? Colors.white30 : Colors.black38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _footerPlatform(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        _footerLink('Privacy Policy', () {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()));
        }, isDark),
        _footerLink('Terms & Conditions', () {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => TermsOfServiceScreen()));
        }, isDark),
        _footerLink('Support', () {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => AppInfoScreen()));
        }, isDark),
      ],
    );
  }

  Widget _footerLink(String text, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _footerContact(bool isDark) {
    final org = OrganizationSettingsService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get In Touch',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          org.supportEmail,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          org.companyPhone,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          org.companyAddress,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSliverSkeleton() => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(0.05),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
            childCount: 6,
          ),
        ),
      );
}

// class HeaderClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     Path path = Path();
//     path.lineTo(0, size.height - 12);
//     path.quadraticBezierTo(
//         size.width / 2, size.height, size.width, size.height - 12);
//     path.lineTo(size.width, 0);
//     path.close();
//     return path;
//   }

//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// }
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double radius = 14;

    path.lineTo(0, size.height - radius);

    for (double i = 0; i < size.width; i += radius * 2) {
      path.arcToPoint(
        Offset(i + radius * 2, size.height - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
    }

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}