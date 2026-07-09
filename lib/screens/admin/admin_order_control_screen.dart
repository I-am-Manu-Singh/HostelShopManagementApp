import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/receipt_service.dart';

class AdminOrderControlScreen extends StatefulWidget {
  final bool approvalsOnly;
  final bool hideAppBar;
  final DateTime? initialDate;
  final bool isBookingFilter;
  const AdminOrderControlScreen({
    super.key, 
    this.approvalsOnly = false, 
    this.hideAppBar = false, 
    this.initialDate,
    this.isBookingFilter = false,
  });

  @override
  State<AdminOrderControlScreen> createState() => _AdminOrderControlScreenState();
}

class _AdminOrderControlScreenState extends State<AdminOrderControlScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late RealtimeChannel _channel;
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _orders = [];
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _filterDate = widget.initialDate;
    _tabController = TabController(length: 3, vsync: this);
    _fetchOrders();
    _subscribeToOrders();
  }

  void _subscribeToOrders() {
    _channel = _client.channel('public:shop_orders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'shop_orders', callback: (payload) {
       debugPrint('LOGISTICS UPDATE DETECTED: ${payload.toString()}');
       _fetchOrders();
    }).subscribe();
  }

  @override
  void dispose() {
    _client.removeChannel(_channel);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (_orders.isEmpty) setState(() => _isLoading = true);
    try {
      // 🧠 RESILIENT JOIN: Handles both direct and aliased profile relationships
      final res = await _client.from('shop_orders').select('*, profiles(*)').order('created_at', ascending: false);
      if (mounted) setState(() { _orders = res; _isLoading = false; });
    } catch (e) {
      try {
        final resFallback = await _client.from('shop_orders').select().order('created_at', ascending: false);
        if (mounted) setState(() { _orders = resFallback; _isLoading = false; });
      } catch (e2) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // Use a simplified view if integrating into Approvals Center
    if (widget.approvalsOnly) {
       return _isLoading 
         ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
         : _buildOrdersList(['Placed'], isDark, pendingUpiOnly: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ORDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_suggest_rounded, color: textColor, size: 20),
            onPressed: () => _showSettingsDialog(isDark),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
          labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
             Tab(text: 'NEW'),
             Tab(text: 'READY / SHIP'),
             Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(),
              TabBarView(
  controller: _tabController,
  children: [
    _buildOrdersList(
      ['Placed', 'Confirmed', 'In Process', 'Packing', 'Preparing'],
      isDark,
    ),
    _buildOrdersList(
      ['Ready', 'Shipped'],
      isDark,
    ),
    _buildOrdersList(
      ['Completed', 'Delivered', 'Cancelled', 'Rejected'],
      isDark,
    ),
  ],
),
            ],
          ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildOrdersList(List<String> statuses, bool isDark, {bool pendingUpiOnly = false}) {
    final filtered = _orders.where((o) {
       final matchStatus = statuses.contains(o['order_status'] ?? 'Placed');
       final matchBooking = (o['is_booking'] ?? false) == widget.isBookingFilter;
       if (pendingUpiOnly) {
         return matchStatus && o['payment_method'] == 'UPI' && matchBooking;
       }
       return matchStatus && matchBooking;
     }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text('NO ACTIVE ORDERS DETECTED', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontWeight: FontWeight.bold, fontSize: 12)));
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
          if (crossCount > 1) {
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _buildOrderCard(filtered[i], isDark),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _buildOrderCard(filtered[i], isDark),
          );
        }
      ),
    );
  }

  Widget _buildOrderCard(dynamic o, bool isDark) {
    final profile = o['profiles'];
    final status = o['order_status'] ?? 'Placed';
    final items = o['items'] as List;
    final isUPI = o['payment_method'] == 'UPI';
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(24),
            collapsedIconColor: isDark ? Colors.white24 : Colors.black26,
            iconColor: Colors.pinkAccent,
            title: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), child: Text(profile?['full_name']?[0] ?? 'C', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Row(children: [
                     Text(profile?['full_name'] ?? 'USER', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                     if (o['order_instructions'] != null && o['order_instructions'].toString().isNotEmpty) ...[
                       const SizedBox(width: 8),
                       Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(4)), child: const Text('NOTE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900))),
                     ],
                   ]),
                   Text('ORDER #${o['id'].toString().substring(0,8).toUpperCase()}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                ])),
              ],
            ),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
               Text('₹${(o['total_price'] ?? 0).toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
               _statusBadge(status.toUpperCase(), _getStatusColor(status)),
            ]),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    _detailRow('METHOD', o['delivery_type'] ?? 'Pickup', isDark),
                    _detailRow('PAYMENT', o['payment_method'] ?? 'Wallet', isDark),
                    _detailRow('PHONE', o['phone_no'] ?? 'N/A', isDark),
                    if (o['alt_phone_no'] != null && o['alt_phone_no'].toString().isNotEmpty) _detailRow('ALT_PHONE', o['alt_phone_no'], isDark),
                    if (o['delivery_address'] != null && o['delivery_address'].toString().isNotEmpty) _detailRow('ADDRESS', o['delivery_address'], isDark),
                    if (o['is_booking'] == true) ...[
                      _detailRow('BOOKING DATE', o['booking_date'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(o['booking_date'])) : 'N/A', isDark, color: Colors.indigoAccent),
                      _detailRow('ADVANCE PAID', '₹${o['advance_paid'] ?? 0.0}', isDark, color: Colors.green),
                      _detailRow('USER TYPE', (o['user_type'] ?? 'domestic').toString().toUpperCase(), isDark),
                      if (o['delivery_location'] != null && o['delivery_location'].toString().isNotEmpty)
                        _detailRow('LOCATION', o['delivery_location'], isDark),
                    ],
                    if (o['order_instructions'] != null && o['order_instructions'].toString().isNotEmpty)
                      _detailRow('INSTRUCTIONS', o['order_instructions'], isDark, color: Colors.pinkAccent),
                    if (o['delivery_otp'] != null && status != 'Completed' && status != 'Delivered')
                      _detailRow('VERIF. OTP', o['delivery_otp'].toString(), isDark, color: Colors.indigoAccent),
                    if (o['estimated_delivery'] != null) _detailRow('ETA', DateFormat('MMM dd, hh:mm a').format(DateTime.parse(o['estimated_delivery'])), isDark, color: Colors.amberAccent),
                    const SizedBox(height: 16),
                    if (isUPI && o['upi_screenshot_url'] != null) ...[
                       Text('PAYMENT VOUCHER', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                       const SizedBox(height: 12),
                       GestureDetector(
                         onTap: () => _showScreenshotDialog(o['upi_screenshot_url']),
                         child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined, color: Colors.indigoAccent), SizedBox(width: 12), Text('VIEW UPI RECEIPT', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold))]))),
                       ),
                       const SizedBox(height: 16),
                    ],
                    /// 🔥 ADMIN STATUS WORKFLOW
                    if (status == 'Placed' && isUPI) ...[
                       const SizedBox(height: 12),
                       Row(children: [
                         Expanded(child: ElevatedButton(onPressed: () => _updateStatus(o['id'], 'Confirmed'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent), child: const Text('AUTHORIZE PAYMENT', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)))),
                         const SizedBox(width: 8),
                         Expanded(child: OutlinedButton(onPressed: () => _updateStatus(o['id'], 'Failed'), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)), child: const Text('FAIL ORDER', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)))),
                       ]),
                       const SizedBox(height: 24),
                    ],

                    Text('ORDER ITEMS', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                          Text(it['name'] ?? 'ITEM', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          Text('₹${it['price'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ]),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Invoice PDF...')));
                          try {
                            // Import of ReceiptService might be missing, so we'll check it
                            await ReceiptService.generateAndShareReceipt(o);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        },
                        icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 16),
                        label: const Text('DOWNLOAD INVOICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildActionButtons(o, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(dynamic o, bool isDark) {
    final status = o['order_status'] ?? 'Placed';
    if (status == 'Completed' || status == 'Delivered' || status == 'Cancelled') return const SizedBox.shrink();

    String nextLabel = 'MARK PREPARING';
    String nextStatus = 'Preparing';
    Color btnColor = Colors.indigoAccent;

    if (status == 'Placed') { nextLabel = 'MARK PREPARING'; nextStatus = 'Preparing'; }
    else if (status == 'Preparing') { nextLabel = 'MARK READY'; nextStatus = 'Ready'; btnColor = Colors.blueAccent; }
    else if (status == 'Ready') { nextLabel = 'MARK DISPATCHED'; nextStatus = 'Shipped'; btnColor = Colors.orangeAccent; }
    else if (status == 'Shipped') { nextLabel = 'MARK DELIVERED'; nextStatus = 'Delivered'; btnColor = Colors.greenAccent; }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (nextStatus == 'Delivered') {
                    _verifyAndDelivery(o, isDark);
                  } else {
                    _updateStatus(o['id'], nextStatus);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: btnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(nextLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                onSelected: (val) => _updateStatus(o['id'], val),
                itemBuilder: (ctx) => [
                  'Confirmed', 'In Process', 'Packing', 'Ready', 'Shipped', 'Delivered', 'Completed', 'Rejected', 'Cancelled'
                ].map((s) => PopupMenuItem(value: s, child: Text(s.toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)))).toList(),
              ),
            ),
          ],
        ),
        if (o['delivery_type'] == 'Home Delivery' || o['delivery_type'] == null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setDeliveryTime(o['id'], isDark),
                  icon: const Icon(Icons.timer_outlined, size: 16, color: Colors.amberAccent),
                  label: const Text('SET ETA', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amberAccent), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _assignDeliveryPartner(o['id'], isDark),
                  icon: const Icon(Icons.delivery_dining_rounded, size: 16, color: Colors.greenAccent),
                  label: const Text('ASSIGN PARTNER', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.greenAccent), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setDeliveryTime(String id, bool isDark) async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent, brightness: isDark ? Brightness.dark : Brightness.light)), child: child!));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    final target = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await _client.from('shop_orders').update({'estimated_delivery': target.toIso8601String()}).eq('id', id);
      _fetchOrders();
    } catch (_) {}
  }

  Widget _statusBadge(String label, Color c) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text(label, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)));
  }

   Color _getStatusColor(String s) {
      if (s == 'Confirmed') return Colors.tealAccent;
      if (s == 'In Process' || s == 'Preparing') return Colors.indigoAccent;
      if (s == 'Packing') return Colors.amberAccent;
      if (s == 'Ready') return Colors.blueAccent;
      if (s == 'Shipped') return Colors.orangeAccent;
      if (s == 'Delivered' || s == 'Completed') return Colors.greenAccent;
      if (s == 'Rejected' || s == 'Cancelled') return Colors.redAccent;
      return Colors.white24;
   }

  Widget _detailRow(String label, String val, bool isDark, {Color color = Colors.white70}) {
    final defaultColor = isDark ? Colors.white70 : Colors.black87;
    final labelColor = isDark ? Colors.white24 : Colors.black26;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text(label, style: TextStyle(color: labelColor, fontSize: 9, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Expanded(child: Text(val, style: TextStyle(color: color == Colors.white70 ? defaultColor : color, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right))]));
  }

  void _showScreenshotDialog(String url) {
    showDialog(context: context, builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Dialog(backgroundColor: Colors.transparent, child: Column(mainAxisSize: MainAxisSize.min, children: [ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(url, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text('LOAD ERROR', style: TextStyle(color: Colors.white))))), const SizedBox(height: 16), ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: const Text('DISMISS', style: TextStyle(color: Colors.white)))]))));
  }

  Future<void> _updateStatus(dynamic id, String status) async {
    try {
      await _client.from('shop_orders').update({'order_status': status}).eq('id', id);
      _fetchOrders();
    } catch (_) {}
  }

  Future<void> _verifyAndDelivery(dynamic o, bool isDark) async {
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
              Text('Ask the customer or alternate receiver for their 4-digit Collection OTP.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
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

  Future<void> _showSettingsDialog(bool isDark) async {
    final settings = await _client.from('app_settings').select('value').eq('key', 'delivery_charge').maybeSingle();
    final TextEditingController chargeCtrl = TextEditingController(text: (settings?['value'] ?? 20.0).toString());

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Text('LOGISTICS SETTINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STANDARD DELIVERY FEE (₹)', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 12),
            TextField(
              controller: chargeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
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
            onPressed: () async {
              try {
                final val = double.tryParse(chargeCtrl.text);
                if (val == null) return;
                await _client.from('app_settings').upsert({'key': 'delivery_charge', 'value': val});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOGISTICS UPDATED'), backgroundColor: Colors.greenAccent));
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: const Text('SAVE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Future<void> _assignDeliveryPartner(String orderId, bool isDark) async {
    try {
      final partners = await _client.from('profiles').select('id, full_name').eq('role', 'delivery_partner');
      if (!mounted) return;
      if (partners.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NO DELIVERY PARTNERS REGISTERED IN SYSTEM'), backgroundColor: Colors.orangeAccent),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('ASSIGN DELIVERY AGENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: partners.length,
              itemBuilder: (c, idx) {
                final p = partners[idx];
                return ListTile(
                  title: Text(p['full_name'] ?? 'Agent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.send_rounded, color: Colors.greenAccent, size: 18),
                  onTap: () async {
                    try {
                      await _client.from('shop_orders').update({
                        'delivery_partner_id': p['id'],
                        'order_status': 'Shipped',
                      }).eq('id', orderId);
                      Navigator.pop(ctx);
                      _fetchOrders();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Order assigned to ${p['full_name']}'), backgroundColor: Colors.green),
                      );
                    } catch (err) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to assign partner: $err'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading partners: $e');
    }
  }
}
