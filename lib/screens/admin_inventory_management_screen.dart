import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_edit_product_screen.dart';
import 'inventory_scanner_screen.dart';
import '../models/shop.dart';

class AdminInventoryManagementScreen extends StatefulWidget {
  const AdminInventoryManagementScreen({super.key});

  @override
  State<AdminInventoryManagementScreen> createState() => _AdminInventoryManagementScreenState();
}

class _AdminInventoryManagementScreenState extends State<AdminInventoryManagementScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<ShopItem> _allItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    try {
      final shopRes = await _client.from('shop_items').select().order('name');
      final List<ShopItem> combined = (shopRes as List).map((i) => ShopItem.fromJson(i)).toList();

      if (mounted) {
        setState(() {
          _allItems = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, int> _getAnalytics(List<ShopItem> items) {
    int total = items.length;
    int low = items.where((i) => i.stockQuantity > 0 && i.stockQuantity < 10).length;
    int out = items.where((i) => i.stockQuantity <= 0).length;
    return {'total': total, 'low': low, 'out': out};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('INVENTORY MANAGEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigoAccent),
            onPressed: () async {
              final String? result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScannerScreen()));
              if (result != null) {
                // Try finding item
                final item = _allItems.cast<ShopItem?>().firstWhere((i) => i?.skuQr == result, orElse: () => null);
                if (item != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(product: item))).then((_) => _fetchInventory());
                } else {
                  // Not found, open Add screen with SKU pre-filled
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(scannedSku: result))).then((_) => _fetchInventory());
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
             Tab(text: 'SHOP STOCK'),
             Tab(text: 'MESS INVENTORY'),
             Tab(text: 'CANTEEN'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(isDark),
              Column(
                children: [
                  _buildSearchBar(isDark),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabContent('SHOP', isDark, cardColor, borderColor),
                        _buildTabContent('MESS', isDark, cardColor, borderColor),
                        _buildTabContent('CANTEEN', isDark, cardColor, borderColor),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEditProductScreen()));
          if (res == true) _fetchInventory();
        },
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'FILTER BY ITEM NAME OR CODE...',
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigoAccent, size: 20),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRefractionOrbs(bool isDark) {
    return Positioned(bottom: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(isDark ? 0.05 : 0.02), shape: BoxShape.circle))));
  }

  Widget _buildTabContent(String type, bool isDark, Color cardColor, Color borderColor) {
    final filteredItems = _allItems.where((i) {
      final cat = i.category.toLowerCase();
      final name = i.name.toLowerCase();
      if (type == 'SHOP') {
        // Items NOT in other categories
        return !cat.contains('kitchen') && !cat.contains('raw') && !cat.contains('grocery') && 
               !cat.contains('beverage') && !cat.contains('snack') && !cat.contains('meal') && 
               !cat.contains('ready');
      }
      if (type == 'MESS') {
        // Raw materials and bulk kitchen supplies
        return cat.contains('kitchen') || cat.contains('raw') || cat.contains('grocery') || 
               cat.contains('bulk') || name.contains('rice') || name.contains('dal') || name.contains('oil');
      }
      if (type == 'CANTEEN') {
        // Ready to eat, snacks, beverages
        return cat.contains('beverage') || cat.contains('snack') || cat.contains('ready') || 
               cat.contains('canteen') || cat.contains('fast food') || name.contains('coke') || name.contains('chips');
      }
      return true;
    }).toList();

    final searchFiltered = filteredItems.where((i) => 
      i.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      i.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
    
    final stats = _getAnalytics(filteredItems);

    return Column(
      children: [
        _buildAnalyticsRow(stats, isDark),
        Expanded(
          child: searchFiltered.isEmpty 
            ? _buildEmptyInventory(type, isDark)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: searchFiltered.length,
                itemBuilder: (context, i) => _buildItemCard(searchFiltered[i], cardColor, borderColor, isDark),
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyInventory(String type, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 16),
          Text('NO ITEMS IN $type REPOSITORY', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Register new assets using the action button.', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(Map<String, int> stats, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          _statCard('TOTAL', stats['total']!, Colors.indigoAccent, isDark),
          const SizedBox(width: 12),
          _statCard('LOW STOCK', stats['low']!, Colors.amberAccent, isDark),
          const SizedBox(width: 12),
          _statCard('OUT OF STOCK', stats['out']!, Colors.redAccent, isDark),
        ],
      ),
    );
  }

  Widget _statCard(String label, int val, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.1))),
        child: Column(
          children: [
            Text(val.toString(), style: GoogleFonts.outfit(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ShopItem item, Color cardColor, Color borderColor, bool isDark) {
    final int stock = item.stockQuantity;
    final bool lowStock = stock < 10;
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: lowStock ? Colors.redAccent.withOpacity(0.3) : borderColor)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: item.imageUrl != null 
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.inventory_2_rounded, color: Colors.indigoAccent)))
              : const Icon(Icons.inventory_2_rounded, color: Colors.indigoAccent),
          ),
          title: Text(item.name, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(children: [
              _statusTag('QTY: $stock', lowStock ? Colors.redAccent : Colors.greenAccent),
              const SizedBox(width: 8),
              _statusTag('₹${item.discountPrice ?? item.price}', Colors.indigoAccent),
            ]),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
             _actionIcon(Icons.history_rounded, isDark ? Colors.white24 : Colors.black26, () {}),
             _actionIcon(Icons.edit_rounded, Colors.blueAccent, () async {
               final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(product: item)));
               if (res == true) _fetchInventory();
             }),
          ]),
        ),
      ),
    );
  }

  Widget _statusTag(String label, Color c) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900)));
  }

  Widget _actionIcon(IconData icon, Color c, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: c, size: 20), onPressed: onTap);
  }
}
