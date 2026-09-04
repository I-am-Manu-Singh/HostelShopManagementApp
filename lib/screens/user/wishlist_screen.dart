import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../shop/product_detail_screen.dart';
import '../../models/shop.dart';
import '../../services/cart_service.dart';
import 'package:provider/provider.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _wishlist = [];

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _supabase.from('wishlist').select('*, shop_items(*)').eq('user_id', user.id);
      if (mounted) setState(() { _wishlist = res as List; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(String productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('wishlist').delete().eq('user_id', user.id).eq('product_id', productId);
      _fetchWishlist();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('WISHLIST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildBackgroundOrbs(),
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
            : _wishlist.isEmpty 
              ? _buildEmptyState(isDark)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: _wishlist.length,
                        itemBuilder: (context, index) => _buildWishlistItem(_wishlist[index], isDark),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _wishlist.length,
                      itemBuilder: (context, index) => _buildWishlistItem(_wishlist[index], isDark),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Positioned(top: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 80),
          const SizedBox(height: 20),
          Text('EMPTY WISHLIST', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildWishlistItem(dynamic item, bool isDark) {
    final productId = item['product_id'];
    final pD = item['shop_items'];
    if (pD == null) return const SizedBox.shrink();

    final shopItem = ShopItem.fromJson({
      'id': productId,
      'name': pD['name'],
      'price': pD['price'],
      'discount_price': pD['discount_price'],
      'image_url': pD['image_url'],
      'category': pD['category'],
      'rating': pD['rating'] ?? 4.5,
      'brand': pD['brand'] ?? 'Campus',
      'weight_ml': pD['weight_ml'] ?? '',
      'is_bestseller': pD['is_bestseller'] ?? false,
      'stock_quantity': pD['stock_quantity'] ?? 100,
      'total_reviews': pD['total_reviews'] ?? 0,
      'sku_qr': pD['sku_qr'] ?? '',
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: shopItem))),
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: shopItem.imageUrl != null && shopItem.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: shopItem.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, s) => _placeholder(shopItem.category),
                    )
                  : _placeholder(shopItem.category),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopItem.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black, fontSize: 14)),
                Text(shopItem.category, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('₹${shopItem.discountPrice ?? shopItem.price}', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _removeFromWishlist(productId)),
              Consumer<CartProvider>(builder: (context, cart, _) => IconButton(icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.indigoAccent, size: 20), onPressed: () => cart.addItem(shopItem))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String cat) {
    IconData icon;
    switch (cat.toUpperCase()) {
      case 'SNACKS': icon = Icons.cookie_rounded; break;
      case 'BEVERAGES': icon = Icons.local_cafe_rounded; break;
      case 'STATIONERY': icon = Icons.edit_note_rounded; break;
      case 'HYGIENE': icon = Icons.clean_hands_rounded; break;
      default: icon = Icons.shopping_bag_rounded;
    }
    return Container(
      width: double.infinity, height: double.infinity,
      color: Colors.indigoAccent.withOpacity(0.05),
      child: Center(child: Icon(icon, color: Colors.indigoAccent.withOpacity(0.2), size: 30)),
    );
  }
}
