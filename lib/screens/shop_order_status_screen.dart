import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/receipt_service.dart';

class ShopOrderStatusScreen extends StatefulWidget {
  const ShopOrderStatusScreen({super.key});

  @override
  State<ShopOrderStatusScreen> createState() => _ShopOrderStatusScreenState();
}

class _ShopOrderStatusScreenState extends State<ShopOrderStatusScreen> {
  final _client = Supabase.instance.client;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final user = _client.auth.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('MY ORDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close_rounded, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: user == null 
        ? const Center(child: Text('SESSION EXPIRED'))
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _client.from('shop_orders').stream(primaryKey: ['id']).eq('user_id', user.id).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) return _buildEmptyState(textColor);

              return Stack(
                children: [
                  _buildBackgroundGlow(isDark),
                  ListView.builder(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: orders.length,
                    itemBuilder: (context, i) => _buildOrderTile(orders[i], textColor, isDark),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: (isDark ? Colors.indigoAccent : Colors.pinkAccent).withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: textColor.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text('NO ACTIVE MISSIONS', style: GoogleFonts.outfit(color: textColor.withOpacity(0.2), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('Secure your rations from the campus store.', style: TextStyle(color: textColor.withOpacity(0.1), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildOrderTile(dynamic o, Color textColor, bool isDark) {
    final status = o['order_status'] ?? 'Placed';
    final items = o['items'] as List;
    final eta = o['estimated_delivery'];
    
    return FadeInRight(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(32), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(24),
            collapsedIconColor: textColor.withOpacity(0.2),
            iconColor: Colors.pinkAccent,
            title: Row(
              children: [
                _statusIndicator(status),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Text('ORDER #${o['id'].toString().substring(0,8).toUpperCase()}', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 14)),
                   Text(DateFormat('MMM dd, hh:mm a').format(DateTime.parse(o['created_at'])), style: TextStyle(color: textColor.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold)),
                ])),
              ],
            ),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
               Text('₹${(o['total_price'] ?? 0).toInt()}', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 18)),
               Text('${items.length} ITEMS', style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ]),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: textColor.withOpacity(0.05)),
                    const SizedBox(height: 16),
                    _detailRow('LOGISTICS', o['delivery_type'] ?? 'Pickup', textColor),
                    if (o['delivery_address'] != null && o['delivery_address'].toString().isNotEmpty)
                      _detailRow('ADDRESS', o['delivery_address'], textColor),
                    _detailRow('PAYMENT', o['payment_method'] ?? 'Wallet', textColor),
                    _detailRow('P.STATUS', o['payment_status'] ?? 'Pending', textColor),
                    if (o['is_booking'] == true) ...[
                      const SizedBox(height: 8),
                      _detailRow('BOOKING DATE', o['booking_date'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(o['booking_date'])) : 'N/A', Colors.indigoAccent),
                      _detailRow('ADVANCE PAID', '₹${o['advance_paid'] ?? 0.0}', Colors.green),
                      _detailRow('USER TYPE', (o['user_type'] ?? 'domestic').toString().toUpperCase(), textColor),
                      if (o['delivery_location'] != null && o['delivery_location'].toString().isNotEmpty)
                        _detailRow('LOCATION', o['delivery_location'], textColor),
                    ],
                    if (o['emergency_contact_name'] != null && o['emergency_contact_name'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _detailRow('ALT. RECEIVER', '${o['emergency_contact_name']} (${o['emergency_contact_relation']})', textColor),
                      _detailRow('ALT. PHONE', o['emergency_contact_phone'], textColor),
                    ],
                    if (o['order_instructions'] != null && o['order_instructions'].toString().isNotEmpty)
                      _detailRow('INSTRUCTIONS', o['order_instructions'], Colors.pinkAccent),
                    if (eta != null) ...[
                       _detailRow('ESTIMATED ARRIVAL', DateFormat('hh:mm a').format(DateTime.parse(eta)), Colors.amberAccent),
                       _buildRelativeETA(eta, isDark),
                    ],
                    
                    if (o['delivery_otp'] != null && status != 'Completed' && status != 'Delivered') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
                        child: Row(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                             Text('COLLECTION OTP', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                             const SizedBox(height: 4),
                             Text('Show this during delivery', style: TextStyle(color: textColor.withOpacity(0.2), fontSize: 9)),
                          ]),
                          const Spacer(),
                          Text(o['delivery_otp'].toString(), style: GoogleFonts.outfit(color: textColor, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text('MANIFEST', style: GoogleFonts.outfit(color: textColor.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    ...items.map((it) {
                      final qty = (it['qty'] as num).toInt();
                      final wQty = it['weight_qty'] != null ? (it['weight_qty'] as num).toDouble() : null;
                      final wUnit = it['weight_unit']?.toString();
                      
                      String qtyWeightStr = qty.toString();
                      if (wQty != null && wQty != 1.0) {
                        qtyWeightStr = '$qty x ${wQty} ${wUnit ?? 'kg'}';
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Text('$qtyWeightStr ', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                          Text(it['name'] ?? 'ITEM', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                          const Spacer(),
                          Text('₹${it['price'] ?? ''}', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12)),
                        ]),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _authorizeReceipt(o),
                        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                        label: const Text('AUTHORIZE MISSION RECEIPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _authorizeReceipt(dynamic o) async {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating receipt...'), duration: Duration(seconds: 1)));
     try {
       await ReceiptService.generateAndShareReceipt(o);
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export receipt: $e'), backgroundColor: Colors.red));
     }
  }

  Widget _statusIndicator(String s) {
    Color c = Colors.indigoAccent;
    if (s == 'Confirmed') c = Colors.tealAccent;
    if (s == 'In Process' || s == 'Preparing' || s == 'Placed') c = Colors.orangeAccent;
    if (s == 'Packing') c = Colors.amberAccent;
    if (s == 'Ready' || s == 'Shipped') c = Colors.blueAccent;
    if (s == 'Completed' || s == 'Delivered') c = Colors.greenAccent;
    if (s == 'Rejected' || s == 'Cancelled') c = Colors.redAccent;

    return Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 10)]));
  }

  Widget _buildRelativeETA(String etaStr, bool isDark) {
    final eta = DateTime.parse(etaStr);
    final diff = eta.difference(DateTime.now());
    if (diff.isNegative) return const SizedBox.shrink();
    
    String text = "Expected shortly";
    if (diff.inHours > 0) {
      text = "Arriving in approx. ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}";
    } else if (diff.inMinutes > 0) {
      text = "Delivery in ${diff.inMinutes} mins";
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amberAccent.withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.timer_outlined, color: Colors.amberAccent, size: 14),
        const SizedBox(width: 8),
        Text(text.toUpperCase(), style: const TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _detailRow(String label, String val, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text(label, style: TextStyle(color: color.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Expanded(child: Text(val, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right))]));
  }
}
