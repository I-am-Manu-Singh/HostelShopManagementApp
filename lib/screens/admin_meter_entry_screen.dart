import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminMeterEntryScreen extends StatefulWidget {
  const AdminMeterEntryScreen({super.key});

  @override
  State<AdminMeterEntryScreen> createState() => _AdminMeterEntryScreenState();
}

class _AdminMeterEntryScreenState extends State<AdminMeterEntryScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _units = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, double> _lastReadings = {};
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  double _unitRate = 12.0;

  @override
  void initState() {
    super.initState();
    _fetchUnitRate();
    _fetchUnits();
  }

  Future<void> _fetchUnitRate() async {
    try {
      final res = await _client.from('fee_structure').select('price').eq('service_name', 'Power').maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _unitRate = (res['price'] as num).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchUnits() async {
    setState(() => _isLoading = true);
    try {
      // Fetch active enrollments with room types
      final res = await _client.from('hostel_enrollments')
          .select('*, hostel_rooms(*), profiles(*)')
          .eq('status', 'Active');
      
      final unitsList = res as List;
      for (var u in unitsList) {
        final roomId = u['hostel_rooms']['id'];
        if (!_controllers.containsKey(roomId)) {
           _controllers[roomId] = TextEditingController();
        }
        
        final lastReadingRes = await _client
            .from('meter_readings')
            .select('latest_reading')
            .eq('room_id', roomId)
            .order('reading_date', ascending: false)
            .limit(1)
            .maybeSingle();
        
        _lastReadings[roomId] = (lastReadingRes?['latest_reading'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _units = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group units by Floor
    final floorGroups = <int, List<dynamic>>{};
    for (var u in _units) {
      final roomNo = u['hostel_rooms']['room_number']?.toString() ?? '0';
      int floor = int.tryParse(roomNo.substring(0, roomNo.length > 2 ? 1 : 0)) ?? 0;
      if (roomNo.length == 4) floor = int.tryParse(roomNo.substring(0, 2)) ?? 0;
      if (!floorGroups.containsKey(floor)) floorGroups[floor] = [];
      floorGroups[floor]!.add(u);
    }
    final sortedFloors = floorGroups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('UTILITY POWER AUDIT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.amberAccent), onPressed: _selectMonth),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                   _buildMonthBanner(),
                   const SizedBox(height: 32),
                   ...sortedFloors.map((f) => Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildFloorHeader(f),
                       const SizedBox(height: 16),
                       GridView.builder(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
                         itemCount: floorGroups[f]!.length,
                         itemBuilder: (context, i) => _buildMeterTile(floorGroups[f]![i]),
                       ),
                       const SizedBox(height: 40),
                     ],
                   )).toList(),
                   const SizedBox(height: 100),
                ],
              ),
            ],
          ),
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  Widget _buildFloorHeader(int f) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text('LEVEL 0$f STRATA', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildMonthBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amberAccent.withOpacity(0.1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('AUDIT PERIOD:', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
          Text(DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase(), style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
        ],
      ),
    );
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _fetchUnits();
    }
  }

  Widget _buildRefractionOrbs() {
    return Positioned(top: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildMeterTile(dynamic u) {
    final room = u['hostel_rooms'];
    final profile = u['profiles'];
    final roomId = room['id'];
    final double lastReading = _lastReadings[roomId] ?? 0.0;

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(
          children: [
            Row(children: [
              const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 16),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text('UNIT ${room['room_number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                 Text(profile?['full_name'] ?? 'VACANT', style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
              ])),
            ]),
            const Spacer(),
            _buildReadBox('PREVIOUS', lastReading.toStringAsFixed(1)),
            const SizedBox(height: 12),
            _buildInputBox('LATEST', _controllers[roomId]!),
            const Spacer(),
            ValueListenableBuilder(
              valueListenable: _controllers[roomId]!,
              builder: (context, val, _) {
                double latest = double.tryParse(val.text) ?? lastReading;
                double units = (latest - lastReading).clamp(0, double.infinity);
                double amt = units * _unitRate;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     _miniInsight('USAGE', '${units.toStringAsFixed(1)}U', Colors.white24),
                     _miniInsight('BILL', '₹${amt.toInt()}', Colors.amberAccent),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadBox(String label, String val) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 4), Text(val, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))]));
  }

  Widget _buildInputBox(String label, TextEditingController ctrl) {
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amberAccent.withOpacity(0.1))), child: TextField(controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 20), decoration: InputDecoration(border: InputBorder.none, hintText: '0000', hintStyle: const TextStyle(color: Colors.white10), label: Center(child: Text(label, style: const TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900))))));
  }

  Widget _miniInsight(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), Text(v, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 16))]);

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      color: const Color(0xFF0F172A),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitAllReadings,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 20)),
        child: const Text('AUTHORIZE & BILL MONTHLY CYCLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
      ),
    );
  }

  Future<void> _submitAllReadings() async {
    setState(() => _isLoading = true);
    bool anySuccess = false;
    String monthStr = DateFormat('yyyy-MM-01').format(_selectedMonth);

    try {
      for (var u in _units) {
         final roomId = u['hostel_rooms']['id'];
         final studentId = u['user_id'];
         final double lastR = _lastReadings[roomId] ?? 0.0;
         final reading = double.tryParse(_controllers[roomId]!.text);
         
         if (reading != null && reading > lastR) {
            await _client.from('meter_readings').upsert({
              'room_id': roomId,
              'user_id': studentId,
              'previous_reading': lastR,
              'latest_reading': reading,
              'month_period': monthStr,
              'reading_date': DateTime.now().toIso8601String().split('T')[0],
            }, onConflict: 'room_id, month_period');
            anySuccess = true;
         }
      }
      
      if (mounted) {
        if (anySuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOGISTICS: Power Audit Synced and Resident Bills Dispatched.'), backgroundColor: Colors.greenAccent));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AUDIT ERROR: No new readings detected or invalid data.'), backgroundColor: Colors.orangeAccent));
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Submit Error: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MISSION_FAILURE: $e'), backgroundColor: Colors.redAccent));
         setState(() => _isLoading = false);
      }
    }
  }
}
