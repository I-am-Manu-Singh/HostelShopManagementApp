import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../social/chat_screen.dart';
import '../../services/receipt_service.dart';
import '../../services/pos_hardware_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _hostelBookings = [];
  List<dynamic> _shopOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final hostelRes = await _client.from('hostel_enrollments').select('*, hostel_rooms(*)').eq('user_id', user.id).order('created_at', ascending: false);
      final shopRes = await _client.from('shop_orders').select('*, delivery_partner:profiles!delivery_partner_id(*)').eq('user_id', user.id).order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _hostelBookings = hostelRes;
          _shopOrders = shopRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        title: Text('MISSION LOGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white24,
          labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ENROLLMENTS'),
            Tab(text: 'SHOP ORDERS'),
            Tab(text: 'WISHLIST'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildEnrollmentsList(),
              _buildShopOrdersList(),
              _buildWishlist(),
            ],
          ),
    );
  }

  Widget _buildEnrollmentsList() {
    if (_hostelBookings.isEmpty) return _buildEmptyState('No active enrollments found.');
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _hostelBookings.length,
      itemBuilder: (context, i) => FadeInUp(
        delay: Duration(milliseconds: i * 100),
        child: _buildEnrollmentCard(_hostelBookings[i]),
      ),
    );
  }

  Widget _buildEnrollmentCard(dynamic b) {
    final room = b['hostel_rooms'];
    return GestureDetector(
      onTap: () => _showEnrollmentDebrief(b, room),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Image.network(
                    room['image_url'] ?? 'https://images.unsplash.com/photo-1555854817-5b273417735e',
                    height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(height: 160, color: Colors.indigoAccent.withOpacity(0.1), child: const Icon(Icons.bed_rounded, color: Colors.indigoAccent, size: 40)),
                  ),
                ),
                Positioned(top: 16, right: 16, child: _statusTag(b['payment_status'])),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(children: [
                      Text('Unit ${room['room_number']}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('₹${b['total_price']}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -1)),
                   ]),
                   const SizedBox(height: 6),
                   // 🧠 Corrected to 'building'
                   Text('${room['building'] ?? 'General Building'} • ${room['room_type'] ?? 'Standard'}', style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                   const Divider(height: 48, color: Colors.white10),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        _miniCol('CHECK-IN', DateFormat('dd MMM').format(DateTime.parse(b['created_at']))),
                        _miniCol('DURATION', '1 Semester'),
                        _miniCol('LEVEL', 'Premium'),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CampusChatScreen(roomId: b['id'], title: 'Room ${room['room_number']} Chat'))),
                          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.forum_outlined, color: Colors.indigoAccent, size: 18)),
                        ),
                     ],
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopOrdersList() {
    if (_shopOrders.isEmpty) return _buildEmptyState('No shop orders registered.');
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _shopOrders.length,
      itemBuilder: (context, i) => FadeInUp(
        delay: Duration(milliseconds: i * 100),
        child: _buildOrderCard(_shopOrders[i]),
      ),
    );
  }

  Widget _buildOrderCard(dynamic o) {
    return GestureDetector(
      onTap: () => _showOrderDebrief(o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.04))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.shopping_bag_outlined, color: Colors.pinkAccent, size: 18)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ORDER #${o['id'].toString().substring(0, 8).toUpperCase()}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(DateFormat('MMM dd • HH:mm').format(DateTime.parse(o['created_at'])), style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${o['total_price']}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              const Text('PAID', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlist() {
    return _buildEmptyState('Tactical wishlist is currently empty.');
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.query_builder_rounded, size: 60, color: Colors.white10), const SizedBox(height: 20), Text(msg, style: const TextStyle(color: Colors.white24, fontSize: 13))]));
  }

  Widget _statusTag(String status) {
    final bool ok = status == 'Approved';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ok ? Colors.greenAccent : Colors.orangeAccent, borderRadius: BorderRadius.circular(10)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)));
  }

  Widget _miniCol(String label, String val) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    ]);
  }

  void _showEnrollmentDebrief(dynamic b, dynamic room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(color: Color(0xFF16181A), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
               const SizedBox(height: 32),
               Text('ENROLLMENT DEBRIEF', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
               const SizedBox(height: 8),
               Text('Operational Intelligence Log', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 40),
               _debriefRow('DEPLOYMENT', 'Room ${room['room_number']}'),
               // 🧠 Building mapping
               _debriefRow('BUILDING', room['building'] ?? 'N/A'),
               _debriefRow('PERSONNEL ID', b['user_id'].toString().substring(0,12).toUpperCase()),
               _debriefRow('STATUS', b['payment_status']),
               const Divider(height: 48, color: Colors.white10),
               Text('PAYMENT DETAILS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
               const SizedBox(height: 20),
               _priceRow('Base Enrollment', '₹${b['total_price']}'),
               _priceRow('Security Deposit', '₹2000'),
               _priceRow('Mess Surcharge', '₹1500'),
               const Spacer(),
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL ARREARS', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.w900)),
                  Text('₹0.00', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.w900)),
               ]),
               const SizedBox(height: 20),
               SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text('DISMISS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)))),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDebrief(dynamic o) {
    final items = o['items'] as List;
    final partner = o['delivery_partner'];
    final address = o['delivery_address'] ?? 'N/A';
    final location = o['delivery_location'] ?? 'N/A';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: Color(0xFF08090A), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
               const SizedBox(height: 24),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('ORDER LOGISTICS', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                       Text('Order Details', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                     ],
                   ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_rounded, color: Colors.amberAccent, size: 26),
                          tooltip: 'Print Thermal Ticket',
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
                              customerName: 'Customer',
                              items: items,
                              subtotal: total,
                              total: total,
                              paymentMode: (o['payment_status'] ?? 'paid').toString().toLowerCase(),
                              templateStyle: PosHardwareService().templateStyle,
                              footerNote: PosHardwareService().footerNote,
                            );

                            await PosHardwareService().printThermalReceipt(receiptData);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_for_offline_rounded, color: Colors.greenAccent, size: 28),
                          tooltip: 'A4 PDF Invoice',
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Invoice PDF...')));
                            try {
                              await ReceiptService.generateAndShareReceipt(o);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                 ],
               ),
               const SizedBox(height: 24),
               Expanded(
                 child: ListView(
                   children: [
                     // 📍 MAP LOCATION CONTAINER
                     Container(
                       height: 140,
                       width: double.infinity,
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.02),
                         borderRadius: BorderRadius.circular(24),
                         border: Border.all(color: Colors.white.withOpacity(0.05)),
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(24),
                         child: Stack(
                           children: [
                             // Simple abstract grid representing a map
                             Positioned.fill(
                               child: Opacity(
                                 opacity: 0.15,
                                 child: GridView.builder(
                                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                                   itemBuilder: (context, index) => Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 0.5))),
                                 ),
                               ),
                             ),
                             Center(
                               child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   const Icon(Icons.map_rounded, color: Colors.pinkAccent, size: 36),
                                   const SizedBox(height: 8),
                                   Text(
                                     'DELIVERY TRACKER: $location',
                                     style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                   ),
                                   Text(
                                     address,
                                     style: const TextStyle(color: Colors.white30, fontSize: 9),
                                   )
                                 ],
                               ),
                             )
                           ],
                         ),
                       ),
                     ),
                     const SizedBox(height: 24),
                     
                     // 🤝 ASSIGNED DELIVERY PARTNER CARD
                     Text('DELIVERY TEAM', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                     const SizedBox(height: 12),
                     Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.02),
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: Colors.white.withOpacity(0.05)),
                       ),
                       child: Row(
                         children: [
                           CircleAvatar(
                             radius: 20,
                             backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                             child: const Icon(Icons.person_pin_rounded, color: Colors.indigoAccent),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   partner?['full_name'] ?? 'Assigning Logistics Agent...',
                                   style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                 ),
                                 Text(
                                   partner != null ? 'Contact: ${partner['phone_no'] ?? 'N/A'}' : 'Standard Route Delivery',
                                   style: const TextStyle(color: Colors.white24, fontSize: 10),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 24),

                     Text('ITEMS LOG', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                     const SizedBox(height: 12),
                     ...items.map((it) {
                       final qty = (it['qty'] as num).toInt();
                       final wQty = it['weight_qty'] != null ? (it['weight_qty'] as num).toDouble() : null;
                       final wUnit = it['weight_unit']?.toString();
                       
                       String qtyWeightStr = qty.toString();
                       if (wQty != null && wQty != 1.0) {
                         qtyWeightStr = '$qty x ${wQty} ${wUnit ?? 'kg'}';
                       }
                       
                       return Container(
                         margin: const EdgeInsets.only(bottom: 10),
                         padding: const EdgeInsets.all(14),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.01),
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Colors.white.withOpacity(0.03)),
                         ),
                         child: Row(
                           children: [
                             Text(qtyWeightStr, style: GoogleFonts.outfit(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 13)),
                             const SizedBox(width: 16),
                             Expanded(child: Text(it['name'] ?? 'Shop Item', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                             Text('₹${it['price'] ?? 0}', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                           ],
                         ),
                       );
                     }).toList(),
                     const SizedBox(height: 12),
                   ],
                 ),
               ),
               const Divider(height: 32, color: Colors.white10),
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL PAYABLE', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w900)),
                  Text('₹${o['total_price']}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
               ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debriefRow(String label, String val) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]));
  }

  Widget _priceRow(String label, String val) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)), Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]));
  }
}
