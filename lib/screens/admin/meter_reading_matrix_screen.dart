import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';
import 'dart:ui';

class MeterReadingMatrixScreen extends StatefulWidget {
  const MeterReadingMatrixScreen({super.key});

  @override
  State<MeterReadingMatrixScreen> createState() =>
      _MeterReadingMatrixScreenState();
}

class _MeterReadingMatrixScreenState extends State<MeterReadingMatrixScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;

  // --- Tab ---
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSaving = false;

  // Building selector
  List<String> _buildings = [];
  String? _selectedBuilding;

  // Month range (last N months ending this month)
  int _monthCount = 6;

  // Rooms fetched for selected building
  List<Map<String, dynamic>> _rooms = [];

  // months[i] = DateTime(year, month, 1)
  List<DateTime> _months = [];

  // readings[roomId][monthStr] = { reading value, electricity_charges }
  Map<String, Map<String, Map<String, dynamic>>> _readings = {};

  // Controllers for inline editing: key = '$roomId|$monthStr'
  Map<String, TextEditingController> _controllers = {};

  double _unitRate = 12.0;

  // Synchronized scroll controllers for 2D Sticky Matrix
  final ScrollController _horizHeader = ScrollController();
  final ScrollController _horizBody = ScrollController();
  final ScrollController _vertRooms = ScrollController();
  final ScrollController _vertBody = ScrollController();

  // --- Intelligence tab data ---
  List<dynamic> _intelReadings = [];
  List<dynamic> _intelUnits = [];
  final Map<String, TextEditingController> _intelControllers = {};
  final Map<String, double> _intelLastReadings = {};
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _intelLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _setupScrollSynchronization();
    _fetchBuildings();
    _fetchIntelligenceData();
  }

  void _setupScrollSynchronization() {
    _horizHeader.addListener(() {
      if (_horizBody.hasClients && _horizBody.offset != _horizHeader.offset) {
        _horizBody.jumpTo(_horizHeader.offset);
      }
    });
    _horizBody.addListener(() {
      if (_horizHeader.hasClients && _horizHeader.offset != _horizBody.offset) {
        _horizHeader.jumpTo(_horizBody.offset);
      }
    });
    _vertRooms.addListener(() {
      if (_vertBody.hasClients && _vertBody.offset != _vertRooms.offset) {
        _vertBody.jumpTo(_vertRooms.offset);
      }
    });
    _vertBody.addListener(() {
      if (_vertRooms.hasClients && _vertRooms.offset != _vertBody.offset) {
        _vertRooms.jumpTo(_vertBody.offset);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _intelControllers.values) {
      c.dispose();
    }
    _horizHeader.dispose();
    _horizBody.dispose();
    _vertRooms.dispose();
    _vertBody.dispose();
    super.dispose();
  }

  // ── Intelligence Data ──────────────────────────────────────────────────────

  Future<void> _fetchIntelligenceData() async {
    setState(() => _intelLoading = true);
    try {
      final rateRes = await _client.from('fee_structure').select('price').eq('service_name', 'Power').maybeSingle();
      if (rateRes != null) _unitRate = (rateRes['price'] as num).toDouble();

      final enrollmentsRes = await _client.from('hostel_enrollments').select('*, hostel_rooms(*), profiles(*)').eq('status', 'Active');
      final List<dynamic> units = enrollmentsRes;
      for (var u in units) {
        final roomId = u['hostel_rooms']['id'];
        if (!_intelControllers.containsKey(roomId)) {
          _intelControllers[roomId] = TextEditingController();
        }
        final lastReadingRes = await _client.from('meter_readings').select('latest_reading').eq('room_id', roomId).order('reading_date', ascending: false).limit(1).maybeSingle();
        _intelLastReadings[roomId] = (lastReadingRes?['latest_reading'] as num?)?.toDouble() ?? 0.0;
      }

      final List<dynamic> readingsRes = await _client.from('meter_readings').select('*, hostel_rooms(*)').order('reading_date', ascending: false);
      final studentIds = readingsRes.map((r) => r['student_id']).where((id) => id != null).toSet().toList();
      List<dynamic> studentProfiles = [];
      if (studentIds.isNotEmpty) {
        studentProfiles = await _client.from('profiles').select('id, full_name').inFilter('id', studentIds);
      }
      final studentMap = {for (var p in studentProfiles) p['id']: p};
      for (var r in readingsRes) {
        final sid = r['student_id'];
        r['profiles'] = studentMap[sid];
      }

      if (mounted) {
        setState(() {
          _intelUnits = units;
          _intelReadings = readingsRes;
          _intelLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _intelLoading = false);
    }
  }

  Future<void> _submitAllIntelReadings() async {
    setState(() => _intelLoading = true);
    bool anySuccess = false;
    String monthStr = DateFormat('yyyy-MM-01').format(_selectedMonth);
    try {
      for (var u in _intelUnits) {
        final roomId = u['hostel_rooms']['id'];
        final studentId = u['user_id'];
        final double lastR = _intelLastReadings[roomId] ?? 0.0;
        final reading = double.tryParse(_intelControllers[roomId]?.text ?? '');
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
      _fetchIntelligenceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(anySuccess ? 'Power audit synced and bills dispatched.' : 'No new readings detected.'),
          backgroundColor: anySuccess ? Colors.greenAccent : Colors.orangeAccent,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      setState(() => _intelLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<DateTime> _computeMonths() {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = _monthCount - 1; i >= 0; i--) {
      int month = now.month - i;
      int year = now.year;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      months.add(DateTime(year, month, 1));
    }
    return months;
  }

  String _monthStr(DateTime d) => DateFormat('yyyy-MM-01').format(d);
  String _monthLabel(DateTime d) => DateFormat('MMM yy').format(d);
  String _monthLabelFull(DateTime d) => DateFormat('MMM yyyy').format(d);

  String _cellKey(String roomId, DateTime month) =>
      '$roomId|${_monthStr(month)}';

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchBuildings() async {
    try {
      final res =
          await _client.from('hostel_rooms').select('building_name').neq('building_name', '');
      final names = (res as List)
          .map((r) => r['building_name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) {
        setState(() {
          _buildings = names;
          _selectedBuilding = names.isNotEmpty ? names.first : null;
        });
        _fetchData();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    if (_selectedBuilding == null) return;
    setState(() => _isLoading = true);
    try {
      // Rate from fee_structure
      final rateRes = await _client
          .from('fee_structure')
          .select('price')
          .eq('service_name', 'Power')
          .maybeSingle();
      if (rateRes != null) _unitRate = (rateRes['price'] as num).toDouble();

      // Rooms in this building
      final roomsRes = await _client
          .from('hostel_rooms')
          .select()
          .eq('building_name', _selectedBuilding!)
          .order('room_number');

      // Month range
      final months = _computeMonths();
      final fromStr = _monthStr(months.first);
      final toStr = _monthStr(months.last);

      // Readings for these rooms & months
      final roomIds = (roomsRes as List).map((r) => r['id'].toString()).toList();
      List<dynamic> readingsRes = [];
      if (roomIds.isNotEmpty) {
        readingsRes = await _client
            .from('meter_readings')
            .select()
            .inFilter('room_id', roomIds);
      }

      // Build lookup map
      final readingMap = <String, Map<String, Map<String, dynamic>>>{};
      for (final r in readingsRes) {
        final rid = r['room_id'].toString();
        final rawPeriod = r['month_period'].toString();
        final mp = rawPeriod.length >= 7 ? rawPeriod.substring(0, 7) : rawPeriod;
        readingMap[rid] ??= {};
        readingMap[rid]![mp] = {
          'latest_reading': (r['latest_reading'] as num?)?.toDouble(),
          'previous_reading': (r['previous_reading'] as num?)?.toDouble(),
          'electricity_charges': (r['electricity_charges'] as num?)?.toDouble(),
        };
      }

      // Dispose old controllers
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers = {};

      // Create controllers pre-filled with existing values
      for (final room in roomsRes) {
        final rid = room['id'].toString();
        for (final month in months) {
          final mp = _monthStr(month).substring(0, 7);
          final key = _cellKey(rid, month);
          final existing = readingMap[rid]?[mp]?['latest_reading'];
          _controllers[key] = TextEditingController(
              text: existing != null ? existing.toStringAsFixed(1) : '');
        }
      }

      if (mounted) {
        setState(() {
          _rooms = (roomsRes as List).cast<Map<String, dynamic>>();
          _months = months;
          _readings = readingMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Load error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── Save / Submit ──────────────────────────────────────────────────────────

  Future<void> _submitReadings() async {
    setState(() => _isSaving = true);
    int saved = 0;
    int skipped = 0;

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (final room in _rooms) {
        final rid = room['id'].toString();
        final buildingName = room['building_name']?.toString() ?? '';
        final double startingMeter = (_readings[rid]?['INITIAL']?['latest_reading'] as num? ?? 0.0).toDouble();

        // Get active student in this room for student_id field
        final enrollRes = await _client
            .from('hostel_enrollments')
            .select('user_id')
            .eq('room_id', rid)
            .eq('status', 'Active')
            .limit(1)
            .maybeSingle();
        final studentId = enrollRes?['user_id'];

        for (final month in _months) {
          final monthStr = _monthStr(month);
          final mp = monthStr.substring(0, 7);
          final key = _cellKey(rid, month);
          final text = _controllers[key]?.text.trim() ?? '';
          if (text.isEmpty) { skipped++; continue; }

          final currR = double.tryParse(text);
          if (currR == null) { skipped++; continue; }

          // Get previous month reading to compute delta
          final prevMonth = month.month == 1
              ? DateTime(month.year - 1, 12, 1)
              : DateTime(month.year, month.month - 1, 1);
          final prevMp = _monthStr(prevMonth).substring(0, 7);
          double prevR = _readings[rid]?[prevMp]?['latest_reading'] ?? startingMeter;

          // Also check if existing reading for this room/month already has a previous_reading
          final existingPrev = _readings[rid]?[mp]?['previous_reading'];
          if (existingPrev != null) prevR = (existingPrev as double);

          final units = (currR - prevR).clamp(0.0, double.infinity);
          // Bill = units × rate (e.g. ₹12/unit)
          final electricityCharges = units * _unitRate;

          await _client.from('meter_readings').upsert({
            'room_id': rid,
            if (studentId != null) 'student_id': studentId,
            'previous_reading': prevR,
            'latest_reading': currR,
            'month_period': monthStr,
            'reading_date': today,
            'electricity_charges': electricityCharges,
            'building_name': buildingName,
          }, onConflict: 'room_id, month_period');
          saved++;
        }
      }

      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $saved readings saved. Electricity bills auto-computed.'),
          backgroundColor: Colors.greenAccent.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: '${_selectedBuilding ?? "Building"} Matrix',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();

      // Header row
      final headers = ['Room', 'Building', 'Floor'];
      for (final m in _months) {
        headers.add(_monthLabelFull(m));
        headers.add('${_monthLabelFull(m)} Bill (₹)');
      }
      buffer.writeln(headers.join(','));

      // Data rows
      for (final room in _rooms) {
        final rid = room['id'].toString();
        final mp_map = _readings[rid] ?? {};
        final row = <String>[
          '"${room['room_number'] ?? ''}"',
          '"${room['building_name'] ?? ''}"',
          room['floor']?.toString() ?? '0',
        ];
        for (final month in _months) {
          final mp = _monthStr(month).substring(0, 7);
          final reading = mp_map[mp]?['latest_reading'];
          final bill = mp_map[mp]?['electricity_charges'];
          row.add(reading != null ? reading.toStringAsFixed(1) : '');
          row.add(bill != null ? bill.toStringAsFixed(2) : '');
        }
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = '${_selectedBuilding?.replaceAll(' ', '_') ?? 'all'}_meter_matrix_$dateLabel.csv';
      final csvContent = buffer.toString();

      if (kIsWeb) {
        downloadCsvFile(csvContent, filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(csvContent);
        await Share.shareXFiles([XFile(file.path)], text: 'Meter Reading Export');
      }

      if (mounted && !kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CSV exported successfully'),
          backgroundColor: Colors.greenAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: '${_selectedBuilding ?? "Building"} Matrix',
      isImport: true,
    );
    if (range == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
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

      if (lines.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('CSV is empty or missing data rows'),
              backgroundColor: Colors.orangeAccent));
        }
        return;
      }

      // Parse header
      final rawHeaders = lines.first.split(',').map((h) => h.trim().replaceAll('"', '')).toList();

      // Identify month columns
      final monthCols = <Map<String, dynamic>>[];
      for (int i = 3; i < rawHeaders.length - 1; i += 2) {
        try {
          final dt = DateFormat('MMM yyyy').parse(rawHeaders[i]);
          monthCols.add({
            'readingIdx': i,
            'billIdx': i + 1,
            'monthStr': _monthStr(dt),
          });
        } catch (_) {
          continue;
        }
      }

      int saved = 0;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cells = _parseCsvLine(line);
        if (cells.length < 4) continue;

        final roomNumber = cells[0].trim();
        final buildingName = cells[1].trim();
        if (roomNumber.isEmpty) continue;

        // Find room
        final roomRes = await _client
            .from('hostel_rooms')
            .select()
            .eq('room_number', roomNumber)
            .eq('building_name', buildingName)
            .maybeSingle();
        if (roomRes == null) continue;
        final rid = roomRes['id'].toString();
        final initialRes = await _client.from('meter_readings').select('latest_reading').eq('room_id', rid).eq('month_period', 'INITIAL').maybeSingle();
        final double startingMeter = (initialRes?['latest_reading'] as num? ?? 0.0).toDouble();

        // Get active student
        final enrollRes = await _client
            .from('hostel_enrollments')
            .select('user_id')
            .eq('room_id', rid)
            .eq('status', 'Active')
            .limit(1)
            .maybeSingle();
        final studentId = enrollRes?['user_id'];

        for (final mc in monthCols) {
          final int rIdx = mc['readingIdx'];
          final String monthStr = mc['monthStr'];
          if (rIdx >= cells.length) continue;
          final rawReading = cells[rIdx].trim();
          if (rawReading.isEmpty) continue;
          final currR = double.tryParse(rawReading);
          if (currR == null) continue;

          // Fetch previous reading from DB or starting reading
          final prevRes = await _client
              .from('meter_readings')
              .select('latest_reading')
              .eq('room_id', rid)
              .lt('month_period', monthStr)
              .order('month_period', ascending: false)
              .limit(1)
              .maybeSingle();
          final prevR = (prevRes?['latest_reading'] as num?)?.toDouble() ?? startingMeter;
          final units = (currR - prevR).clamp(0.0, double.infinity);
          final bill = units * _unitRate;

          await _client.from('meter_readings').upsert({
            'room_id': rid,
            if (studentId != null) 'student_id': studentId,
            'previous_reading': prevR,
            'latest_reading': currR,
            'month_period': monthStr,
            'reading_date': today,
            'electricity_charges': bill,
            'building_name': buildingName,
          }, onConflict: 'room_id, month_period');
          saved++;
        }
      }

      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Imported $saved readings from CSV'),
          backgroundColor: Colors.greenAccent.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    bool inQuotes = false;
    final buf = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    cells.add(buf.toString());
    return cells;
  }

  // ── Tapping Room Details & Starting Meter Modal ───────────────────────────

  Future<void> _showRoomDetailsModal(Map<String, dynamic> room) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 13);
    final headingStyle = GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1);

    final rid = room['id'].toString();

    // Query active occupants (students) in this room
    final List<dynamic> occupants = await _client
        .from('hostel_enrollments')
        .select('*, profiles(*)')
        .eq('room_id', rid)
        .eq('status', 'Active');

    final initialRes = await _client.from('meter_readings').select('latest_reading').eq('room_id', rid).eq('month_period', 'INITIAL').maybeSingle();
    final double initialReadingVal = (initialRes?['latest_reading'] as num? ?? 0.0).toDouble();

    final ctrl = TextEditingController(text: initialReadingVal.toString());

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'ROOM ${room['room_number']} INTEL',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Archetype Cost
                Text('ARCHETYPE & BASE COST', style: headingStyle),
                const SizedBox(height: 4),
                Text('Type: ${room['room_type'] ?? "Standard"}', style: textStyle),
                Text('Base Price: ₹${room['base_price'] ?? "6500"}/month', style: textStyle),
                const SizedBox(height: 20),

                // Starting Meter Input
                Text('INITIAL/STARTING METER READING (kWh)', style: headingStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 20),

                // Occupant details
                Text('ROOM OCCUPANTS', style: headingStyle),
                const SizedBox(height: 6),
                if (occupants.isEmpty)
                  Text('Vacant (No Active Residents)', style: textStyle.copyWith(color: Colors.grey))
                else
                  ...occupants.map((occ) {
                    final prof = occ['profiles'] ?? {};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: Colors.indigoAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(prof['full_name'] ?? 'Resident', style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                                Text('Role: ${prof['role']?.toString().replaceAll("_", " ").toUpperCase() ?? "Student"}', style: textStyle.copyWith(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CLOSE', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? val = double.tryParse(ctrl.text);
                if (val != null) {
                  await _client
                      .from('meter_readings')
                      .upsert({
                        'room_id': rid,
                        'month_period': 'INITIAL',
                        'latest_reading': val,
                        'previous_reading': 0.0,
                        'reading_date': DateTime.now().toIso8601String().split('T')[0],
                        'electricity_charges': 0.0,
                        'building_name': room['building_name'] ?? '',
                      }, onConflict: 'room_id, month_period');
                  
                  // Reload grid readings calculation
                  Navigator.pop(ctx);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Starting meter reading updated successfully.'),
                    backgroundColor: Colors.greenAccent,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('SAVE INTEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tabController.index == 0 ? 'METER MATRIX' : 'POWER INTELLIGENCE',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900, fontSize: 14, color: textColor, letterSpacing: 1.5)),
        actions: [
          if (_tabController.index == 0) ...[
            Tooltip(
              message: 'Export CSV',
              child: IconButton(
                icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent),
                onPressed: _exportCSV,
              ),
            ),
            Tooltip(
              message: 'Import CSV',
              child: IconButton(
                icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent),
                onPressed: _importCSV,
              ),
            ),
            Tooltip(
              message: 'Save All Readings',
              child: IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent))
                    : const Icon(Icons.save_rounded, color: Colors.amberAccent),
                onPressed: _isSaving ? null : _submitReadings,
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: Colors.amberAccent),
              tooltip: 'Select Month',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedMonth,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.amberAccent),
              tooltip: 'Refresh',
              onPressed: _fetchIntelligenceData,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: textColor.withOpacity(0.4),
          labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          tabs: const [
            Tab(icon: Icon(Icons.grid_on_rounded, size: 14), text: 'MATRIX'),
            Tab(icon: Icon(Icons.flash_on_rounded, size: 14), text: 'INTELLIGENCE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab 0: Matrix Grid
          Column(
            children: [
              _buildFilterBar(isDark),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
                    : _rooms.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildMatrix(isDark, textColor),
              ),
              _buildLegend(isDark),
            ],
          ),
          // Tab 1: Intelligence
          _buildIntelligenceTab(isDark),
        ],
      ),
    );
  }

  // ── Intelligence Tab UI ─────────────────────────────────────────────────────

  Widget _buildIntelligenceTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    Map<String, double> roomConsumption = {};
    Map<String, int> roomReadingsCount = {};
    for (var r in _intelReadings) {
      final roomNo = r['hostel_rooms']?['room_number'] ?? 'N/A';
      final double delta = (r['latest_reading'] as num? ?? 0.0).toDouble() -
          (r['previous_reading'] as num? ?? 0.0).toDouble();
      roomConsumption[roomNo] = (roomConsumption[roomNo] ?? 0.0) + delta;
      roomReadingsCount[roomNo] = (roomReadingsCount[roomNo] ?? 0) + 1;
    }

    final floorGroups = <int, List<dynamic>>{};
    for (var u in _intelUnits) {
      final roomNo = u['hostel_rooms']['room_number']?.toString() ?? '0';
      int floor = int.tryParse(roomNo.length > 0 ? roomNo[0] : '0') ?? 0;
      if (roomNo.length == 4) floor = int.tryParse(roomNo.substring(0, 2)) ?? 0;
      floorGroups[floor] = (floorGroups[floor] ?? [])..add(u);
    }
    final sortedFloors = floorGroups.keys.toList()..sort();

    double totalUnits = 0.0;
    roomConsumption.values.forEach((v) => totalUnits += v);

    return _intelLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Overview Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('POWER AUDIT — ${DateFormat('MMM yyyy').format(_selectedMonth).toUpperCase()}',
                        style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${totalUnits.toStringAsFixed(1)} U',
                              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                          Text('TOTAL CONSUMPTION', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('₹${(totalUnits * _unitRate).toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                          Text('EST. BILLING', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Billing input form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISPATCH BILLS FOR MONTH', style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    ...sortedFloors.map((f) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FLOOR 0$f', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 8),
                        ...(floorGroups[f] ?? []).map((u) {
                          final room = u['hostel_rooms'];
                          final profile = u['profiles'];
                          final roomId = room['id'];
                          final double lastReading = _intelLastReadings[roomId] ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('UNIT ${room['room_number']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text(profile?['full_name'] ?? 'VACANT', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
                                  ],
                                )),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PREV', style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                                    Text(lastReading.toStringAsFixed(1), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                )),
                                Expanded(child: TextField(
                                  controller: _intelControllers[roomId],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    hintText: '000.0',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    border: OutlineInputBorder(),
                                  ),
                                )),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                      ],
                    )).toList(),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitAllIntelReadings,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text('AUTHORIZE & DISPATCH BILLS', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Room-wise consumption
              if (roomConsumption.isNotEmpty) ...[
                Text('ROOM-WISE CONSUMPTION', style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...roomConsumption.entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ROOM ${e.key}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${roomReadingsCount[e.key] ?? 0} logs', style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black38)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${e.value.toStringAsFixed(1)} U', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.amberAccent)),
                        Text('₹${(e.value * _unitRate).toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54)),
                      ]),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 20),
              // Readings log
              if (_intelReadings.isNotEmpty) ...[
                Text('METER LOG HISTORY', style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ..._intelReadings.take(20).map((r) {
                  final room = r['hostel_rooms'];
                  final delta = (r['latest_reading'] as num? ?? 0.0) - (r['previous_reading'] as num? ?? 0.0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ROOM ${room?['room_number'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(r['reading_date']?.toString() ?? '', style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black38)),
                        ]),
                        Text('+${delta.toStringAsFixed(1)} U', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar(bool isDark) {
    final cardColor = isDark ? const Color(0xFF16181A) : Colors.white;
    return FadeInDown(
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: cardColor,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildDropdown(
                hint: 'Select Building',
                value: _selectedBuilding,
                items: _buildings,
                icon: Icons.domain_rounded,
                color: Colors.indigoAccent,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _selectedBuilding = val);
                  _fetchData();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildDropdown(
                hint: 'Months',
                value: _monthCount.toString(),
                items: ['3', '6', '9', '12'],
                icon: Icons.calendar_view_month_rounded,
                color: Colors.amberAccent,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _monthCount = int.parse(val!));
                  _fetchData();
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.amberAccent, size: 20),
                onPressed: _fetchData,
                tooltip: 'Refresh',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Color color,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.outfit(fontSize: 12, color: color.withOpacity(0.6))),
          icon: Icon(icon, color: color, size: 18),
          dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
          isExpanded: true,
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black),
          onChanged: onChanged,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
      ),
    );
  }

  // ── Matrix table ───────────────────────────────────────────────────────────

  Widget _buildMatrix(bool isDark, Color textColor) {
    const double colWidth = 100.0;
    const double billColWidth = 90.0;
    const double rowHeight = 52.0;
    const double roomColWidth = 90.0;
    const double headerHeight = 48.0;

    final headerBg = isDark ? const Color(0xFF16181A) : const Color(0xFFF0F4FF);
    final rowBg = isDark ? const Color(0xFF0E0F11) : Colors.white;
    final altRowBg = isDark ? const Color(0xFF12141A) : const Color(0xFFFAFBFF);
    final borderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return Row(
      children: [
        // Left Column: Sticky room labels
        Column(
          children: [
            // Top-Left corner: Room title header
            _headerCell('Room', roomColWidth, headerHeight, isDark, textColor),
            Container(height: 1, color: borderColor, width: roomColWidth),
            // Scrollable room labels column
            Expanded(
              child: SingleChildScrollView(
                controller: _vertRooms,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(), // Synced from _vertBody
                child: Column(
                  children: [
                    for (int ri = 0; ri < _rooms.length; ri++) ...[
                      InkWell(
                        onTap: () => _showRoomDetailsModal(_rooms[ri]),
                        child: Container(
                          width: roomColWidth,
                          height: rowHeight,
                          decoration: BoxDecoration(
                            color: ri.isOdd ? altRowBg : rowBg,
                            border: Border(right: BorderSide(color: borderColor)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _rooms[ri]['room_number']?.toString() ?? '-',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.indigoAccent,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                      Container(height: 0.5, color: borderColor, width: roomColWidth),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        // Right Area: Columns and data cells
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month header row (scrolls horizontally, sticky vertically)
              SingleChildScrollView(
                controller: _horizHeader,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(), // Synced from _horizBody
                child: Container(
                  color: headerBg,
                  child: Row(
                    children: [
                      for (final month in _months) ...[
                        _headerCell(_monthLabel(month), colWidth, headerHeight, isDark, Colors.indigoAccent),
                        _headerCell('₹ Bill', billColWidth, headerHeight, isDark, Colors.greenAccent.shade400, fontSize: 10),
                      ],
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: borderColor),

              // Grid cells (scrolls vertically and horizontally)
              Expanded(
                child: Scrollbar(
                  controller: _vertBody,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vertBody,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      controller: _horizBody,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizBody,
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int ri = 0; ri < _rooms.length; ri++) ...[
                              Builder(builder: (context) {
                                final room = _rooms[ri];
                                final rid = room['id'].toString();
                                final bg = ri.isOdd ? altRowBg : rowBg;

                                return Container(
                                  color: bg,
                                  child: Row(
                                    children: [
                                      for (final month in _months) ...[
                                        _readingCell(rid, month, colWidth, rowHeight, borderColor, isDark),
                                        _billCell(rid, month, billColWidth, rowHeight, borderColor, isDark),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                              Container(height: 0.5, color: borderColor),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String label, double width, double height, bool isDark, Color color,
      {double fontSize = 11}) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              color: color,
              letterSpacing: 0.5)),
    );
  }

  Widget _readingCell(
      String roomId, DateTime month, double width, double height, Color borderColor, bool isDark) {
    final key = _cellKey(roomId, month);
    final ctrl = _controllers[key];
    final mp = _monthStr(month).substring(0, 7);
    final existing = _readings[roomId]?[mp];
    final hasData = existing != null;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
        color: hasData
            ? Colors.indigoAccent.withOpacity(isDark ? 0.06 : 0.04)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: hasData ? FontWeight.w600 : FontWeight.normal,
              color: isDark
                  ? (hasData ? Colors.indigoAccent.shade100 : Colors.white54)
                  : (hasData ? Colors.indigo.shade700 : Colors.black38)),
          decoration: InputDecoration(
            hintText: '—',
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _billCell(
      String roomId, DateTime month, double width, double height, Color borderColor, bool isDark) {
    final mp = _monthStr(month).substring(0, 7);
    final bill = _readings[roomId]?[mp]?['electricity_charges'] as double?;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
        color: bill != null && bill > 0
            ? Colors.greenAccent.withOpacity(isDark ? 0.05 : 0.04)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        bill != null ? '₹${bill.toStringAsFixed(0)}' : '—',
        style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: bill != null && bill > 0
                ? Colors.greenAccent.shade700
                : (isDark ? Colors.white24 : Colors.black26)),
      ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: isDark ? const Color(0xFF0A0B0D) : const Color(0xFFF5F7FF),
      child: Row(
        children: [
          _legendDot(Colors.indigoAccent, 'Meter reading (kWh)'),
          const SizedBox(width: 20),
          _legendDot(Colors.greenAccent.shade700, '₹ Bill = units × ₹${_unitRate.toStringAsFixed(0)}'),
          const Spacer(),
          Text(
            'Tap Room No for Starting Meter/Occupant Intel • Save icon to submit all',
            style: GoogleFonts.outfit(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.electric_meter_rounded,
                size: 64, color: isDark ? Colors.white12 : Colors.black12),
            const SizedBox(height: 16),
            Text('NO ROOMS FOUND',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white24 : Colors.black26,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(
              _selectedBuilding == null
                  ? 'Select a building to view meter readings'
                  : 'No rooms in "$_selectedBuilding"',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}
