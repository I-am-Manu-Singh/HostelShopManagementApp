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
  List<dynamic> _units = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, double> _lastReadings = {};
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  double _unitRate = 12.0;

  @override
  void initState() {
    super.initState();
    _fetchMeterData();
  }

  Future<void> _fetchMeterData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch fee structure rate
      final rateRes = await _client.from('fee_structure').select('price').eq('service_name', 'Power').maybeSingle();
      if (rateRes != null) {
        _unitRate = (rateRes['price'] as num).toDouble();
      }

      // 2. Fetch room units & active enrollments
      final roomsRes = await _client.from('hostel_rooms').select();
      final enrollmentsRes = await _client.from('hostel_enrollments').select('*, hostel_rooms(*), profiles(*)').eq('status', 'Active');
      _units = enrollmentsRes as List;

      for (var u in _units) {
        final roomId = u['hostel_rooms']['id'];
        if (!_controllers.containsKey(roomId)) {
          _controllers[roomId] = TextEditingController();
        }
        final lastReadingRes = await _client.from('meter_readings').select('latest_reading').eq('room_id', roomId).order('reading_date', ascending: false).limit(1).maybeSingle();
        _lastReadings[roomId] = (lastReadingRes?['latest_reading'] as num?)?.toDouble() ?? 0.0;
      }

      // 3. Fetch meter readings
      final readingsRes = await _client.from('meter_readings').select('*, hostel_rooms(*), profiles!meter_readings_student_id_fkey(full_name)').order('reading_date', ascending: false);
      
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
    }
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
          final double units = reading - lastR;
          final double electricityCharges = units * _unitRate;
          final roomData = u['hostel_rooms'];
          await _client.from('meter_readings').upsert({
            'room_id': roomId,
            'student_id': studentId,
            'previous_reading': lastR,
            'latest_reading': reading,
            'month_period': monthStr,
            'reading_date': DateTime.now().toIso8601String().split('T')[0],
            'electricity_charges': electricityCharges,
            'building_name': roomData?['building_name'] ?? '',
          }, onConflict: 'room_id, month_period');
          anySuccess = true;
        }
      }
      
      _fetchMeterData();
      if (mounted) {
        if (anySuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Power audit synced and resident bills dispatched successfully.'), backgroundColor: Colors.greenAccent));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No new readings detected or invalid values.'), backgroundColor: Colors.orangeAccent));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failure: $e'), backgroundColor: Colors.redAccent));
      setState(() => _isLoading = false);
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

    // Floor sorting groups for recording
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
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('METER INTELLIGENCE & AUDITS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.amberAccent, size: 24), onPressed: _selectMonth),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Stack(
              children: [
                Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), shape: BoxShape.circle)))),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      // Desktop/Wide View: 2-column layout split
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  _buildOverviewDashboard(roomConsumption, isDark),
                                  const SizedBox(height: 24),
                                  _buildBillingPeriodForm(sortedFloors, floorGroups, isDark),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, color: Colors.black12),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                                  child: Text('ROOM-WISE UTILITIES & CONSUMPTION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 1.5)),
                                ),
                                Expanded(
                                  child: roomConsumption.isEmpty
                                    ? Center(child: Text('NO ROOM CONSUMPTION DATA', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13, fontWeight: FontWeight.bold)))
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        itemCount: roomConsumption.length,
                                        itemBuilder: (context, i) {
                                          final key = roomConsumption.keys.elementAt(i);
                                          return _buildConsumptionCard(key, roomConsumption[key]!, roomReadingsCount[key] ?? 0, isDark);
                                        },
                                      ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                                  child: Text('METER READINGS RECORDED LOG', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                                ),
                                Expanded(
                                  child: _readings.isEmpty
                                    ? Center(child: Text('NO RECORDED LOGS FOUND', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13, fontWeight: FontWeight.bold)))
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        itemCount: _readings.length,
                                        itemBuilder: (context, i) => _buildReadingLogTile(_readings[i], isDark),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile View: Single column scrolling list
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildOverviewDashboard(roomConsumption, isDark),
                        const SizedBox(height: 24),
                        _buildBillingPeriodForm(sortedFloors, floorGroups, isDark),
                        const SizedBox(height: 32),
                        Text('ROOM-WISE UTILITIES & CONSUMPTION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        ...roomConsumption.entries.map((e) => _buildConsumptionCard(e.key, e.value, roomReadingsCount[e.key] ?? 0, isDark)).toList(),
                        const SizedBox(height: 32),
                        Text('METER READINGS RECORDED LOG', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        ..._readings.map((r) => _buildReadingLogTile(r, isDark)).toList(),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildBillingPeriodForm(List<int> sortedFloors, Map<int, List<dynamic>> floorGroups, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.amberAccent.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DISPATCH BILLS FOR MONTH', style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Text(DateFormat('MMM yyyy').format(_selectedMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedFloors.map((f) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEVEL 0$f STRATA', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...floorGroups[f]!.map((u) => _buildMeterInputTile(u, isDark)).toList(),
              const SizedBox(height: 16),
            ],
          )).toList(),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submitAllReadings, style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent), child: const Text('AUTHORIZE & DISPATCH BILLS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15))))
        ],
      ),
    );
  }

  Widget _buildMeterInputTile(dynamic u, bool isDark) {
    final room = u['hostel_rooms'];
    final profile = u['profiles'];
    final roomId = room['id'];
    final double lastReading = _lastReadings[roomId] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('UNIT ${room['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(profile?['full_name'] ?? 'VACANT', style: const TextStyle(color: Colors.white24, fontSize: 11))])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('PREV', style: TextStyle(fontSize: 10, color: Colors.white24)), Text(lastReading.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])),
          Expanded(child: TextField(controller: _controllers[roomId]!, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: '000.0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)))),
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
          Text('AGGREGATED MONTHLY POWER AUDIT', style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${totalUnits.toStringAsFixed(1)}U', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('TOTAL CONSUMPTION', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${(totalUnits * 8.5).toInt()}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('ESTIMATED REVENUE (₹8.5/U)', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
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
              Text('ROOM $roomNo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('$logsCount active logs', style: const TextStyle(fontSize: 11, color: Colors.white24)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${consumption.toStringAsFixed(1)} U', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.amberAccent)),
              Text('₹${(consumption * 8.5).toInt()}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
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
              Text('ROOM ${room?['room_number'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Auditor: ${profile?['full_name'] ?? 'System'}', style: const TextStyle(fontSize: 11, color: Colors.white24)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${delta.toStringAsFixed(1)} U', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM yyyy').format(DateTime.parse(r['reading_date'])), style: const TextStyle(fontSize: 11, color: Colors.white24)),
            ],
          )
        ],
      ),
    );
  }
}
