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

class MeterReadingMatrixScreen extends StatefulWidget {
  const MeterReadingMatrixScreen({super.key});

  @override
  State<MeterReadingMatrixScreen> createState() =>
      _MeterReadingMatrixScreenState();
}

class _MeterReadingMatrixScreenState extends State<MeterReadingMatrixScreen> {
  final _client = Supabase.instance.client;

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

  @override
  void initState() {
    super.initState();
    _fetchBuildings();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
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
            .inFilter('room_id', roomIds)
            .gte('month_period', fromStr)
            .lte('month_period', toStr);
      }

      // Build lookup map
      final readingMap = <String, Map<String, Map<String, dynamic>>>{};
      for (final r in readingsRes) {
        final rid = r['room_id'].toString();
        final mp = r['month_period'].toString().substring(0, 7); // yyyy-MM
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
          double prevR = _readings[rid]?[prevMp]?['latest_reading'] ?? 0.0;

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
        setState(() => _isSaving = false);
      }
    }
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportCSV() async {
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

      final filename =
          '${_selectedBuilding?.replaceAll(' ', '_') ?? 'all'}_meter_readings.csv';
      final csvContent = buffer.toString();

      if (kIsWeb) {
        // Real browser download via dart:html
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // ensures bytes are available on web
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

      // Parse header: Room, Building, Floor, {MonthLabel}, {MonthLabel Bill (₹)}, ...
      final rawHeaders = lines.first.split(',').map((h) => h.trim().replaceAll('"', '')).toList();

      // Identify month columns (skip Room, Building, Floor)
      // Month col pairs: (reading col index, bill col index, monthStr)
      final monthCols = <Map<String, dynamic>>[];
      for (int i = 3; i < rawHeaders.length - 1; i += 2) {
        // Try to parse header as 'MMM yyyy'
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

        // Simple quoted CSV parse
        final cells = _parseCsvLine(line);
        if (cells.length < 4) continue;

        final roomNumber = cells[0].trim();
        final buildingName = cells[1].trim();
        if (roomNumber.isEmpty) continue;

        // Find room_id
        final roomRes = await _client
            .from('hostel_rooms')
            .select('id, floor')
            .eq('room_number', roomNumber)
            .eq('building_name', buildingName)
            .maybeSingle();
        if (roomRes == null) continue;
        final rid = roomRes['id'].toString();

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

          // Fetch previous reading from DB
          final prevRes = await _client
              .from('meter_readings')
              .select('latest_reading')
              .eq('room_id', rid)
              .lt('month_period', monthStr)
              .order('month_period', ascending: false)
              .limit(1)
              .maybeSingle();
          final prevR = (prevRes?['latest_reading'] as num?)?.toDouble() ?? 0.0;
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

  // ── Build UI ───────────────────────────────────────────────────────────────

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
        title: Text('METER READING MATRIX',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 14, color: textColor, letterSpacing: 1.5)),
        actions: [
          // Export
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent),
              onPressed: _exportCSV,
            ),
          ),
          // Import
          Tooltip(
            message: 'Import CSV',
            child: IconButton(
              icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent),
              onPressed: _importCSV,
            ),
          ),
          // Save all
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
        ],
      ),
      body: Column(
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
            // Building selector
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
            // Month count selector
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
            // Refresh
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

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──
              Container(
                color: headerBg,
                child: Row(
                  children: [
                    // Sticky room column header
                    _headerCell('Room', roomColWidth, headerHeight, isDark, textColor,
                        sticky: true),
                    // Month + bill pair headers
                    for (final month in _months) ...[
                      _headerCell(
                          _monthLabel(month), colWidth, headerHeight, isDark, Colors.indigoAccent),
                      _headerCell(
                          '₹ Bill', billColWidth, headerHeight, isDark, Colors.greenAccent.shade400,
                          fontSize: 10),
                    ],
                  ],
                ),
              ),
              Container(height: 1, color: borderColor),

              // ── Data rows ──
              for (int ri = 0; ri < _rooms.length; ri++) ...[
                Builder(builder: (context) {
                  final room = _rooms[ri];
                  final rid = room['id'].toString();
                  final bg = ri.isOdd ? altRowBg : rowBg;

                  return Container(
                    color: bg,
                    child: Row(
                      children: [
                        // Room label
                        Container(
                          width: roomColWidth,
                          height: rowHeight,
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border(right: BorderSide(color: borderColor)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            room['room_number']?.toString() ?? '-',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                          ),
                        ),
                        // Month cells
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
    );
  }

  Widget _headerCell(String label, double width, double height, bool isDark, Color color,
      {bool sticky = false, double fontSize = 11}) {
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
            'Tap a cell to edit • Save icon to submit all',
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
