import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';
import 'admin_outpass_screen.dart';
import 'admin_guest_invitations_screen.dart';
import 'admin_unified_payment_approvals.dart';

class AdminApprovalsCenterScreen extends StatefulWidget {
  const AdminApprovalsCenterScreen({super.key});

  @override
  State<AdminApprovalsCenterScreen> createState() => _AdminApprovalsCenterScreenState();
}

class _AdminApprovalsCenterScreenState extends State<AdminApprovalsCenterScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportApprovalsToCSV() async {
    final activeTab = _tabController.index;
    String title = 'Approvals';
    if (activeTab == 0) title = 'Payment Approvals';
    if (activeTab == 1) title = 'Outpass Approvals';
    if (activeTab == 2) title = 'Guest Invitations';

    final range = await showCsvRangeDialog(
      context: context,
      title: title,
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';

      if (activeTab == 0) {
        // Payments
        buffer.writeln('Order/Ref ID,User Name,Amount (₹),Payment Method,Status,Created At');
        final res = await _client.from('shop_orders').select('*, profiles(*)').gte('created_at', range.startDate.toIso8601String()).lte('created_at', range.endDate.toIso8601String());
        for (var o in res) {
          final profile = o['profiles'] ?? {};
          buffer.writeln('${o['id']},"${profile['full_name'] ?? 'User'}",${o['total_price']},${o['payment_method']},${o['order_status']},${o['created_at']}');
        }
      } else if (activeTab == 1) {
        // Outpasses
        buffer.writeln('Outpass ID,Student Name,Reason,Departure,Arrival,Status,Created At');
        final res = await _client.from('hostel_outpasses').select('*, profiles:user_id(*)').gte('created_at', range.startDate.toIso8601String()).lte('created_at', range.endDate.toIso8601String());
        for (var o in res) {
          final profile = o['profiles'] ?? {};
          buffer.writeln('${o['id']},"${profile['full_name'] ?? 'Student'}","${o['reason'] ?? ''}",${o['departure_time']},${o['arrival_time']},${o['status']},${o['created_at']}');
        }
      } else {
        // Guests
        buffer.writeln('Invite ID,Host Name,Guest Name,Relation,Status,Arrival,Created At');
        final res = await _client.from('guest_invitations').select('*, profiles:user_id(*)').gte('created_at', range.startDate.toIso8601String()).lte('created_at', range.endDate.toIso8601String());
        for (var g in res) {
          final profile = g['profiles'] ?? {};
          buffer.writeln('${g['id']},"${profile['full_name'] ?? 'Host'}","${g['guest_name']}","${g['relationship'] ?? ''}",${g['status']},${g['check_in_time']},${g['created_at']}');
        }
      }

      final filename = '${activeTab == 0 ? "payments" : activeTab == 1 ? "outpasses" : "guests"}_approvals_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Approvals CSV Export');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importApprovalsFromCSV() async {
    final activeTab = _tabController.index;
    String title = 'Approvals';
    if (activeTab == 0) title = 'Payment Approvals';
    if (activeTab == 1) title = 'Outpass Approvals';
    if (activeTab == 2) title = 'Guest Invitations';

    final range = await showCsvRangeDialog(
      context: context,
      title: title,
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
        if (cells.length < 5) continue;

        final id = cells[0].trim();
        final status = cells[4].trim();

        if (id.isNotEmpty && id.length > 5) {
          if (activeTab == 0) {
            await _client.from('shop_orders').update({'order_status': status}).eq('id', id);
          } else if (activeTab == 1) {
            await _client.from('hostel_outpasses').update({'status': status, 'approved_by': user?.id}).eq('id', id);
          } else {
            await _client.from('guest_invitations').update({'status': status, 'approved_by': user?.id}).eq('id', id);
          }
          successCount++;
        }
      }

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated $successCount approvals from CSV successfully.'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _buildSidebarTile(int index, String title, IconData icon) {
    final active = _tabController.index == index;
    return ListTile(
      leading: Icon(icon, color: active ? Colors.indigoAccent : Colors.grey, size: 20),
      title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: active ? Colors.indigoAccent : Colors.grey)),
      selected: active,
      onTap: () {
        setState(() => _tabController.index = index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('APPROVALS CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importApprovalsFromCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportApprovalsToCSV, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), onPressed: () async {
             final d = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
             if (d != null) setState(() => _selectedDate = d);
          }),
        ],
        bottom: MediaQuery.of(context).size.width > 800 
          ? null 
          : TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
              labelColor: Colors.indigoAccent,
              unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
              indicatorColor: Colors.indigoAccent,
              tabs: const [
                Tab(text: 'PAYMENTS', icon: Icon(Icons.payments_rounded, size: 18)),
                Tab(text: 'OUTPASSES', icon: Icon(Icons.calendar_today_rounded, size: 18)),
                Tab(text: 'GUESTS', icon: Icon(Icons.people_rounded, size: 18)),
              ],
            ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Desktop/Wide View: 2-column sidebar design
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        _buildSidebarTile(0, 'PAYMENTS', Icons.payments_rounded),
                        _buildSidebarTile(1, 'OUTPASSES', Icons.calendar_today_rounded),
                        _buildSidebarTile(2, 'GUESTS', Icons.people_rounded),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      AdminUnifiedPaymentApprovals(hideAppBar: true, selectedDate: _selectedDate),
                      AdminOutpassScreen(hideAppBar: true, selectedDate: _selectedDate),
                      AdminGuestInvitationsScreen(hideAppBar: true, selectedDate: _selectedDate),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile View: Default TabBarView
          return TabBarView(
            controller: _tabController,
            children: [
              AdminUnifiedPaymentApprovals(hideAppBar: true, selectedDate: _selectedDate),
              AdminOutpassScreen(hideAppBar: true, selectedDate: _selectedDate),
              AdminGuestInvitationsScreen(hideAppBar: true, selectedDate: _selectedDate),
            ],
          );
        },
      ),
    );
  }
}
