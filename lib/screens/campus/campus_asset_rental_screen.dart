import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class CampusAssetRentalScreen extends StatefulWidget {
  const CampusAssetRentalScreen({super.key});

  @override
  State<CampusAssetRentalScreen> createState() => _CampusAssetRentalScreenState();
}

class _CampusAssetRentalScreenState extends State<CampusAssetRentalScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rentals = [];

  @override
  void initState() {
    super.initState();
    _fetchRentals();
  }

  Future<void> _fetchRentals() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      // Mocking or fetching from asset_rentals if exists
      final res = await _client.from('asset_rentals').select('*, assets(*)').eq('user_id', user.id).order('issue_date', ascending: false);
      if (mounted) {
        setState(() {
          _rentals = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReserveModal() async {
    // Premium Mock for Asset Selection
    final List<Map<String, dynamic>> mockAssets = [
      {'id': '1', 'name': 'Speedster Cycle', 'price': 50, 'icon': Icons.pedal_bike_rounded},
      {'id': '2', 'name': 'Iron Box Pro', 'price': 20, 'icon': Icons.iron_rounded},
      {'id': '3', 'name': 'Vacuum Cleaner', 'price': 30, 'icon': Icons.cleaning_services_rounded},
      {'id': '4', 'name': 'Tennis Kit', 'price': 40, 'icon': Icons.sports_tennis_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(color: Color(0xFF16181A), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
               const SizedBox(height: 32),
               Text('ASSET ACQUISITION', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
               const SizedBox(height: 8),
               Text('Reserve Campus Equipment', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 40),
               Expanded(child: ListView.builder(
                 itemCount: mockAssets.length,
                 itemBuilder: (context, i) {
                    final a = mockAssets[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                      child: Row(children: [
                         Icon(a['icon'] as IconData, color: Colors.indigoAccent),
                         const SizedBox(width: 16),
                         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                             Text(a['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             Text('₹${a['price']}/hour', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                         ])),
                         ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('RESERVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      ]),
                    );
                 },
               )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        title: Text('RENTAL TERMINAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildBackgroundGlow(),
              ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _rentals.length,
                itemBuilder: (context, i) => _buildRentalCard(_rentals[i]),
              ),
              if (_rentals.isEmpty) _buildEmptyState(),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReserveModal,
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
        label: Text('NEW RESERVATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(bottom: -100, left: -100, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildRentalCard(dynamic r) {
    final bool isReturned = r['status'] == 'returned';
    final asset = r['assets'];
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.inventory_2_outlined, color: Colors.indigoAccent, size: 24)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(asset?['name'] ?? 'CAMPUS ASSET', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('ISSUED: ${DateFormat('dd MMM').format(DateTime.parse(r['issue_date']))}', style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ])),
                  _statusBadge(isReturned ? 'RETURNED' : 'ISSUED', isReturned ? Colors.greenAccent : Colors.orangeAccent),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 _infoCell('TOTAL FEE', '₹${r['total_price']}', Icons.payments_outlined),
                 _infoCell('SECURITY', 'WAIVED', Icons.verified_user_outlined),
                 _infoCell('ID', r['id'].toString().substring(0,6).toUpperCase(), Icons.qr_code_rounded),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color c) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.3))), child: Text(label, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)));
  }

  Widget _infoCell(String label, String value, IconData icon) {
    return Column(children: [Icon(icon, size: 14, color: Colors.indigoAccent), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.bold)), Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70))]);
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.history_rounded, size: 60, color: Colors.white10), const SizedBox(height: 20), const Text('No rental history found.', style: TextStyle(color: Colors.white24, fontSize: 13))]));
  }
}
