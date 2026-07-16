// lib/screens/mandi/mandi_delivery_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class MandiDeliveryScreen extends StatefulWidget {
  const MandiDeliveryScreen({super.key});

  @override
  State<MandiDeliveryScreen> createState() => _MandiDeliveryScreenState();
}

class _MandiDeliveryScreenState extends State<MandiDeliveryScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _assignedOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchAssignedDeliveries();
  }

  Future<void> _fetchAssignedDeliveries() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _client
          .from('shop_orders')
          .select('*, profiles(*)')
          .eq('delivery_partner_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _assignedOrders = res as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Delivery partner load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _client
          .from('shop_orders')
          .update({'order_status': status})
          .eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order Status updated to $status'), backgroundColor: Colors.indigoAccent),
      );
      _fetchAssignedDeliveries();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _verifyAndDeliver(dynamic o, bool isDark) async {
    final TextEditingController otpCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text('VERIFY DELIVERY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ask the customer for their 4-digit Collection OTP.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
              const SizedBox(height: 24),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10, color: Colors.indigoAccent),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () {
                if (otpCtrl.text == o['delivery_otp'].toString()) {
                  Navigator.pop(ctx);
                  _updateStatus(o['id'], 'Delivered');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VERIFICATION SUCCESSFUL: ORDER DELIVERED'), backgroundColor: Colors.greenAccent));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('INVALID OTP: ACCESS DENIED'), backgroundColor: Colors.redAccent));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('VERIFY & COMPLETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final bgColor = theme.scaffoldBackgroundColor;

    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : _assignedOrders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delivery_dining_outlined, size: 64, color: textColor.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    Text('NO PENDING DISPATCHES', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor.withOpacity(0.2))),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchAssignedDeliveries,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.8,
                        ),
                        itemCount: _assignedOrders.length,
                        itemBuilder: (context, i) {
                          final o = _assignedOrders[i];
                          final status = o['order_status'] ?? 'Placed';
                          final profile = o['profiles'];
                          final isBooking = o['is_booking'] ?? false;
                          return _buildDeliveryCard(o, status, profile, isBooking, isDark, textColor);
                        },
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _assignedOrders.length,
                      itemBuilder: (context, i) {
                        final o = _assignedOrders[i];
                        final status = o['order_status'] ?? 'Placed';
                        final profile = o['profiles'];
                        final isBooking = o['is_booking'] ?? false;
                        return _buildDeliveryCard(o, status, profile, isBooking, isDark, textColor);
                      },
                    );
                  },
                ),
              );

    if (kIsWeb) return Material(color: bgColor, child: bodyContent);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MY MISSIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: bodyContent,
    );
  }

  Widget _buildDeliveryCard(dynamic o, String status, dynamic profile, bool isBooking, bool isDark, Color textColor) {
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
                                    isBooking ? 'MANDI BOOKING' : 'SHOP DISPATCH',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.indigoAccent, letterSpacing: 1),
                                  ),
                                  _statusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Recipient: ${profile?['full_name'] ?? 'Guest'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 6),
                              _rowDetail('PHONE', o['phone_no'] ?? 'N/A', textColor),
                              _rowDetail('ADDRESS', o['delivery_address'] ?? 'Pickup at Store', textColor),
                              if (isBooking) ...[
                                _rowDetail('NEIGHBORHOOD', o['delivery_location'] ?? 'N/A', textColor),
                                _rowDetail('BOOKING DATE', o['booking_date'] ?? 'N/A', Colors.greenAccent),
                              ],
                              const SizedBox(height: 16),
                              if (status != 'Delivered' && status != 'Completed' && status != 'Cancelled') ...[
                                Row(
                                  children: [
                                    if (status == 'Shipped')
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _verifyAndDeliver(o, isDark),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text('VERIFY OTP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _updateStatus(o['id'], 'Shipped'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigoAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text('START SHIFT/PICK UP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                  ),
                ),
              );
  }

  Widget _rowDetail(String label, String val, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(val, style: GoogleFonts.outfit(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c = Colors.grey;
    if (status == 'Delivered' || status == 'Completed') c = Colors.green;
    if (status == 'Shipped') c = Colors.orange;
    if (status == 'Cancelled') c = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
