import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminFleetConsoleScreen extends StatefulWidget {
  const AdminFleetConsoleScreen({super.key});

  @override
  State<AdminFleetConsoleScreen> createState() => _AdminFleetConsoleScreenState();
}

class _AdminFleetConsoleScreenState extends State<AdminFleetConsoleScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _vans = [];
  List<dynamic> _logs = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchConsoleData();
  }

  Future<void> _fetchConsoleData() async {
    setState(() => _isLoading = true);
    try {
      final vansRes = await _client.from('vans').select();
      final logsRes = await _client.from('van_logs').select('*, profiles(full_name), vans(*)').order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _vans = vansRes;
          _logs = logsRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewVan(String number, String name) async {
    try {
      await _client.from('vans').insert({
        'van_number': number.toUpperCase(),
        'driver_name': name,
        'is_active': true,
      });
      _fetchConsoleData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding van: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showAddVanModal(bool isDark) {
    final numCtrl = TextEditingController();
    final driverCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(c).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADD NEW VEHICLE', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 20),
            TextField(controller: numCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(labelText: 'VEHICLE NUMBER (e.g. MH12AB1234)', labelStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 10), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 16),
            TextField(controller: driverCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(labelText: 'DEFAULT DRIVER NAME', labelStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 10), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { if (numCtrl.text.isNotEmpty) { _addNewVan(numCtrl.text, driverCtrl.text); Navigator.pop(c); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent), child: const Text('REGISTER VEHICLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // Filter logs for calendar
    final dateFiltered = _logs.where((l) {
      if (l['created_at'] == null) return false;
      final dt = DateTime.parse(l['created_at']);
      return dt.year == _selectedDate.year && dt.month == _selectedDate.month && dt.day == _selectedDate.day;
    }).toList();

    // Statistics
    double totalCost = 0.0;
    double totalLiters = 0.0;
    for (var l in _logs) {
      totalCost += (l['amount_paid'] as num? ?? 0.0).toDouble();
      totalLiters += (l['fuel_liters'] as num? ?? 0.0).toDouble();
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('FLEET CONSOLE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.greenAccent), onPressed: () => _showAddVanModal(isDark)),
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (picked != null) setState(() => _selectedDate = picked);
          }),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : Stack(
              children: [
                Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.05), shape: BoxShape.circle)))),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildOverviewMetrics(totalCost, totalLiters, isDark),
                    const SizedBox(height: 32),
                    Text('REFUELING REGISTRY (${DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase()})', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    if (dateFiltered.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('NO ENTRIES REGISTERED TODAY', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11, fontWeight: FontWeight.bold))))
                    else
                      ...dateFiltered.map((l) => _buildLogCard(l, isDark)).toList(),
                  ],
                )
              ],
            ),
    );
  }

  Widget _buildOverviewMetrics(double totalCost, double totalLiters, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FLEET LIFETIME OUTLAY', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('₹${totalCost.toInt()}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('TOTAL FUEL COST', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${totalLiters.toStringAsFixed(1)}L', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('TOTAL VOLUME INJECTED', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
              ])
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(dynamic log, bool isDark) {
    final van = log['vans'];
    final profile = log['profiles'];
    final double odomStart = (log['previous_meter'] as num? ?? 0.0).toDouble();
    final double odomEnd = (log['latest_meter'] as num? ?? 0.0).toDouble();
    final double delta = odomEnd - odomStart;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(van?['van_number'] ?? 'FLEET UNIT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('₹${log['amount_paid']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Volume: ${log['fuel_liters']}L', style: const TextStyle(fontSize: 11, color: Colors.white60)),
              Text('Distance: ${delta.toStringAsFixed(1)}km', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Refueled By: ${profile?['full_name'] ?? 'Driver'}', style: const TextStyle(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold)),
              if (log['receipt_url'] != null)
                GestureDetector(
                  onTap: () {
                    showDialog(context: context, builder: (_) => Dialog(child: Container(padding: const EdgeInsets.all(8), child: Image.network(log['receipt_url'], fit: BoxFit.contain))));
                  },
                  child: const Row(children: [Icon(Icons.receipt_long_rounded, color: Colors.greenAccent, size: 12), SizedBox(width: 4), Text('VIEW RECEIPT', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold))]),
                )
            ],
          )
        ],
      ),
    );
  }
}
