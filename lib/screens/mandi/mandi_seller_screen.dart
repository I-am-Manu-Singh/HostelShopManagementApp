// lib/screens/mandi/mandi_seller_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class MandiSellerScreen extends StatefulWidget {
  const MandiSellerScreen({super.key});

  @override
  State<MandiSellerScreen> createState() => _MandiSellerScreenState();
}

class _MandiSellerScreenState extends State<MandiSellerScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _purchaseOrders = [];
  List<dynamic> _mandiProducts = [];
  Map<String, double> _todayRates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSellerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch procurement POs addressed to this seller
      final poRes = await _client
          .from('mandi_purchase_orders')
          .select()
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      // 2. Fetch all Mandi products to update rates
      final prodRes = await _client
          .from('shop_items')
          .select()
          .eq('is_mandi', true);

      // 3. Fetch rates already updated for today
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateRes = await _client
          .from('mandi_rates')
          .select('product_id, price_per_unit')
          .eq('rate_date', todayStr);

      final Map<String, double> ratesMap = {};
      for (var r in (rateRes as List)) {
        ratesMap[r['product_id']] = (r['price_per_unit'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _purchaseOrders = poRes as List;
          _mandiProducts = prodRes as List;
          _todayRates = ratesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Seller load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRate(String productId, double rate) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await _client.from('mandi_rates').upsert({
        'product_id': productId,
        'rate_date': todayStr,
        'price_per_unit': rate,
        'created_by': user.id,
      }, onConflict: 'product_id,rate_date');

      // Also update base price in shop_items to keep them synchronized
      await _client.from('shop_items').update({
        'price': rate,
        'rate_date': todayStr,
      }).eq('id', productId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RATE SYNCHRONIZED SUCCESSFULLY'), backgroundColor: Colors.green),
      );
      _loadSellerData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('RATE UPDATE FAILED: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _updatePOStatus(String id, String status) async {
    try {
      await _client
          .from('mandi_purchase_orders')
          .update({'status': status})
          .eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PO Status updated to $status'), backgroundColor: Colors.indigoAccent),
      );
      _loadSellerData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PO update failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final showSidebar = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('SELLER PORTAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: showSidebar 
          ? null 
          : TabBar(
              controller: _tabController,
              indicatorColor: Colors.greenAccent,
              labelColor: Colors.greenAccent,
              unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              tabs: const [
                Tab(text: 'PROCUREMENT ORDERS'),
                Tab(text: 'MY DAILY RATES'),
              ],
            ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (showSidebar) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            children: [
                              ListTile(
                                selected: _tabController.index == 0,
                                selectedTileColor: Colors.greenAccent.withOpacity(0.08),
                                leading: const Icon(Icons.receipt_long_rounded),
                                title: Text('PROCUREMENT ORDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11)),
                                onTap: () {
                                  setState(() {
                                    _tabController.index = 0;
                                  });
                                },
                              ),
                              ListTile(
                                selected: _tabController.index == 1,
                                selectedTileColor: Colors.greenAccent.withOpacity(0.08),
                                leading: const Icon(Icons.analytics_rounded),
                                title: Text('MY DAILY RATES', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11)),
                                onTap: () {
                                  setState(() {
                                    _tabController.index = 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 7,
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildProcurementTab(isDark, textColor),
                            _buildRatesTab(isDark, textColor),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProcurementTab(isDark, textColor),
                    _buildRatesTab(isDark, textColor),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildProcurementTab(bool isDark, Color textColor) {
    if (_purchaseOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: textColor.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('NO PROCUREMENT REQUESTS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor.withOpacity(0.2))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _purchaseOrders.length,
      itemBuilder: (context, i) {
        final po = _purchaseOrders[i];
        final orderStatus = po['status'] ?? 'draft';

        return FadeInUp(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PO #${po['id'].toString().substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                    ),
                    _statusBadge(orderStatus),
                  ],
                ),
                const SizedBox(height: 16),
                _poRow('ITEM', po['product_name'] ?? 'N/A', textColor),
                _poRow('QUANTITY', '${po['quantity']} ${po['unit']}', textColor),
                _poRow('TARGET RATE', '₹${po['rate_per_unit']} / ${po['unit']}', textColor),
                _poRow('TOTAL PAYABLE', '₹${po['total_amount']}', Colors.green),
                if (po['notes'] != null && po['notes'].toString().isNotEmpty)
                  _poRow('ADMIN NOTES', po['notes'], Colors.orangeAccent),
                if (po['photo_url'] != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      po['photo_url'],
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const SizedBox(),
                    ),
                  ),
                ],
                if (orderStatus == 'sent' || orderStatus == 'draft') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updatePOStatus(po['id'], 'received'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ACCEPT & DELIVER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updatePOStatus(po['id'], 'cancelled'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('DECLINE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatesTab(bool isDark, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _mandiProducts.length,
      itemBuilder: (context, i) {
        final product = _mandiProducts[i];
        final currentRate = _todayRates[product['id']] ?? (product['price'] as num).toDouble();
        final TextEditingController rateCtrl = TextEditingController(text: currentRate.toString());

        return FadeInUp(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                      Text('Category: ${product['category']} | Unit: ${product['unit'] ?? 'kg'}', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  width: 100,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                    decoration: const InputDecoration(
                      prefixText: '₹',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                  onPressed: () {
                    final newRate = double.tryParse(rateCtrl.text);
                    if (newRate != null) {
                      _updateRate(product['id'], newRate);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _poRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c = Colors.grey;
    if (status == 'received') c = Colors.green;
    if (status == 'sent') c = Colors.orange;
    if (status == 'cancelled') c = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
