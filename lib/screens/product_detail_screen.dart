import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cart_service.dart';
import '../models/shop.dart';
import '../services/placeholder_service.dart';
import 'package:intl/intl.dart';
import 'shop_order_status_screen.dart';
import 'admin/admin_edit_product_screen.dart';
import 'add_product_review_screen.dart';
import 'shop_checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ShopItem product;
  final bool isMandiMode;
  const ProductDetailScreen({super.key, required this.product, this.isMandiMode = false});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _supabase = Supabase.instance.client;
  late ShopItem _currentProduct;
  int _currentImageIndex = 0;
  bool _isWishlisted = false;
  bool _isLoading = false;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  bool _canReview = false;
  
  // Weight & Loose Items quantity selection state
  double _selectedWeightMultiplier = 1.0;
  late String _selectedWeightUnit;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _selectedWeightUnit = _currentProduct.unit;
    _checkWishlist();
    _fetchReviews();
    _checkReviewEligibility();
  }

  Future<void> _checkReviewEligibility() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      // Check if user has ordered this product
      final orders = await _supabase.from('shop_orders').select('items').eq('user_id', user.id);
      bool hasOrdered = false;
      for (var order in orders) {
        final items = order['items'] as List;
        if (items.any((i) => i['id'] == _currentProduct.id)) {
          hasOrdered = true;
          break;
        }
      }
      
      // Check if already reviewed
      final existing = await _supabase.from('reviews').select('id').eq('product_id', _currentProduct.id).eq('user_id', user.id).maybeSingle();
      
      if (hasOrdered && existing == null && mounted) {
        setState(() => _canReview = true);
      }
    } catch (_) {}
  }

  Future<void> _fetchReviews() async {
    try {
      final res = await _supabase.from('reviews').select('*, profiles(full_name, avatar_url)').eq('product_id', _currentProduct.id).order('created_at', ascending: false);
      if (mounted) setState(() { _reviews = res as List; _isLoadingReviews = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _fetchFreshProduct() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('shop_items').select().eq('id', _currentProduct.id).single();
      if (mounted) {
        setState(() {
          _currentProduct = ShopItem.fromMap(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkWishlist() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final res = await _supabase.from('wishlist').select().eq('user_id', user.id).eq('product_id', _currentProduct.id).maybeSingle();
    if (mounted) setState(() => _isWishlisted = res != null);
  }

  Future<void> _toggleWishlist() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      if (_isWishlisted) {
        await _supabase.from('wishlist').delete().eq('user_id', user.id).eq('product_id', _currentProduct.id);
      } else {
        await _supabase.from('wishlist').insert({'user_id': user.id, 'product_id': _currentProduct.id});
      }
      setState(() => _isWishlisted = !_isWishlisted);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = PlaceholderService.getProductColor(_currentProduct.id);
    final bgColor = Color.alphaBlend(
      tintColor.withOpacity(isDark ? 0.05 : 0.03),
      Theme.of(context).scaffoldBackgroundColor,
    );
    final cardColor = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildProductAppBar(context, isDark),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -6))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 720) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeaderSection(isDark),
                                    const SizedBox(height: 16),
                                    _buildBarCodeArea(isDark),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDescriptionSection(cardColor, borderColor, isDark),
                                    SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(10)))),
                            _buildHeaderSection(isDark),
                            const SizedBox(height: 12),
                            _buildDescriptionSection(cardColor, borderColor, isDark),
                            _buildBarCodeArea(isDark),
                            SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                          ],
                        );
                      }
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildPurchaseMissionFooter(isDark),
          if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))),
        ],
      ),
    );
  }

  Widget _glassCircleBtn({required IconData icon, required VoidCallback onTap, required bool isDark, bool active = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(color: active ? Colors.redAccent.withOpacity(0.2) : (isDark ? Colors.black : Colors.white).withOpacity(0.4), shape: BoxShape.circle, border: Border.all(color: (active ? Colors.redAccent : (isDark ? Colors.white : Colors.black)).withOpacity(0.1))),
          child: IconButton(icon: Icon(icon, color: active ? Colors.redAccent : (isDark ? Colors.white : Colors.black), size: 18), onPressed: onTap),
        ),
      ),
    );
  }

  Widget _buildProductAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 340,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(padding: const EdgeInsets.all(8.0), child: _glassCircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.pop(context), isDark: isDark)),
      actions: [
        Padding(padding: const EdgeInsets.all(8.0), child: _glassCircleBtn(icon: Icons.edit_note_rounded, onTap: () async {
          final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(product: _currentProduct)));
          if (updated == true) _fetchFreshProduct();
        }, isDark: isDark)),
        Padding(padding: const EdgeInsets.all(8.0), child: _glassCircleBtn(icon: Icons.share_outlined, onTap: () {}, isDark: isDark)),
        Padding(padding: const EdgeInsets.all(8.0), child: _glassCircleBtn(icon: _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, onTap: _toggleWishlist, isDark: isDark, active: _isWishlisted)),
        
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(color: PlaceholderService.getProductColor(_currentProduct.id).withOpacity(isDark ? 0.05 : 0.08)),
              child: PageView.builder(
                onPageChanged: (v) => setState(() => _currentImageIndex = v),
                itemCount: 3,
                itemBuilder: (context, i) {
                  final img = _currentProduct.imageUrl;
                  return Hero(
                    tag: i == 0 ? 'prod_${_currentProduct.id}' : 'prod_slide_${_currentProduct.id}_$i',
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 120, 16, 60),
                      child: img != null && img.startsWith('http') && !img.contains('vjmqvymkquj')
                          ? CachedNetworkImage(imageUrl: img, fit: BoxFit.contain, errorWidget: (c, e, s) => PlaceholderService.buildPlaceholder(_currentProduct.category, _currentProduct.id, isDark: isDark))
                          : PlaceholderService.buildPlaceholder(_currentProduct.category, _currentProduct.id, isDark: isDark),
                    ),
                  );
                },
              ),
            ),
            Positioned(bottom: 20, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)), child: Text('${_currentImageIndex + 1} / 3', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark) {
    final price = (_currentProduct.discountPrice ?? _currentProduct.price).toInt();
    final hasDiscount = _currentProduct.discountPrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentProduct.isBestseller)
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.redAccent]), borderRadius: BorderRadius.circular(12)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_fire_department, color: Colors.black, size: 15), SizedBox(width: 8), Text('BESTSELLER', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: Row(children: [const Icon(Icons.star_rounded, color: Colors.amber, size: 14), const SizedBox(width: 6), Text('${_currentProduct.rating} (${_reviews.length})', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w900))])),
          ],
        ),
        const SizedBox(height: 12),
        Text(_currentProduct.name, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Row(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_currentProduct.brand ?? 'Campus', style: const TextStyle(color: Colors.indigoAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Text(_currentProduct.weightMl ?? '', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
                const SizedBox(width: 8),
                Text(_currentProduct.category, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
              ]),
            ]),
            const Spacer(),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildSmallInfoChip(Icons.timer_outlined, _currentProduct.shelfLife ?? '12 Months', isDark),
            const SizedBox(width: 8),
            _buildSmallInfoChip(Icons.inventory_2_outlined, _currentProduct.packageType ?? 'Standard', isDark),
          ],
        ),
        if (_currentProduct.ingredients != null && _currentProduct.ingredients!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_currentProduct.ingredients!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('₹${(price * _selectedWeightMultiplier).toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            if (hasDiscount) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('₹${(_currentProduct.price * _selectedWeightMultiplier).toInt()}', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 14, decoration: TextDecoration.lineThrough)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('-${((1 - (_currentProduct.discountPrice! / _currentProduct.price)) * 100).toInt()}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900))),
              ]),
            ],
            const Spacer(),
            Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 🔻 tighter
  decoration: BoxDecoration(
    color: (_currentProduct.stockQuantity > 0
            ? Colors.greenAccent
            : Colors.redAccent)
        .withOpacity(0.15),
    borderRadius: BorderRadius.circular(6), // 🔥 match discount badge
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min, // 🔥 shrink to content
    children: [
      Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: _currentProduct.stockQuantity > 0
              ? Colors.greenAccent
              : Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),

      Text(
        _currentProduct.stockQuantity > 0
            ? 'IN STOCK'
            : 'OUT',
        style: TextStyle(
          color: _currentProduct.stockQuantity > 0
              ? Colors.greenAccent
              : Colors.redAccent,
          fontSize: 9, // 🔥 match discount badge
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  ),
)
          ],
        ),
        _buildWeightSelectionOptions(isDark),
      ],
    );
  }

  Widget _buildWeightSelectionOptions(bool isDark) {
    final cat = _currentProduct.category.toLowerCase();
    final isLoose = cat.contains('sabji') || cat.contains('fruit') || cat.contains('kiryana') || cat.contains('dairy') || _currentProduct.isMandi;
    
    // Choose appropriate options depending on the product's unit type
    final List<Map<String, dynamic>> options;
    if (_currentProduct.unit == 'kg') {
      options = [
        {'label': '250 g', 'multiplier': 0.25, 'unit': 'kg'},
        {'label': '500 g', 'multiplier': 0.5, 'unit': 'kg'},
        {'label': '1 kg', 'multiplier': 1.0, 'unit': 'kg'},
        {'label': '2 kg', 'multiplier': 2.0, 'unit': 'kg'},
        {'label': '5 kg', 'multiplier': 5.0, 'unit': 'kg'},
      ];
    } else if (_currentProduct.unit == 'L' || _currentProduct.unit == 'litre') {
      options = [
        {'label': '250 ml', 'multiplier': 0.25, 'unit': _currentProduct.unit},
        {'label': '500 ml', 'multiplier': 0.5, 'unit': _currentProduct.unit},
        {'label': '1 L', 'multiplier': 1.0, 'unit': _currentProduct.unit},
        {'label': '2 L', 'multiplier': 2.0, 'unit': _currentProduct.unit},
      ];
    } else if (isLoose) {
      options = [
        {'label': '0.5x', 'multiplier': 0.5, 'unit': _currentProduct.unit},
        {'label': '1.0x', 'multiplier': 1.0, 'unit': _currentProduct.unit},
        {'label': '2.0x', 'multiplier': 2.0, 'unit': _currentProduct.unit},
        {'label': '5.0x', 'multiplier': 5.0, 'unit': _currentProduct.unit},
      ];
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT WEIGHT / QUANTITY', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              itemBuilder: (ctx, i) {
                final opt = options[i];
                final isSelected = _selectedWeightMultiplier == opt['multiplier'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWeightMultiplier = opt['multiplier'] as double;
                      _selectedWeightUnit = opt['unit'] as String;
                    });
                    // If already in cart, update it
                    final cart = context.read<CartProvider>();
                    if (cart.items.containsKey(_currentProduct.id)) {
                      cart.updateWeightOrUnit(_currentProduct.id, _selectedWeightMultiplier, _selectedWeightUnit);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12)),
                    ),
                    child: Center(
                      child: Text(
                        opt['label'] as String,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child, required Color cardColor, required Color borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(Color cardColor, Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Text('PRODUCT STORY', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2))]),
                  const SizedBox(height: 14),
                  Text(_currentProduct.description ?? 'Optimized for campus convenience.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.7, fontWeight: FontWeight.w500)),
                  if (_currentProduct.nutritionalInfo != null || _currentProduct.ingredients != null) ...[
                    const SizedBox(height: 24),
                    _buildNutritionLabelCard(isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 36), // 👈 increased gap spacer between product specs/identifier card and user feedback
        _buildReviewsSection(isDark),
      ],
    );
  }

  Widget _buildNutritionLabelCard(bool isDark) {
    final info = _currentProduct.nutritionalInfo ?? {};
    final labelColor = isDark ? Colors.white : Colors.black;
    final isFood = ['Chocolates', 'Snacks', 'Drinks', 'Instant Meals', 'Biscuits'].contains(_currentProduct.category);
    
    // 🛡️ DAILY VALUE REFERENCE (MISSION-CRITICAL ESTIMATES)
    final Map<String, double> dvMap = {
      'Calories': 2000, 'Energy': 2000, 'Fat': 65, 'Saturated Fat': 20,
      'Sugar': 50, 'Carbohydrates': 275, 'Protein': 50, 'Sodium': 2400,
    };

    String getDV(String key, String value) {
      if (!isFood) return "—";
      final numValue = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (numValue == null || !dvMap.containsKey(key)) return "—";
      final dv = (numValue / dvMap[key]!) * 100;
      return "${dv.toInt()}%";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFood ? 'Nutrition Facts' : 'Technical Specifications', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: labelColor)),
          const Divider(thickness: 8, color: Colors.black, height: 16),
          if (isFood) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Serving size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: labelColor)), Text(_currentProduct.weightMl ?? '1 unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: labelColor))]),
            const Divider(thickness: 4, color: Colors.black, height: 12),
            Text('Amount per serving', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: labelColor)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Calories', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: labelColor)), Text(info['Calories']?.toString() ?? info['Energy']?.toString() ?? '?', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: labelColor))]),
            const Divider(thickness: 2, color: Colors.black, height: 12),
            Align(alignment: Alignment.centerRight, child: Text('% Daily Value*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: labelColor))),
          ] else ...[
            Text('IDENTIFIER: ${_currentProduct.skuQr ?? 'X-REQUISITION'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: labelColor)),
            const Divider(thickness: 2, color: Colors.black, height: 12),
          ],
          ...info.entries.where((e) => e.key != 'Calories' && e.key != 'Energy').map((e) => Column(children: [const Divider(thickness: 1, color: Colors.black45, height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(e.key, style: TextStyle(fontWeight: FontWeight.bold, color: labelColor, fontSize: 13)), const SizedBox(width: 4), Text(e.value.toString(), style: TextStyle(color: labelColor, fontSize: 13))]), Text(getDV(e.key, e.value.toString()), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: labelColor))])])),
          const Divider(thickness: 4, color: Colors.black, height: 16),
          if (_currentProduct.ingredients != null && _currentProduct.ingredients!.isNotEmpty) ...[
            Text(isFood ? 'INGREDIENTS:' : 'SPECIFICATIONS:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: labelColor, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(_currentProduct.ingredients!, style: TextStyle(fontSize: 12, color: labelColor.withOpacity(0.8), height: 1.5)),
            const Divider(thickness: 1, color: Colors.black12, height: 24),
          ],
          if (_currentProduct.howToUse != null && _currentProduct.howToUse!.isNotEmpty) ...[
            Text('MISSION PROTOCOL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: labelColor, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(_currentProduct.howToUse!, style: TextStyle(fontSize: 12, color: labelColor.withOpacity(0.8), height: 1.5)),
            const Divider(thickness: 4, color: Colors.black, height: 16),
          ],
          if (isFood) Text('* The % Daily Value (DV) tells you how much a nutrient in a serving of food contributes to a daily diet.', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: labelColor.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(Color cardColor, Color borderColor, bool isDark) {
    return _glassCard(
      cardColor: cardColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.egg_alt_rounded, color: Colors.greenAccent, size: 16), const SizedBox(width: 8), Text('INGREDIENTS', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2))]),
          const SizedBox(height: 12),
          Text(_currentProduct.ingredients!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, height: 1.6, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUsageSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigoAccent.withOpacity(0.15))),
      child: ExpansionTile(
        title: Text('HOW TO USE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.indigoAccent)),
        children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Text(_currentProduct.howToUse!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, height: 1.7, fontWeight: FontWeight.bold)))]))],
      ),
    );
  }

  Widget _buildSpecificationsGrid(Color cardColor, Color borderColor, bool isDark) {
    final specs = [
      {'label': 'SHELF LIFE', 'value': _currentProduct.shelfLife ?? '12 Months', 'icon': Icons.timer_outlined},
      {'label': 'PACKAGE', 'value': _currentProduct.packageType ?? 'Standard', 'icon': Icons.inventory_2_outlined},
      {'label': 'CATEGORY', 'value': _currentProduct.category, 'icon': Icons.category_outlined},
      {'label': 'STOCK', 'value': '${_currentProduct.stockQuantity} UNITS', 'icon': Icons.inventory_2_outlined},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5),
      itemCount: specs.length,
      itemBuilder: (ctx, i) {
        final s = specs[i];
        return _glassCard(cardColor: cardColor, borderColor: borderColor, child: Row(children: [Icon(s['icon'] as IconData, size: 16, color: Colors.indigoAccent), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(s['label'] as String, style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 8, fontWeight: FontWeight.w900)), Text(s['value'] as String, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)]))]));
      },
    );
  }

  Widget _buildReviewsSection(bool isDark) {
    if (_isLoadingReviews) return const Center(child: CircularProgressIndicator());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('USER FEEDBACK', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            if (_reviews.isNotEmpty) Text('${_reviews.length} REVIEWS', style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        if (true) // 🔥 Always show review prompt but restrict access via _canReview logic if needed
          FadeInDown(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.1), Colors.pinkAccent.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                   Expanded(
                     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                       Text('ENJOYED THE PRODUCT?', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                       const SizedBox(height: 4),
                       Text('Share your mission intel with the community.', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
                     ]),
                   ),
                   ElevatedButton(
                     onPressed: () async {
                       final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductReviewScreen(product: _currentProduct)));
                       if (res == true) { _fetchReviews(); setState(() => _canReview = false); }
                     }, 
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                     child: const Text('RATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                   ),
                ],
              ),
            ),
          ),

        if (_reviews.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('MISSION INTEL PENDING: NO REVIEWS YET.', style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold))))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length > 5 ? 5 : _reviews.length,
            itemBuilder: (context, i) {
              final r = _reviews[i];
              final profile = r['profiles'] ?? {};
              return Container(
                margin: EdgeInsets.only(bottom: i == ( (_reviews.length > 5 ? 5 : _reviews.length) - 1 ) ? 0 : 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(18), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 12, backgroundImage: NetworkImage(profile['avatar_url'] ?? 'https://i.pravatar.cc/150?img=1')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile['full_name'] ?? 'Guest User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text(DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(r['created_at'])), style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Row(children: List.generate(5, (index) => Icon(Icons.star_rounded, size: 10, color: index < (r['rating'] ?? 5) ? Colors.amber : Colors.white10))),
                    ],
                  ),
                    const SizedBox(height: 10),
                    Text(r['comment'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, height: 1.5)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBarCodeArea(bool isDark) {
    return _glassCard(
      cardColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
      borderColor: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SPECIFICATION IDENTIFIER', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 4), Text(_currentProduct.skuQr ?? _currentProduct.name.toUpperCase(), style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))]),
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: QrImageView(data: _currentProduct.skuQr ?? _currentProduct.name, size: 60, version: QrVersions.auto)),
        ],
      ),
    );
  }

  Widget _buildTagsArea() {
    final tags = _currentProduct.tags ?? ['Store', 'Essential', 'Provision'];
    return Wrap(spacing: 10, runSpacing: 10, children: tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.06), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigoAccent.withOpacity(0.12))), child: Text('#$t', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)))).toList());
  }

  Widget _buildPurchaseMissionFooter(bool isDark) {
    return Consumer<CartProvider>(builder: (context, cart, _) {
      final qty = cart.items[_currentProduct.id] ?? 0;
      final unitPrice = _currentProduct.discountPrice ?? _currentProduct.price;
      final mult = cart.weightQuantities[_currentProduct.id] ?? _selectedWeightMultiplier;
      final totalPrice = qty * unitPrice * mult;
      return Positioned(
        left: 0, right: 0, bottom: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(36)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, -10))]),
          child: Row(children: [
            if (_currentProduct.stockQuantity <= 0)
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
                  child: Center(child: Text('PRODUCT OUT OF STOCK', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1))),
                ),
              )
            else if (qty > 0) ...[
              Expanded(
                child: Container(
                  height: 64, padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('TOTAL COST', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1)), Text('₹${totalPrice.toInt()}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black))]),
                      const Spacer(),
                      _buildQuantityController(cart, qty),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _actionIconBtn(Icons.shopping_cart_checkout_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCheckoutScreen(isMandiMode: widget.isMandiMode))), isDark),
            ] else
              Expanded(child: _buildAddToCartBtn(cart)),
          ]),
        ),
      );
    });
  }

  Widget _actionIconBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return Container(
      width: 64, height: 60,
      decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Icon(icon, color: Colors.white, size: 24))),
    );
  }

  Widget _buildAddToCartBtn(CartProvider cart) {
    return Container(
      height: 64,
      decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Material(color: Colors.transparent, child: InkWell(onTap: () => cart.addItem(_currentProduct, multiplier: _selectedWeightMultiplier, unit: _selectedWeightUnit), borderRadius: BorderRadius.circular(24), child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22), SizedBox(width: 12), Text('ADD TO CART SYSTEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5))])))),
    );
  }

  Widget _buildQuantityController(CartProvider cart, int qty) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _qtyBtn(Icons.remove_rounded, () => cart.removeItem(_currentProduct.id)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$qty', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.indigoAccent))),
      _qtyBtn(Icons.add_rounded, () => cart.addItem(_currentProduct, multiplier: _selectedWeightMultiplier, unit: _selectedWeightUnit)),
    ]);
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return Material(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(8), child: Icon(icon, size: 18, color: Colors.white))));
  }

  Widget _buildSmallInfoChip(IconData icon, String val, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.indigoAccent), const SizedBox(width: 6), Text(val, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11, fontWeight: FontWeight.bold))]),
    );
  }
}
