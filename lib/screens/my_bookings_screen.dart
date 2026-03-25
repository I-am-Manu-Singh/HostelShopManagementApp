import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';
import 'room_detail_screen.dart';

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
      final shopRes = await _client.from('shop_orders').select('*').eq('user_id', user.id).order('created_at', ascending: false);
      
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
      backgroundColor: const Color(0xFF0F172A),
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
          decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
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
               Text('FISCAL BREAKDOWN', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
               const SizedBox(height: 32),
               Text('TRANSACTION DEBRIEF', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
               const SizedBox(height: 8),
               Text('Inventory Acquisition Log', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 40),
               _debriefRow('ORDER ID', o['id'].toString().toUpperCase()),
               _debriefRow('TIMESTAMP', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(o['created_at']))),
               _debriefRow('TERMINAL', 'Campus Express Main'),
               const Divider(height: 48, color: Colors.white10),
               Text('ACQUIRED ASSETS', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
               const SizedBox(height: 20),
               Expanded(child: ListView(children: [
                   _priceRow('Campus Water (x2)', '₹40'),
                   _priceRow('Protein Bar (x1)', '₹120'),
                   _priceRow('Stationary Pack', '₹200'),
               ])),
               const Divider(height: 48, color: Colors.white10),
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL VOLUME', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.w900)),
                  Text('₹${o['total_price']}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
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
