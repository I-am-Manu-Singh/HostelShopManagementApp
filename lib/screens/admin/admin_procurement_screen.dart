import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';
import '../common/add_procurement_screen.dart';

class AdminProcurementScreen extends StatefulWidget {
  final bool isMandiPOFilter;
  const AdminProcurementScreen({super.key, this.isMandiPOFilter = false});

  @override
  State<AdminProcurementScreen> createState() => _AdminProcurementScreenState();
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class _AdminProcurementScreenState extends State<AdminProcurementScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String _filterStatus = 'ALL';
  String? _filterEmployeeId;
  DateTime? _filterDate;
  late bool _isMandiPOFilter;
  
  List<dynamic> _procurements = [];
  List<dynamic> _staffList = [];

  @override
  void initState() {
    super.initState();
    _isMandiPOFilter = widget.isMandiPOFilter;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchStaff();
    await _fetchProcurements();
  }

  Future<void> _fetchStaff() async {
    try {
      final roleFilter = _isMandiPOFilter ? ['farmer_seller'] : ['staff', 'admin', 'hostel_manager', 'hostel_student', 'mess_student', 'student'];
      final res = await _client.from('profiles').select().inFilter('role', roleFilter);
      if (mounted) setState(() => _staffList = res);
    } catch (_) {}
  }

  Future<void> _fetchProcurements() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_isMandiPOFilter) {
        var query = _client.from('mandi_purchase_orders').select();
        if (_filterStatus != 'ALL') {
          String s = _filterStatus.toLowerCase();
          if (s == 'requested') s = 'sent';
          if (s == 'procured') s = 'received';
          query = query.eq('status', s);
        }
        if (_filterEmployeeId != null) {
          query = query.eq('seller_id', _filterEmployeeId!);
        }
        if (_filterDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(_filterDate!);
          query = query.gte('created_at', '${dateStr}T00:00:00').lte('created_at', '${dateStr}T23:59:59');
        }
        final List<dynamic> res = await query.order('created_at', ascending: false);
        
        final ids = res.map((item) => item['seller_id']).where((id) => id != null).toSet().toList();
        List<dynamic> profilesList = [];
        if (ids.isNotEmpty) {
          profilesList = await _client.from('profiles').select().inFilter('id', ids);
        }
        final profilesMap = {for (var prof in profilesList) prof['id']: prof};
        for (var item in res) {
          final id = item['seller_id'];
          item['profiles'] = profilesMap[id];
        }

        if (mounted) setState(() { _procurements = res; _isLoading = false; });
      } else {
        var query = _client.from('procurements').select();
        if (_filterStatus != 'ALL') {
          query = query.eq('status', _filterStatus.toLowerCase().capitalize());
        }
        if (_filterEmployeeId != null) {
          query = query.eq('requester_id', _filterEmployeeId!);
        }
        if (_filterDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(_filterDate!);
          query = query.gte('created_at', '${dateStr}T00:00:00').lte('created_at', '${dateStr}T23:59:59');
        }
        final List<dynamic> res = await query.order('created_at', ascending: false);
        
        final ids = res.map((item) => item['requester_id']).where((id) => id != null).toSet().toList();
        List<dynamic> profilesList = [];
        if (ids.isNotEmpty) {
          profilesList = await _client.from('profiles').select().inFilter('id', ids);
        }
        final profilesMap = {for (var prof in profilesList) prof['id']: prof};
        for (var item in res) {
          final id = item['requester_id'];
          item['profiles'] = profilesMap[id];
        }

        if (mounted) setState(() { _procurements = res; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final table = _isMandiPOFilter ? 'mandi_purchase_orders' : 'procurements';
      await _client.from(table).update({'status': status}).eq('id', id);
      _fetchProcurements();
    } catch (_) {}
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportProcurementsToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: _isMandiPOFilter ? 'Mandi PO' : 'Canteen/Mess Procurements',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      final headers = _isMandiPOFilter
          ? ['PO ID', 'Seller Name', 'Item Name', 'Qty', 'Rate', 'Total', 'Status', 'Date']
          : ['Procurement ID', 'Requester Name', 'Item Name', 'Qty', 'Estimated Price', 'Status', 'Date'];
      buffer.writeln(headers.join(','));

      final filtered = _procurements.where((p) {
        if (p['created_at'] != null) {
          final dt = DateTime.tryParse(p['created_at'].toString());
          if (dt != null) {
            return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
          }
        }
        return true;
      }).toList();

      for (var p in filtered) {
        final profile = p['profiles'] ?? {};
        final List<String> row = _isMandiPOFilter
            ? [
                p['id']?.toString() ?? '',
                '"${(profile['full_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
                '"${(p['item_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
                (p['quantity'] ?? 0).toString(),
                (p['agreed_rate'] ?? 0.0).toString(),
                (p['total_amount'] ?? 0.0).toString(),
                p['status']?.toString() ?? 'Pending',
                p['created_at']?.toString() ?? '',
              ]
            : [
                p['id']?.toString() ?? '',
                '"${(profile['full_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
                '"${(p['item_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
                (p['quantity'] ?? 0).toString(),
                (p['estimated_price'] ?? 0.0).toString(),
                p['status']?.toString() ?? 'Pending',
                p['created_at']?.toString() ?? '',
              ];
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = '${_isMandiPOFilter ? "mandi_po" : "procurements"}_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Procurement CSV Export');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importProcurementsFromCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: _isMandiPOFilter ? 'Mandi PO' : 'Canteen/Mess Procurements',
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

      final table = _isMandiPOFilter ? 'mandi_purchase_orders' : 'procurements';
      int successCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cells = line.split(',');
        if (cells.length < 5) continue;

        final id = cells[0].trim();
        final status = cells[6].trim();

        if (id.isNotEmpty && id.length > 5) {
          await _client.from(table).update({
            'status': status.toLowerCase(),
          }).eq('id', id);
          successCount++;
        }
      }

      _fetchProcurements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated $successCount procurements from CSV successfully.'), backgroundColor: Colors.greenAccent));
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
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('PROCUREMENT CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importProcurementsFromCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportProcurementsToCSV, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddProcurementScreen())).then((_) => _fetchProcurements());
          }),
        ],
      ),
      body: Column(
        children: [
          // Toggle filter slider between Campus Shop/Mess and Mandi Procurements
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isMandiPOFilter = false;
                          _filterEmployeeId = null;
                        });
                        _loadInitialData();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isMandiPOFilter ? Colors.indigoAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'CANTEEN & MESS',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: !_isMandiPOFilter ? Colors.white : (isDark ? Colors.white38 : Colors.black45),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isMandiPOFilter = true;
                          _filterEmployeeId = null;
                        });
                        _loadInitialData();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isMandiPOFilter ? Colors.indigoAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'MANDI PO',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: _isMandiPOFilter ? Colors.white : (isDark ? Colors.white38 : Colors.black45),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFilterRow(isDark, cardColor, borderColor),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : _procurements.isEmpty
                ? _emptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _procurements.length,
                    itemBuilder: (context, index) => _procurementCard(_procurements[index], isDark, cardColor, borderColor),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isDark, Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          _statusChip('ALL', isDark),
          const SizedBox(width: 8),
          _statusChip('REQUESTED', isDark),
          const SizedBox(width: 8),
          _statusChip('APPROVED', isDark),
          const SizedBox(width: 8),
          _statusChip('PROCURED', isDark),
          const SizedBox(width: 8),
          _statusChip('REJECTED', isDark),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: DropdownButton<String>(
              value: _filterEmployeeId,
              hint: const Text('BY PERSON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              underline: const SizedBox(),
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
              onChanged: (val) {
                setState(() => _filterEmployeeId = val);
                _fetchProcurements();
              },
              items: [
                const DropdownMenuItem(value: null, child: Text('ALL STAFF')),
                ..._staffList.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text((s['full_name'] ?? 'Staff').toString().toUpperCase()))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool isDark) {
    final active = _filterStatus == label;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: active ? Colors.white : (isDark ? Colors.white30 : Colors.black45))),
      selected: active,
      selectedColor: Colors.indigoAccent,
      backgroundColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
      onSelected: (sel) {
        if (sel) {
          setState(() => _filterStatus = label);
          _fetchProcurements();
        }
      },
    );
  }

  Widget _procurementCard(dynamic p, bool isDark, Color cardColor, Color borderColor) {
    final name = p['item_name'] ?? 'Procurement Item';
    final qty = p['quantity'] ?? 0;
    final status = p['status']?.toString().toUpperCase() ?? 'PENDING';
    
    final cost = _isMandiPOFilter 
      ? (p['total_amount'] ?? 0.0)
      : (p['estimated_price'] ?? 0.0);

    final requester = p['profiles']?['full_name'] ?? 'Requester';

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name.toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('₹${cost.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.greenAccent, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: $qty', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_isMandiPOFilter ? 'Seller: $requester' : 'By: $requester', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Divider(height: 24, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusBadge(status),
                if (status == 'PENDING' || status == 'REQUESTED' || status == 'SENT')
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 20), onPressed: () => _updateStatus(p['id'], _isMandiPOFilter ? 'received' : 'Approved')),
                      IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20), onPressed: () => _updateStatus(p['id'], 'Rejected')),
                    ],
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg = Colors.amberAccent.withOpacity(0.12);
    Color fg = Colors.amberAccent;
    if (status == 'APPROVED' || status == 'RECEIVED') { bg = Colors.greenAccent.withOpacity(0.12); fg = Colors.greenAccent; }
    if (status == 'REJECTED') { bg = Colors.redAccent.withOpacity(0.12); fg = Colors.redAccent; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black12),
            const SizedBox(height: 12),
            Text('NO TRANSACTIONS RECORDED', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
