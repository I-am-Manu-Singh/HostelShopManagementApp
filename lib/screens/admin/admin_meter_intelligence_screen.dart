import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminMeterIntelligenceScreen extends StatefulWidget {
  const AdminMeterIntelligenceScreen({super.key});

  @override
  State<AdminMeterIntelligenceScreen> createState() => _AdminMeterIntelligenceScreenState();
}

class _AdminMeterIntelligenceScreenState extends State<AdminMeterIntelligenceScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _readings = [];
  List<dynamic> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchMeterData();
  }

  Future<void> _fetchMeterData() async {
    setState(() => _isLoading = true);
    try {
      final roomsRes = await _client.from('hostel_rooms').select();
      final readingsRes = await _client.from('meter_readings').select('*, hostel_rooms(*), profiles(full_name)').order('reading_date', ascending: false);
      if (mounted) {
        setState(() {
          _rooms = roomsRes;
          _readings = readingsRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // Room-wise statistics
    Map<String, double> roomConsumption = {};
    Map<String, int> roomReadingsCount = {};

    for (var r in _readings) {
      final roomNo = r['hostel_rooms']?['room_number'] ?? 'N/A';
      final double delta = (r['latest_reading'] as num? ?? 0.0).toDouble() - (r['previous_reading'] as num? ?? 0.0).toDouble();
      roomConsumption[roomNo] = (roomConsumption[roomNo] ?? 0.0) + delta;
      roomReadingsCount[roomNo] = (roomReadingsCount[roomNo] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('METER INTELLIGENCE & STATS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Stack(
              children: [
                Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), shape: BoxShape.circle)))),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildOverviewDashboard(roomConsumption, isDark),
                    const SizedBox(height: 32),
                    Text('ROOM-WISE UTILITIES & CONSUMPTION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    ...roomConsumption.entries.map((e) => _buildConsumptionCard(e.key, e.value, roomReadingsCount[e.key] ?? 0, isDark)).toList(),
                    const SizedBox(height: 32),
                    Text('METER READINGS LOG', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    ..._readings.map((r) => _buildReadingLogTile(r, isDark)).toList(),
                  ],
                )
              ],
            ),
    );
  }

  Widget _buildOverviewDashboard(Map<String, double> roomConsumption, bool isDark) {
    double totalUnits = 0.0;
    roomConsumption.values.forEach((v) => totalUnits += v);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AGGREGATED MONTHLY POWER AUDIT', style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${totalUnits.toStringAsFixed(1)}U', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('TOTAL CONSUMPTION', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${(totalUnits * 8.5).toInt()}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('ESTIMATED REVENUE (₹8.5/U)', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
              ])
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsumptionCard(String roomNo, double consumption, int logsCount, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROOM $roomNo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('$logsCount active logs', style: const TextStyle(fontSize: 9, color: Colors.white24)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${consumption.toStringAsFixed(1)} U', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.amberAccent)),
              Text('₹${(consumption * 8.5).toInt()}', style: const TextStyle(fontSize: 9, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadingLogTile(dynamic r, bool isDark) {
    final room = r['hostel_rooms'];
    final profile = r['profiles'];
    final double delta = (r['latest_reading'] as num? ?? 0.0).toDouble() - (r['previous_reading'] as num? ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROOM ${room?['room_number'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Auditor: ${profile?['full_name'] ?? 'System'}', style: const TextStyle(fontSize: 8, color: Colors.white24)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${delta.toStringAsFixed(1)} U', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM yyyy').format(DateTime.parse(r['reading_date'])), style: const TextStyle(fontSize: 8, color: Colors.white24)),
            ],
          )
        ],
      ),
    );
  }
}
