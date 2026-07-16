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
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

class AdminRoomInspectionScreen extends StatefulWidget {
  const AdminRoomInspectionScreen({super.key});

  @override
  State<AdminRoomInspectionScreen> createState() => _AdminRoomInspectionScreenState();
}

class _AdminRoomInspectionScreenState extends State<AdminRoomInspectionScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rooms = [];
  List<dynamic> _records = [];
  
  String? _selectedBuilding;
  dynamic _selectedRoom;
  
  final _descCtrl = TextEditingController();
  final _resCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String _activeStatus = 'OK';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final rRes = await _client.from('hostel_rooms').select();
      final mRes = await _client.from('room_maintenance_records').select('*, hostel_rooms(*)').order('inspection_date', ascending: false);
      if (mounted) {
        setState(() {
          _rooms = rRes;
          _records = mRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logInspection() async {
    if (_selectedRoom == null) return;
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      final cost = double.tryParse(_costCtrl.text) ?? 0;
      
      // 1. Create Maintenance Record
      await _client.from('room_maintenance_records').insert({
        'room_id': _selectedRoom['id'],
        'inspector_id': user?.id,
        'status': _activeStatus,
        'issue_description': _descCtrl.text,
        'resolution_details': _resCtrl.text,
        'actual_cost': cost,
      });

      // 2. If cost > 0, log in Day Book automatically
      if (cost > 0) {
        await _client.from('day_book_entries').insert({
          'entry_type': 'Expense',
          'amount': cost,
          'category': 'Room Maintenance',
          'target_user_id': user?.id,
          'related_room_id': _selectedRoom['id'],
          'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
      }

      _descCtrl.clear(); _resCtrl.clear(); _costCtrl.clear();
      _fetchInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('INSPECTION AUDIT COMMITTED'), backgroundColor: Colors.indigoAccent));
      }
    } catch (_) {} finally { setState(() => _isLoading = false); }
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportInspectionsToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: _selectedBuilding != null ? 'Room Inspections ($_selectedBuilding)' : 'All Room Inspections',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      final headers = ['Record ID', 'Building', 'Room No', 'Inspector UUID', 'Status', 'Issue', 'Resolution', 'Cost (₹)', 'Date'];
      buffer.writeln(headers.join(','));

      final filtered = _records.where((r) {
        final room = r['hostel_rooms'] ?? {};
        if (_selectedBuilding != null && room['building_name'] != _selectedBuilding) return false;
        if (r['inspection_date'] != null) {
          final dt = DateTime.tryParse(r['inspection_date'].toString());
          if (dt != null) {
            return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
          }
        }
        return true;
      }).toList();

      for (var r in filtered) {
        final room = r['hostel_rooms'] ?? {};
        final List<String> row = [
          r['id']?.toString() ?? '',
          '"${(room['building_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          (room['room_number'] ?? 'N/A').toString(),
          r['inspector_id']?.toString() ?? 'N/A',
          r['status']?.toString() ?? 'OK',
          '"${(r['issue_description'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          '"${(r['resolution_details'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          (r['actual_cost'] ?? 0.0).toString(),
          r['inspection_date']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'inspections_${_selectedBuilding ?? "all"}_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Inspections CSV Export');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importInspectionsFromCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Room Inspections',
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
      final user = _client.auth.currentUser;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cells = line.split(',');
        if (cells.length < 8) continue;

        final building = cells[1].replaceAll('"', '').trim();
        final roomNo = cells[2].trim();
        final status = cells[4].trim();
        final issue = cells[5].replaceAll('"', '').trim();
        final cost = double.tryParse(cells[7].trim()) ?? 0.0;

        // Find room ID matching room_number & building_name
        final roomRes = await _client.from('hostel_rooms')
            .select('id')
            .eq('room_number', roomNo)
            .eq('building_name', building)
            .maybeSingle();

        if (roomRes != null) {
          await _client.from('room_maintenance_records').insert({
            'room_id': roomRes['id'],
            'inspector_id': user?.id,
            'status': status,
            'issue_description': issue,
            'actual_cost': cost,
          });
          successCount++;
        }
      }

      _fetchInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $successCount inspections successfully.'), backgroundColor: Colors.greenAccent));
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
    final textColor = isDark ? Colors.white : Colors.black;

    // Filtered lists
    final List<dynamic> buildings = _rooms.map((r) => r['building_name']?.toString()).whereType<String>().toSet().toList();
    
    final filteredRooms = _rooms.where((r) {
      if (_selectedBuilding == null) return true;
      return r['building_name'] == _selectedBuilding;
    }).toList();

    final filteredRecords = _records.where((r) {
      final rBuilding = r['hostel_rooms']?['building_name'];
      if (_selectedBuilding == null) return true;
      return rBuilding == _selectedBuilding;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
      appBar: AppBar(
        title: Text('ROOM INSPECTION & AUDIT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importInspectionsFromCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportInspectionsToCSV, tooltip: 'Export CSV'),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Building Selector Filter
                Text('SELECT BLOCK / BUILDING FIRST', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBuilding,
                      hint: const Text('SHOW ALL BUILDINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
                      isExpanded: true,
                      onChanged: (val) {
                        setState(() {
                          _selectedBuilding = val;
                          _selectedRoom = null;
                        });
                      },
                      items: [
                        const DropdownMenuItem(value: null, child: Text('ALL BUILDINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ...buildings.map((b) => DropdownMenuItem(value: b, child: Text(b.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInspectionLauncher(isDark, filteredRooms),
                const SizedBox(height: 40),
                _sectionHeader('HISTORICAL AUDIT LOG'),
                const SizedBox(height: 16),
                if (filteredRecords.isEmpty) _emptyState(isDark)
                else ...filteredRecords.map((r) => FadeInUp(child: _buildRecordTile(r, isDark))).toList(),
              ],
            ),
          ),
    );
  }

  Widget _buildInspectionLauncher(bool isDark, List<dynamic> filteredRooms) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEW INSPECTION PROTOCOL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 24),
        _roomDropdown(isDark, filteredRooms),
        const SizedBox(height: 16),
        _statusPicker(isDark),
        const SizedBox(height: 16),
        _buildInputField('ISSUE DESCRIPTION', _descCtrl, isDark, Icons.report_problem_outlined),
        const SizedBox(height: 16),
        _buildInputField('RESOLUTION DETAILS (IF ANY)', _resCtrl, isDark, Icons.build_circle_outlined),
        const SizedBox(height: 16),
        _buildInputField('REPAIR COST (₹)', _costCtrl, isDark, Icons.payments_outlined, isNumeric: true),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _logInspection,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('COMMIT INSPECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _roomDropdown(bool isDark, List<dynamic> filteredRooms) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(child: DropdownButton<dynamic>(
        hint: const Text('SELECT TARGET ROOM', style: TextStyle(fontSize: 12)),
        isExpanded: true, value: _selectedRoom, dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
        items: filteredRooms.map((r) => DropdownMenuItem(value: r, child: Text('UNIT ${r['room_number']} (${r['building_name']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        onChanged: (v) => setState(() => _selectedRoom = v),
      )),
    );
  }

  Widget _statusPicker(bool isDark) {
    final statuses = ['OK', 'Needs Repair', 'Repairing', 'Resolved'];
    return Row(children: statuses.map((s) {
       bool sel = _activeStatus == s;
       return Expanded(child: GestureDetector(onTap: () => setState(() => _activeStatus = s), child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(s.toUpperCase(), style: TextStyle(color: sel ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 7, fontWeight: FontWeight.w900)))));
    }).toList());
  }

  Widget _buildRecordTile(dynamic r, bool isDark) {
    final statusColor = r['status'] == 'OK' ? Colors.greenAccent : (r['status'] == 'Resolved' ? Colors.blueAccent : Colors.orangeAccent);
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('UNIT ${r['hostel_rooms']?['room_number'] ?? 'N/A'} (${r['hostel_rooms']?['building_name'] ?? 'N/A'})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(r['status'], style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold))),
         ]),
         const SizedBox(height: 8),
         Text(r['issue_description'] ?? 'Periodic check-up', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11)),
         if (r['resolution_details'] != null && r['resolution_details'].toString().isNotEmpty) ...[
           const SizedBox(height: 4),
           Text('Res: ${r['resolution_details']}', style: TextStyle(color: Colors.greenAccent.shade700, fontSize: 11, fontStyle: FontStyle.italic)),
         ],
         const SizedBox(height: 12),
         Row(children: [
            Icon(Icons.calendar_month_rounded, size: 12, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(width: 4),
            Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(r['inspection_date'])), style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 9)),
            const Spacer(),
            if ((r['actual_cost'] ?? 0) > 0) Text('₹${r['actual_cost']}', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
         ]),
      ]),
    );
  }

  Widget _buildInputField(String l, TextEditingController c, bool isDark, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: c, keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
      decoration: InputDecoration(
        labelText: l, labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 16),
        filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
      ),
    );
  }

  Widget _sectionHeader(String label) => Text(label, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  Widget _emptyState(bool isDark) => Center(child: Text('NO INSPECTION HISTORY DETECTED', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 9, fontWeight: FontWeight.bold)));
}
