import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

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

  String? _selectedVanId;
  double _lastMeter = 0.0;
  final _todayMeterCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  String? _receiptUrl;

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

  Future<void> _fetchLastMeter(String vanId) async {
    try {
      final res = await _client.from('van_logs').select('latest_meter').eq('van_id', vanId).order('created_at', ascending: false).limit(1).maybeSingle();
      if (mounted) {
        setState(() {
          _lastMeter = (res?['latest_meter'] as num?)?.toDouble() ?? 0.0;
          _selectedVanId = vanId;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _receiptUrl = 'https://hostel-mgmt.up.railway.app/fleet/receipts/${img.name}');
    }
  }

  Future<void> _submitRefuelingLog() async {
    if (_selectedVanId == null || _todayMeterCtrl.text.isEmpty || _litersCtrl.text.isEmpty || _amountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all refueling details.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      await _client.from('van_logs').insert({
        'van_id': _selectedVanId,
        'user_id': user?.id,
        'previous_meter': _lastMeter,
        'latest_meter': double.parse(_todayMeterCtrl.text),
        'fuel_liters': double.parse(_litersCtrl.text),
        'amount_paid': double.parse(_amountCtrl.text),
        'payment_method': _paymentMethod,
        'receipt_url': _receiptUrl,
      });
      _todayMeterCtrl.clear();
      _litersCtrl.clear();
      _amountCtrl.clear();
      _receiptUrl = null;
      _selectedVanId = null;
      _fetchConsoleData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refueling log submitted successfully.'), backgroundColor: Colors.greenAccent));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      setState(() => _isLoading = false);
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

  // ── CSV Export / Import ────────────────────────────────────────────────────

  Future<void> _exportFleetCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Fleet Refueling Logs',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      final headers = ['Log ID', 'Vehicle No', 'Driver/Submitter', 'Prev Meter', 'Latest Meter', 'Distance (km)', 'Fuel Volume (L)', 'Amt Paid (₹)', 'Payment Method', 'Date'];
      buffer.writeln(headers.join(','));

      final targetLogs = _logs.where((l) {
        if (l['created_at'] != null) {
          final dt = DateTime.tryParse(l['created_at'].toString());
          if (dt != null) {
            return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
          }
        }
        return true;
      }).toList();

      for (var l in targetLogs) {
        final van = l['vans'] ?? {};
        final profile = l['profiles'] ?? {};
        final double prev = (l['previous_meter'] as num? ?? 0.0).toDouble();
        final double curr = (l['latest_meter'] as num? ?? 0.0).toDouble();
        final List<String> row = [
          l['id']?.toString() ?? '',
          '"${(van['van_number'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          '"${(profile['full_name'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          prev.toString(),
          curr.toString(),
          (curr - prev).toStringAsFixed(1),
          (l['fuel_liters'] ?? 0.0).toString(),
          (l['amount_paid'] ?? 0.0).toString(),
          l['payment_method']?.toString() ?? 'Cash',
          l['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'fleet_logs_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Fleet Console Logs CSV');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _importFleetCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Fleet Refueling Logs',
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
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cells = line.split(',');
        if (cells.length < 9) continue;

        final vanNo = cells[1].replaceAll('"', '').trim();
        final latestMeter = double.tryParse(cells[4].trim()) ?? 0.0;
        final liters = double.tryParse(cells[6].trim()) ?? 0.0;
        final amount = double.tryParse(cells[7].trim()) ?? 0.0;
        final method = cells[8].replaceAll('"', '').trim();

        // Find van ID
        final vanRes = await _client.from('vans').select('id').eq('van_number', vanNo).maybeSingle();
        if (vanRes != null) {
          final user = _client.auth.currentUser;
          await _client.from('van_logs').insert({
            'van_id': vanRes['id'],
            'user_id': user?.id,
            'previous_meter': latestMeter - 100, // Estimate distance delta or fallback
            'latest_meter': latestMeter,
            'fuel_liters': liters,
            'amount_paid': amount,
            'payment_method': method,
          });
          successCount++;
        }
      }

      _fetchConsoleData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $successCount refueling logs successfully.'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
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
            Text('ADD NEW VEHICLE', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 20),
            TextField(controller: numCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15), decoration: InputDecoration(labelText: 'VEHICLE NUMBER (e.g. MH12AB1234)', labelStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 16),
            TextField(controller: driverCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15), decoration: InputDecoration(labelText: 'DEFAULT DRIVER NAME', labelStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { if (numCtrl.text.isNotEmpty) { _addNewVan(numCtrl.text, driverCtrl.text); Navigator.pop(c); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent), child: const Text('REGISTER VEHICLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15))))
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
        title: Text('FLEET CONSOLE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importFleetCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportFleetCSV, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.greenAccent, size: 24), onPressed: () => _showAddVanModal(isDark)),
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent, size: 24), onPressed: () async {
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
                                  _buildOverviewMetrics(totalCost, totalLiters, isDark),
                                  const SizedBox(height: 24),
                                  _buildRefuelingForm(isDark),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, color: Colors.white10),
                          Expanded(
                            flex: 5,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: dateFiltered.isEmpty ? 1 : dateFiltered.length,
                              itemBuilder: (c, idx) {
                                if (dateFiltered.isEmpty) {
                                  return Center(child: Padding(padding: const EdgeInsets.only(top: 80), child: Text('NO REFUELLING EVENTS TODAY', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, fontSize: 12))));
                                }
                                return _buildLogCard(dateFiltered[idx], isDark);
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile View: Default Scrollable view
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildOverviewMetrics(totalCost, totalLiters, isDark),
                          const SizedBox(height: 32),
                          _buildRefuelingForm(isDark),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('REFUELING CHRONOLOGY', style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                              Text(DateFormat('MMM dd').format(_selectedDate).toUpperCase(), style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (dateFiltered.isEmpty)
                            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text('NO REFUELLING EVENTS TODAY', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, fontSize: 12))))
                          else
                            ...dateFiltered.map((log) => _buildLogCard(log, isDark)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewMetrics(double totalCost, double totalLiters, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FLEET LIFETIME OUTLAY', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('₹${totalCost.toInt()}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('TOTAL FUEL COST', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${totalLiters.toStringAsFixed(1)}L', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                const Text('TOTAL VOLUME INJECTED', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
              ])
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefuelingForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REFUELING DISPATCH', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedVanId,
                hint: const Text('SELECT VEHICLE UNIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
                isExpanded: true,
                onChanged: (v) {
                  if (v != null) _fetchLastMeter(v);
                },
                items: _vans.map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['van_number'].toString().toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _infoBox('PREVIOUS METER READING (km)', _lastMeter.toStringAsFixed(1), isDark),
          const SizedBox(height: 16),
          _inputBox('CURRENT METER READING (km)', _todayMeterCtrl, isDark, icon: Icons.speed_rounded),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _inputBox('VOLUME (L)', _litersCtrl, isDark, icon: Icons.local_gas_station_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _inputBox('AMOUNT PAID (₹)', _amountCtrl, isDark, icon: Icons.payments_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECEIPT ATTACHED', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
              IconButton(icon: Icon(Icons.camera_alt_rounded, color: _receiptUrl != null ? Colors.greenAccent : Colors.indigoAccent), onPressed: _pickReceipt),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submitRefuelingLog, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('COMMIT FUEL ENTRY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))))
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
              Text(van?['van_number'] ?? 'FLEET UNIT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('₹${log['amount_paid']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Volume: ${log['fuel_liters']}L', style: const TextStyle(fontSize: 13, color: Colors.white60)),
              Text('Distance: ${delta.toStringAsFixed(1)}km', style: const TextStyle(fontSize: 13, color: Colors.white60)),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Refueled By: ${profile?['full_name'] ?? 'Driver'}', style: const TextStyle(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.bold)),
              if (log['receipt_url'] != null)
                GestureDetector(
                  onTap: () {
                    showDialog(context: context, builder: (_) => Dialog(child: Container(padding: const EdgeInsets.all(8), child: Image.network(log['receipt_url'], fit: BoxFit.contain))));
                  },
                  child: const Row(children: [Icon(Icons.receipt_long_rounded, color: Colors.greenAccent, size: 14), SizedBox(width: 4), Text('VIEW RECEIPT', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))]),
                )
            ],
          )
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value, bool isDark) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]));
  }

  Widget _inputBox(String label, TextEditingController ctrl, bool isDark, {IconData? icon}) {
    return TextField(controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), prefixIcon: icon != null ? Icon(icon, size: 16) : null, filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))));
  }
}
