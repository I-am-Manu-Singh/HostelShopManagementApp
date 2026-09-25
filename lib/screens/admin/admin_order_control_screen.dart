import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../services/receipt_service.dart';
import '../../services/pos_hardware_service.dart';
import '../../services/organization_settings_service.dart';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

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
  late bool _isBookingFilter;

  @override
  void initState() {
    super.initState();
    _isBookingFilter = widget.isBookingFilter;
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

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportOrdersToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: _isBookingFilter ? 'Mandi Bookings' : 'Campus Shop Orders',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      final headers = ['Order ID', 'Customer Name', 'Total Price (₹)', 'Payment Method', 'Status', 'Booking Mode', 'Created At'];
      buffer.writeln(headers.join(','));

      final filtered = _orders.where((o) {
        final matchBooking = (o['is_booking'] ?? false) == _isBookingFilter;
        if (!matchBooking) return false;
        if (o['created_at'] != null) {
          final dt = DateTime.tryParse(o['created_at'].toString());
          if (dt != null) {
            return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
          }
        }
        return true;
      }).toList();

      for (var o in filtered) {
        final profile = o['profiles'] ?? {};
        final List<String> row = [
          o['id']?.toString() ?? '',
          '"${(profile['full_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          (o['total_price'] ?? 0.0).toString(),
          o['payment_method']?.toString() ?? 'N/A',
          o['order_status']?.toString() ?? 'Placed',
          (_isBookingFilter ? 'Mandi' : 'Shop'),
          o['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = '${_isBookingFilter ? "mandi" : "shop"}_orders_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Orders CSV Export');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importOrdersFromCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: _isBookingFilter ? 'Mandi Bookings' : 'Campus Shop Orders',
      isImport: true,
    );
    if (range == null) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null) return;

      List<String> lines;
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes == null) return;
        lines = utf8.decode(bytes).split('\n');
      } else {
        if (result.files.single.path == null) return;
        lines = await File(result.files.single.path!).readAsLines();
      }

      if (lines.length < 2) return;

      int successCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cells = line.split(',');
        if (cells.length < 5) continue;

        final orderId = cells[0].trim();
        final status = cells[4].trim();

        if (orderId.isNotEmpty && orderId.length > 5) {
          await _client.from('shop_orders').update({
            'order_status': status,
          }).eq('id', orderId);
          successCount++;
        }
      }

      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated $successCount orders from CSV successfully.'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    if (widget.approvalsOnly) {
       return _isLoading 
         ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
         : _buildOrdersList(['Placed'], isDark, pendingUpiOnly: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ORDERS HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importOrdersFromCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportOrdersToCSV, tooltip: 'Export CSV'),
          IconButton(icon: Icon(Icons.settings_suggest_rounded, color: textColor, size: 20), onPressed: () => _showSettingsDialog(isDark)),
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
        : Column(
            children: [
              // Sliding toggle filter between Campus Shop and Mandi Orders
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isBookingFilter = false),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_isBookingFilter ? Colors.pinkAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'CAMPUS SHOP',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: !_isBookingFilter ? Colors.white : (isDark ? Colors.white38 : Colors.black45),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isBookingFilter = true),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _isBookingFilter ? Colors.pinkAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'MANDI BOOKINGS',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: _isBookingFilter ? Colors.white : (isDark ? Colors.white38 : Colors.black45),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
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
       final matchBooking = (o['is_booking'] ?? false) == _isBookingFilter;
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
    final profile = o['profiles'] is Map ? o['profiles'] : null;
    final status = o['order_status'] ?? 'Placed';
    final items = (o['items'] as List?) ?? [];
    final isUPI = o['payment_method'] == 'UPI';

    // Intelligent customer name resolution
    String customerName = 'CUSTOMER';
    if (profile != null && profile['full_name'] != null && profile['full_name'].toString().trim().isNotEmpty) {
      customerName = profile['full_name'].toString().trim();
    } else if (o['customer_name'] != null && o['customer_name'].toString().trim().isNotEmpty) {
      customerName = o['customer_name'].toString().trim();
    } else if (o['phone_no'] != null && o['phone_no'].toString().trim().isNotEmpty) {
      customerName = 'PH: ${o['phone_no']}';
    } else if (o['user_type'] != null && o['user_type'].toString().trim().isNotEmpty) {
      customerName = '${o['user_type'].toString().toUpperCase()} CLIENT';
    } else if (o['user_id'] != null) {
      final uid = o['user_id'].toString();
      customerName = 'UID: ${uid.length > 8 ? uid.substring(0, 8) : uid}';
    }

    final initial = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C';
    
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
                CircleAvatar(radius: 20, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), child: Text(initial, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Row(children: [
                     Flexible(
                       child: Text(customerName, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                     ),
                     if (o['order_instructions'] != null && o['order_instructions'].toString().isNotEmpty) ...[
                       const SizedBox(width: 8),
                       Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Text('ALERT', style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold))),
                     ],
                   ]),
                   Row(
                     children: [
                       Text('Order Total: ₹${o['total_price']}', style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                       if (o['phone_no'] != null && o['phone_no'].toString().isNotEmpty) ...[
                         const SizedBox(width: 8),
                         Text('•  ${o['phone_no']}', style: GoogleFonts.outfit(fontSize: 11, color: Colors.indigoAccent)),
                       ],
                     ],
                   ),
                ])),
              ],
            ),
            subtitle: Container(
              margin: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (status == 'Placed' || status == 'Pending') ? Colors.orangeAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: TextStyle(
                        color: (status == 'Placed' || status == 'Pending') ? Colors.orangeAccent : Colors.greenAccent.shade700,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (o['payment_method'] ?? 'CASH').toString().toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 32),
                    Text('ITEMS ORDERED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pinkAccent, letterSpacing: 1)),
                    const SizedBox(height: 12),
                     ...items.map((it) {
                       final qty = it['qty'] ?? it['quantity'] ?? 1;
                       final price = it['price'] ?? 0.0;
                       return Padding(
                         padding: const EdgeInsets.symmetric(vertical: 4),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text('${it['name'] ?? 'Item'} x$qty', style: const TextStyle(fontSize: 13)),
                             Text('₹${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                           ],
                         ),
                       );
                     }),
                    if (isUPI) ...[
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('UPI TRANSACTION ATTACHMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.receipt_long_rounded, color: Colors.pinkAccent),
                            onPressed: () {
                              ReceiptService.generateAndShareReceipt(o);
                            },
                          ),
                        ],
                      ),
                    ],
                    if (o['order_instructions'] != null && o['order_instructions'].toString().isNotEmpty) ...[
                      const Divider(height: 32),
                      Text('DELIVERY INSTRUCTIONS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orangeAccent, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(o['order_instructions'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ReceiptService.generateAndShareReceipt(o);
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: const Text('A4 INVOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigoAccent,
                              side: const BorderSide(color: Colors.indigoAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final items = (o['items'] as List? ?? []).map((it) => PosReceiptItem(
                                name: it['name']?.toString() ?? 'Item',
                                quantity: (it['quantity'] ?? it['qty'] ?? 1) as int,
                                unitPrice: (it['price'] as num? ?? 0.0).toDouble(),
                                totalPrice: ((it['quantity'] ?? it['qty'] ?? 1) as int) * (it['price'] as num? ?? 0.0).toDouble(),
                              )).toList();

                              final total = (o['total_price'] as num? ?? 0.0).toDouble();
                              final receiptData = PosReceiptData(
                                storeName: PosHardwareService().storeName,
                                storeAddress: PosHardwareService().storeAddress,
                                storeGstin: PosHardwareService().storeGstin,
                                storePhone: PosHardwareService().storePhone,
                                invoiceNumber: "INV-${o['id'].toString().substring(0, 8).toUpperCase()}",
                                dateTime: DateTime.tryParse(o['created_at']?.toString() ?? '') ?? DateTime.now(),
                                customerName: o['profiles']?['full_name']?.toString() ?? 'Customer',
                                items: items,
                                subtotal: total,
                                total: total,
                                paymentMode: (o['payment_status'] ?? 'paid').toString().toLowerCase(),
                                templateStyle: PosHardwareService().templateStyle,
                                footerNote: PosHardwareService().footerNote,
                              );

                              final success = await PosHardwareService().printThermalReceipt(receiptData);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Thermal ticket sent to printer' : 'Print canceled'),
                                    backgroundColor: success ? Colors.green : Colors.orange,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.print_rounded, size: 16, color: Colors.black),
                            label: const Text('THERMAL POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black, letterSpacing: 0.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'Placed')
                          ElevatedButton(
                            onPressed: () async {
                              await _client.from('shop_orders').update({'order_status': 'Confirmed'}).eq('id', o['id']);
                              _fetchOrders();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                            child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        if (status == 'Confirmed' || status == 'In Process' || status == 'Preparing' || status == 'Packing')
                          ElevatedButton(
                            onPressed: () async {
                              await _client.from('shop_orders').update({'order_status': 'Ready'}).eq('id', o['id']);
                              _fetchOrders();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('MARK READY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        if (status == 'Ready')
                          ElevatedButton(
                            onPressed: () => _assignDeliveryPartner(o['id'], isDark),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent.shade700),
                            child: const Text('ASSIGN DELIVERY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        if (status == 'Shipped')
                          ElevatedButton(
                            onPressed: () async {
                              await _client.from('shop_orders').update({'order_status': 'Completed'}).eq('id', o['id']);
                              _fetchOrders();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700),
                            child: const Text('DELIVERED', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
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

  void _showSettingsDialog(bool isDark) async {
    final chargeCtrl = TextEditingController();
    List<Map<String, dynamic>> rules = [];
    try {
      final res = await _client.from('app_settings').select('value').eq('key', 'delivery_charge').maybeSingle();
      if (res != null) chargeCtrl.text = res['value'].toString();

      final rulesRes = await _client.from('app_settings').select('value').eq('key', 'logistics_rules').maybeSingle();
      if (rulesRes != null && rulesRes['value'] != null) {
        rules = OrganizationSettingsService.parseRules(rulesRes['value']);
      }
    } catch (_) {}

    if (!mounted) return;

    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LOGISTICS & SURCHARGES', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text('FEE & FESTIVAL OFFERS', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: textColor.withOpacity(0.6),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Standard Delivery Fee Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('BASE DELIVERY FEE (₹)', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: chargeCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                        decoration: InputDecoration(
                          hintText: '20',
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                // Custom Logistics Rules & Festival Offers Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('OCCASIONAL OFFERS / CHARGES', style: GoogleFonts.outfit(color: textColor.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    TextButton.icon(
                      onPressed: () {
                        _showAddRuleDialog(isDark, (newRule) {
                          setSheetState(() {
                            rules.add(newRule);
                          });
                        });
                      },
                      icon: const Icon(Icons.add, size: 16, color: Colors.pinkAccent),
                      label: const Text('ADD RULE', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: rules.isEmpty
                      ? Center(child: Text('No active festival/occasional rules set.', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: rules.length,
                          itemBuilder: (c, idx) {
                            final r = rules[idx];
                            final isDiscount = r['type'] == 'discount';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDiscount ? Colors.greenAccent.withOpacity(0.3) : Colors.orangeAccent.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDiscount ? Colors.greenAccent.withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isDiscount ? Icons.local_offer_rounded : Icons.flash_on_rounded,
                                      size: 16,
                                      color: isDiscount ? Colors.greenAccent : Colors.orangeAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r['name'] ?? 'Custom Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                        Text('${isDiscount ? "Discount" : "Charge"}: ₹${r['amount']} • Applies: ${(r['applies_to'] ?? 'all').toString().toUpperCase()}',
                                            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10)),
                                        if (r['start_date'] != null || r['end_date'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Period: ${r['start_date'] != null ? DateFormat('dd MMM').format(DateTime.parse(r['start_date'])) : 'Any'} → ${r['end_date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['end_date'])) : 'Ongoing'}',
                                              style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: r['enabled'] == true,
                                    activeColor: Colors.pinkAccent,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        rules[idx]['enabled'] = val;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () {
                                      setSheetState(() {
                                        rules.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final val = double.tryParse(chargeCtrl.text) ?? 20.0;
                        try {
                          await _client.from('app_settings').upsert({'key': 'delivery_charge', 'value': val});
                          await _client.from('app_settings').upsert({'key': 'logistics_rules', 'value': rules});
                        } catch (_) {
                          // Fallback if column 'value' is of type text
                          await _client.from('app_settings').upsert({'key': 'delivery_charge', 'value': val.toString()});
                          await _client.from('app_settings').upsert({'key': 'logistics_rules', 'value': jsonEncode(rules)});
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOGISTICS & FESTIVAL RULES UPDATED'), backgroundColor: Colors.greenAccent));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.redAccent));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('SAVE PARAMETERS & OFFERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddRuleDialog(bool isDark, Function(Map<String, dynamic>) onAdd) {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String ruleType = 'discount'; // or 'charge'
    String appliesTo = 'all'; // 'all', 'delivery_only', 'takeaway_only', 'domestic', 'commercial'
    DateTime? startDate;
    DateTime? endDate;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2024) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('ADD SPECIAL OFFER / SURCHARGE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Offer / Surcharge Title (e.g. Diwali Discount, Monsoon Fee)',
                    labelStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Adjustment Amount (₹)',
                    labelStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: ruleType,
                  dropdownColor: isDark ? const Color(0xFF26282E) : Colors.white,
                  decoration: const InputDecoration(labelText: 'Adjustment Type'),
                  items: const [
                    DropdownMenuItem(value: 'discount', child: Text('Discount (-₹ Off Total)')),
                    DropdownMenuItem(value: 'charge', child: Text('Added Surcharge (+₹ To Total)')),
                  ],
                  onChanged: (v) => setDState(() => ruleType = v ?? 'discount'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: appliesTo,
                  dropdownColor: isDark ? const Color(0xFF26282E) : Colors.white,
                  decoration: const InputDecoration(labelText: 'Where To Apply'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Orders & Customers')),
                    DropdownMenuItem(value: 'delivery_only', child: Text('Home Delivery Only')),
                    DropdownMenuItem(value: 'takeaway_only', child: Text('Takeaway Orders Only')),
                    DropdownMenuItem(value: 'domestic', child: Text('Domestic / Student Only')),
                    DropdownMenuItem(value: 'commercial', child: Text('Commercial Clients Only')),
                  ],
                  onChanged: (v) => setDState(() => appliesTo = v ?? 'all'),
                ),
                const SizedBox(height: 16),
                // Offer Period Date Pickers
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 14),
                        label: Text(
                          startDate == null ? 'Start Date' : DateFormat('dd MMM yyyy').format(startDate!),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setDState(() => startDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 14),
                        label: Text(
                          endDate == null ? 'End Date' : DateFormat('dd MMM yyyy').format(endDate!),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? (startDate ?? DateTime.now()),
                            firstDate: startDate ?? DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setDState(() => endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amtCtrl.text);
                if (nameCtrl.text.trim().isEmpty || amt == null) return;
                onAdd({
                  'name': nameCtrl.text.trim(),
                  'amount': amt,
                  'type': ruleType,
                  'applies_to': appliesTo,
                  'start_date': startDate?.toIso8601String(),
                  'end_date': endDate?.toIso8601String(),
                  'enabled': true,
                });
                Navigator.pop(dCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              child: const Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
