import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/user_avatar.dart';
import 'admin_audit_nexus_screen.dart';
import '../finance/universal_campus_ledger.dart';
import '../finance/fiscal_calendar_screen.dart';
import '../finance/student_rent_mess_history_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/csv_range_dialog.dart';
import '../../utils/csv_web_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminFinanceHubScreen extends StatefulWidget {
  final bool hideAppBar;
  final String? filterType; // 'Rent' or 'Mess'
  final DateTime? initialDate;
  const AdminFinanceHubScreen({super.key, this.hideAppBar = false, this.filterType, this.initialDate});

  @override
  State<AdminFinanceHubScreen> createState() => _AdminFinanceHubScreenState();
}

class _AdminFinanceHubScreenState extends State<AdminFinanceHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  double _liquidity = 0;
  
  // Analytics - Rentals
  double _totalExpectedRent = 0;
  double _collectedRent = 0;
  int _studentsPaidCount = 0;
  int _totalStudentsCount = 0;
  List<dynamic> _defaulters2Months = [];

  // Analytics - Payroll
  double _payrollPaidTotal = 0;
  double _payrollPendingTotal = 0;
  int _employeesPaidCount = 0;
  int _totalEmployeesCount = 0;

  List<dynamic> _rentCollections = [];
  List<dynamic> _activeMessCards = [];
  List<dynamic> _expiringSoonCards = [];
  List<dynamic> _expiredMessCards = [];
  
  List<dynamic> _hostelStudents = [];
  List<dynamic> _payrollLogs = [];
  List<dynamic> _shopOrders = [];
  List<dynamic> _pendingApprovals = [];
  List<dynamic> _dayBookEntries = [];

  // 🛡️ ANALYTICS DATA (PERIODIC)
  DateTime? _filterDate;
  double _todayRevenue = 0;
  double _monthRevenue = 0;
  int _todayOrders = 0;
  int _monthOrders = 0;
  int _todayMessRenewals = 0;

  @override
  void initState() {
    super.initState();
    _filterDate = widget.initialDate;
    final initialIndex = widget.filterType == 'Rent' ? 1 : (widget.filterType == 'Mess' ? 2 : 0);
    _tabController = TabController(length: 6, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadFinanceData();
  }

  Future<void> _exportMessCardsToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Mess Cards',
      isImport: false,
    );
    if (range == null) return;
    try {
      final List<String> csvHeaders = [
        'id', 'user_id', 'card_number', 'status', 'expiry_date', 'meals_allowed',
        'is_nfc_synced', 'last_sync_at', 'temp_balance'
      ];
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));
      final allCards = _activeMessCards + _expiringSoonCards + _expiredMessCards;
      final filtered = allCards.where((c) {
        final dt = DateTime.tryParse(c['last_sync_at']?.toString() ?? c['created_at']?.toString() ?? '');
        if (dt == null) return true;
        return dt.isAfter(range.startDate.subtract(const Duration(days: 1))) &&
               dt.isBefore(range.endDate.add(const Duration(days: 1)));
      }).toList();
      for (var c in filtered) {
        final List<String> row = [
          c['id']?.toString() ?? '',
          c['user_id']?.toString() ?? '',
          c['card_number']?.toString() ?? '',
          c['status']?.toString() ?? '',
          c['expiry_date']?.toString() ?? '',
          '"${(c['meals_allowed']?.toString() ?? '').replaceAll('"', '""')}"',
          (c['is_nfc_synced'] ?? false).toString(),
          c['last_sync_at']?.toString() ?? '',
          (c['temp_balance'] ?? 0.0).toString(),
        ];
        buffer.writeln(row.join(','));
      }
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'mess_cards_$dateLabel.csv';
      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Mess Cards Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exportRentalsToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Rent Collections',
      isImport: false,
    );
    if (range == null) return;
    try {
      final List<String> csvHeaders = ['id', 'user_id', 'amount', 'collection_type', 'payment_method', 'created_at'];
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));
      final filtered = _rentCollections.where((r) {
        final dt = DateTime.tryParse(r['created_at']?.toString() ?? '');
        if (dt == null) return true;
        return dt.isAfter(range.startDate.subtract(const Duration(days: 1))) &&
               dt.isBefore(range.endDate.add(const Duration(days: 1)));
      }).toList();
      for (var r in filtered) {
        final List<String> row = [
          r['id']?.toString() ?? '',
          r['user_id']?.toString() ?? '',
          r['amount']?.toString() ?? '0',
          r['collection_type']?.toString() ?? 'Rent',
          r['payment_method']?.toString() ?? '',
          r['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'rent_collections_$dateLabel.csv';
      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Rent Collections Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exportPayrollToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Payroll Records',
      isImport: false,
    );
    if (range == null) return;
    try {
      final List<String> csvHeaders = ['id', 'employee_id', 'amount', 'month', 'status', 'created_at'];
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));
      final filtered = _payrollLogs.where((p) {
        final dt = DateTime.tryParse(p['created_at']?.toString() ?? '');
        if (dt == null) return true;
        return dt.isAfter(range.startDate.subtract(const Duration(days: 1))) &&
               dt.isBefore(range.endDate.add(const Duration(days: 1)));
      }).toList();
      for (var p in filtered) {
        final List<String> row = [
          p['id']?.toString() ?? '',
          p['employee_id']?.toString() ?? '',
          p['amount']?.toString() ?? '0',
          p['month']?.toString() ?? '',
          p['status']?.toString() ?? '',
          p['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'payroll_$dateLabel.csv';
      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Payroll Records Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exportShopOrdersToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Shop Orders',
      isImport: false,
    );
    if (range == null) return;
    try {
      final List<String> csvHeaders = ['id', 'user_id', 'total_price', 'payment_method', 'order_status', 'created_at'];
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));
      final filtered = _shopOrders.where((o) {
        final dt = DateTime.tryParse(o['created_at']?.toString() ?? '');
        if (dt == null) return true;
        return dt.isAfter(range.startDate.subtract(const Duration(days: 1))) &&
               dt.isBefore(range.endDate.add(const Duration(days: 1)));
      }).toList();
      for (var o in filtered) {
        final List<String> row = [
          o['id']?.toString() ?? '',
          o['user_id']?.toString() ?? '',
          o['total_price']?.toString() ?? '0',
          o['payment_method']?.toString() ?? '',
          o['order_status']?.toString() ?? '',
          o['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'shop_orders_$dateLabel.csv';
      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Shop Orders Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exportLedgerToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Finance Ledger',
      isImport: false,
    );
    if (range == null) return;
    try {
      final List<String> csvHeaders = ['name', 'type', 'amount', 'date'];
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));
      
      List<dynamic> combinedLogs = [];
      for (var e in _hostelStudents) {
        final paid = double.tryParse(e['paid_amount']?.toString() ?? '0') ?? 0;
        if (paid > 0) combinedLogs.add({'type': 'RENT_IN', 'val': paid, 'date': e['updated_at'] ?? e['created_at'], 'name': e['profiles']?['full_name'] ?? 'RESIDENT'});
      }
      for (var s in _shopOrders) {
        if (s['order_status'] != 'Cancelled') combinedLogs.add({'type': 'SHOP_IN', 'val': (s['total_price'] ?? 0).toDouble(), 'date': s['created_at'], 'name': s['profiles']?['full_name'] ?? 'CUSTOMER'});
      }
      for (var p in _payrollLogs) {
        combinedLogs.add({'type': 'PAYROLL_OUT', 'val': double.tryParse(p['amount']?.toString() ?? '0') ?? 0, 'date': p['month'], 'name': p['profiles']?['full_name'] ?? 'EMPLOYEE'});
      }
      for (var m in _dayBookEntries) {
        final isInc = m['entry_type'] == 'Income';
        combinedLogs.add({'type': isInc ? 'MANUAL_IN' : 'MANUAL_OUT', 'val': (m['amount'] as num).toDouble(), 'date': m['created_at'], 'name': m['category'] ?? 'MANUAL'});
      }
      combinedLogs.sort((a,b) => DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));

      // Filter by range
      final filtered = combinedLogs.where((l) {
        final dt = DateTime.tryParse(l['date']?.toString() ?? '');
        if (dt == null) return true;
        return dt.isAfter(range.startDate.subtract(const Duration(days: 1))) &&
               dt.isBefore(range.endDate.add(const Duration(days: 1)));
      }).toList();

      for (var l in filtered) {
        final List<String> row = [
          '"${l['name'].toString().replaceAll('"', '""')}"',
          l['type'].toString(),
          l['val']?.toString() ?? '0',
          l['date']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'finance_ledger_$dateLabel.csv';
      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Finance Ledger Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _importMessCardsFromCSV() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final List<String> lines = await file.readAsLines();
      if (lines.length < 2) throw 'File is empty or missing headers';
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      int successCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final List<String> cells = [];
        bool inQuotes = false;
        StringBuffer currentCell = StringBuffer();
        for (int c = 0; c < line.length; c++) {
          final char = line[c];
          if (char == '"') {
            inQuotes = !inQuotes;
          } else if (char == ',' && !inQuotes) {
            cells.add(currentCell.toString().trim());
            currentCell.clear();
          } else {
            currentCell.write(char);
          }
        }
        cells.add(currentCell.toString().trim());
        
        final Map<String, dynamic> payload = {};
        String? cardId;
        
        for (int cellIdx = 0; cellIdx < cells.length; cellIdx++) {
          if (cellIdx >= headers.length) break;
          final header = headers[cellIdx];
          final val = cells[cellIdx].replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"');
          
          if (header == 'id') {
            if (val.isNotEmpty && val.length > 5) cardId = val;
          } else if (header == 'user_id') {
            payload['user_id'] = val;
          } else if (header == 'card_number') {
            payload['card_number'] = val;
          } else if (header == 'status') {
            payload['status'] = val;
          } else if (header == 'expiry_date') {
            payload['expiry_date'] = val.isEmpty ? null : val;
          } else if (header == 'meals_allowed') {
            payload['meals_allowed'] = val.isEmpty ? [] : val.split(';');
          } else if (header == 'is_nfc_synced') {
            payload['is_nfc_synced'] = val.toLowerCase() == 'true';
          } else if (header == 'last_sync_at') {
            payload['last_sync_at'] = val.isEmpty ? null : val;
          } else if (header == 'temp_balance') {
            payload['temp_balance'] = double.tryParse(val) ?? 0.0;
          }
        }
        
        if (payload['user_id'] == null) continue;
        
        if (cardId != null) {
          await _client.from('mess_cards').update(payload).eq('id', cardId);
        } else {
          await _client.from('mess_cards').insert(payload);
        }
        successCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully processed $successCount mess card records'), backgroundColor: Colors.indigoAccent));
        _loadFinanceData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _loadFinanceData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();
    try {
      _todayRevenue = 0; 
      _monthRevenue = 0;
      _todayOrders = 0;
      _monthOrders = 0;
      _todayMessRenewals = 0;

      // 🛡️ ISOLATED TRANSACTION: Enrollments
      try {
        final res = await _client.from('hostel_enrollments').select('*, profiles:user_id(*), hostel_rooms(*)').order('room_id');
        setState(() {
          _hostelStudents = res;
          _totalExpectedRent = 0; _collectedRent = 0; _studentsPaidCount = 0; _defaulters2Months = [];
          for (var e in res) {
             final double total = double.tryParse(e['total_price']?.toString() ?? '0') ?? 0;
             final double paid = double.tryParse(e['paid_amount']?.toString() ?? '0') ?? 0;
             _totalExpectedRent += total; _collectedRent += paid;
             if (paid >= total && total > 0) _studentsPaidCount++;
             else if (total - paid > 0) _defaulters2Months.add(e);
             
             final ct = DateTime.tryParse(e['created_at']?.toString() ?? '');
             if (ct != null && ct.year == now.year && ct.month == now.month && ct.day == now.day) { _todayRevenue += paid; }
             if (ct != null && ct.year == now.year && ct.month == now.month) { _monthRevenue += paid; }
          }
        });
      } catch (e) { debugPrint('🚨 ENROLLMENT_SYNC_FAILURE: $e'); }

      // 🛡️ ISOLATED TRANSACTION: Day Book (Manual Entries)
      List<dynamic> manualEntries = [];
      try {
        manualEntries = await _client.from('day_book_entries').select('*, profiles:user_id(*)').order('created_at', ascending: false);
        for (var e in manualEntries) {
           final double amt = (e['amount'] as num).toDouble();
           final isInc = e['entry_type'] == 'Income';
           final ct = DateTime.tryParse(e['transaction_date']?.toString() ?? e['created_at']?.toString() ?? '');
           if (ct != null && ct.year == now.year && ct.month == now.month && ct.day == now.day && isInc) { _todayRevenue += amt; }
           if (ct != null && ct.year == now.year && ct.month == now.month && isInc) { _monthRevenue += amt; }
        }
      } catch (e) { debugPrint('🚨 DAYBOOK_SYNC_FAILURE: $e'); }

      // 🛡️ ISOLATED TRANSACTION: Mess Cards
      try {
        final res = await _client.from('mess_cards').select('*, profiles:user_id(*)').order('expiry_date', ascending: true);
        final soon = now.add(const Duration(days: 5));
        setState(() {
          _activeMessCards = res.where((m) => m['expiry_date'] != null && DateTime.parse(m['expiry_date']).isAfter(soon)).toList();
          _expiringSoonCards = res.where((m) => m['expiry_date'] != null && DateTime.parse(m['expiry_date']).isAfter(now) && DateTime.parse(m['expiry_date']).isBefore(soon)).toList();
          _expiredMessCards = res.where((m) => m['expiry_date'] == null || DateTime.parse(m['expiry_date']).isBefore(now) || m['status'] == 'Expired').toList();
          for (var m in res) {
            final ut = DateTime.tryParse(m['updated_at']?.toString() ?? '');
            if (ut != null && ut.year == now.year && ut.month == now.month && ut.day == now.day) _todayMessRenewals++;
          }
        });
      } catch (e) { debugPrint('🚨 MESS_SYNC_FAILURE: $e'); }

      // 🛡️ ISOLATED TRANSACTION: Shop orders
      try {
        final res = await _client.from('shop_orders').select('*, profiles:user_id(*)').order('created_at', ascending: false);
        double totalShop = 0;
        for (var s in res) {
           final double p = (s['total_price'] ?? 0).toDouble();
           if (s['order_status'] != 'Cancelled') totalShop += p;
           final ct = DateTime.tryParse(s['created_at']?.toString() ?? '');
           if (ct != null && ct.year == now.year && ct.month == now.month && ct.day == now.day) { _todayOrders++; _todayRevenue += p; }
           if (ct != null && ct.year == now.year && ct.month == now.month) { _monthOrders++; _monthRevenue += p; }
        }
        setState(() { _shopOrders = res; _liquidity = (_collectedRent + totalShop) - _payrollPaidTotal; });
      } catch (e) { debugPrint('🚨 SHOP_SYNC_FAILURE: $e'); }
      
      // Store manual entries for the ledger
      _dayBookEntries = manualEntries;

      final census = await _client.from('profiles').select().inFilter('role', ['hostel_student', 'mess_student']);
      final staff = await _client.from('profiles').select().inFilter('role', ['staff', 'admin', 'owner']);
      final appRes = await _client.from('payment_approvals').select('*, profiles:user_id(*)').eq('status', 'Pending');
      
      if (mounted) setState(() { 
        _totalStudentsCount = census.length; 
        _totalEmployeesCount = staff.length;
        _pendingApprovals = appRes;
        _isLoading = false; 
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final showSidebar = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.hideAppBar ? null : AppBar(
        title: Text('FINANCE HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_tabController.index == 2)
            IconButton(
              icon: const Icon(Icons.file_upload_rounded, color: Colors.indigoAccent),
              tooltip: 'Import Mess Cards',
              onPressed: _importMessCardsFromCSV,
            ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: Colors.indigoAccent),
            tooltip: 'Export Tab Data',
            onPressed: () {
              switch (_tabController.index) {
                case 1:
                  _exportRentalsToCSV();
                  break;
                case 2:
                  _exportMessCardsToCSV();
                  break;
                case 3:
                  _exportPayrollToCSV();
                  break;
                case 4:
                  _exportShopOrdersToCSV();
                  break;
                case 5:
                  _exportLedgerToCSV();
                  break;
                default:
                  _exportLedgerToCSV(); // Default backup fallback
                  break;
              }
            },
          ),
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), onPressed: () async {
             final d = await showDatePicker(context: context, initialDate: _filterDate ?? DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
             if (d != null) { setState(() => _filterDate = d); _loadFinanceData(); }
          }),
        ],
        bottom: showSidebar 
          ? null 
          : TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.indigoAccent,
              indicatorWeight: 3,
              labelColor: Colors.indigoAccent,
              unselectedLabelColor: textColor.withOpacity(0.3),
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 14), text: 'OVERVIEW'),
                Tab(icon: Icon(Icons.bed_rounded, size: 14), text: 'RENTALS'),
                Tab(icon: Icon(Icons.restaurant_rounded, size: 14), text: 'MESS CARDS'),
                Tab(icon: Icon(Icons.payments_rounded, size: 14), text: 'PAYROLL'),
                Tab(icon: Icon(Icons.shopping_bag_rounded, size: 14), text: 'SHOP'),
                Tab(icon: Icon(Icons.menu_book_rounded, size: 14), text: 'LEDGER'),
              ],
            ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : LayoutBuilder(
            builder: (context, constraints) {
              if (showSidebar) {
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
                            _buildFinanceSidebarTile(0, 'OVERVIEW', Icons.dashboard_customize_rounded),
                            _buildFinanceSidebarTile(1, 'RENTALS', Icons.bed_rounded),
                            _buildFinanceSidebarTile(2, 'MESS CARDS', Icons.restaurant_rounded),
                            _buildFinanceSidebarTile(3, 'PAYROLL', Icons.payments_rounded),
                            _buildFinanceSidebarTile(4, 'SHOP', Icons.shopping_bag_rounded),
                            _buildFinanceSidebarTile(5, 'LEDGER', Icons.menu_book_rounded),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                           _buildOverviewTab(isDark),
                           _buildRentalsTab(isDark),
                           _buildMessCardsTab(isDark),
                           _buildPayrollTab(isDark),
                           _buildShopTab(isDark),
                           _buildLedgerTab(isDark),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // 🛡️ PREVENT PARENT TAB BUBBLING
                children: [
                   _buildOverviewTab(isDark),
                   _buildRentalsTab(isDark),
                   _buildMessCardsTab(isDark),
                   _buildPayrollTab(isDark),
                   _buildShopTab(isDark),
                   _buildLedgerTab(isDark),
                ],
              );
            },
          ),
    );
  }

  Widget _buildFinanceSidebarTile(int index, String label, IconData icon) {
    final active = _tabController.index == index;
    return ListTile(
      selected: active,
      selectedTileColor: Colors.indigoAccent.withOpacity(0.08),
      leading: Icon(icon, color: active ? Colors.indigoAccent : Colors.grey),
      title: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: active ? Colors.indigoAccent : Colors.grey)),
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildLiquidityCard(isDark),
        const SizedBox(height: 24),
        if (_pendingApprovals.isNotEmpty) ...[
          _sectionHeader('ALL PENDING PAYMENT PROOFS (${_pendingApprovals.length})', color: Colors.orangeAccent),
          const SizedBox(height: 12),
          Text(
            'Review incoming UPI/screenshot proofs across Hostel, Mess, Shop, Mandi & Fast Food',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11),
          ),
          const SizedBox(height: 16),
          ..._pendingApprovals.map((a) => _buildApprovalTile(a, isDark)).toList(),
          const SizedBox(height: 32),
          Divider(color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 24),
        ],
        Row(children: [
           Expanded(child: _miniStat('TODAY REV', '₹${_todayRevenue.toInt()}', Colors.indigoAccent, isDark)),
           const SizedBox(width: 12),
           Expanded(child: _miniStat('THIS MONTH', '₹${_monthRevenue.toInt()}', Colors.blueAccent, isDark)),
        ]),
        const SizedBox(height: 32),
        _buildRevenueGraph(isDark),
        const SizedBox(height: 32),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _statBox('KHATA (OUTSTANDING)', '₹24.5K', Icons.menu_book_rounded, Colors.amberAccent, isDark),
            _statBox('EST. MONTHLY', '₹${(_totalExpectedRent / 1000).toStringAsFixed(1)}K', Icons.trending_up, Colors.indigoAccent, isDark),
            _statBox('STAFF PAYROLL', '₹${(_payrollPaidTotal / 1000).toStringAsFixed(1)}K', Icons.payments_outlined, Colors.greenAccent, isDark),
            _statBox('PENDING DUES', '₹${(_payrollPendingTotal / 1000).toStringAsFixed(1)}K', Icons.pending_actions, Colors.orangeAccent, isDark),
          ],
        ),
        const SizedBox(height: 32),
        _sectionHeader('FINANCE TOOLS'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _heroAction('UNIVERSAL LEDGER', Icons.receipt_long_rounded, Colors.indigoAccent, isDark, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalCampusLedger()));
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _heroAction('GENERATE REPORT', Icons.summarize_outlined, Colors.tealAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalCampusLedger()))),
          ),
        ]),
      ],
    );
  }

  Widget _buildRentalsTab(bool isDark) {
    final pending = _pendingApprovals.where((a) => a['payment_type'] == 'Rent').toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('PENDING RENT VERIFICATIONS', color: Colors.orangeAccent),
          const SizedBox(height: 16),
          ...pending.map((a) => _buildApprovalTile(a, isDark)).toList(),
          const SizedBox(height: 32),
          Divider(color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 24),
        ],

        _sectionHeader('COLLECTION ANALYTICS'), 
        const SizedBox(height: 16),
        _buildRentalAnalyticsGrid(isDark),
        const SizedBox(height: 32),

        Row(children: [
             Expanded(child: _heroAction('ADD RESIDENT', Icons.person_add_alt_rounded, Colors.indigoAccent, isDark)),
             const SizedBox(width: 12),
             Expanded(child: _heroAction('RENT CASH', Icons.payments_outlined, Colors.greenAccent, isDark, onTap: () => _showCashEntryDialog('Rent', isDark))),
        ]),
        const SizedBox(height: 24),
        _heroAction('WALLET TOPUP', Icons.account_balance_wallet_rounded, Colors.purpleAccent, isDark, onTap: () => _showCashEntryDialog('Wallet', isDark)),
        
        const SizedBox(height: 48),
        _sectionHeader('CHRONIC DEFAULTERS (DUE BALANCES)', color: Colors.redAccent),
        const SizedBox(height: 16),
        if (_defaulters2Months.isEmpty) _emptyState('NO PENDING DUES', isDark)
        else ..._defaulters2Months.map((s) => _buildResidentTile(s, isDark, isDefaulter: true)).toList(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildMessCardsTab(bool isDark) {
    final pending = _pendingApprovals.where((a) => a['payment_type'] == 'MessCard').toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('PENDING RENEWAL VERIFICATIONS', color: Colors.orangeAccent),
          const SizedBox(height: 16),
          ...pending.map((a) => _buildApprovalTile(a, isDark)).toList(),
          const SizedBox(height: 32),
          Divider(color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 24),
        ],

        _sectionHeader('MESS CARD ANALYTICS'),
        const SizedBox(height: 16),
        _buildMessAnalyticsGrid(isDark),
        const SizedBox(height: 32),

        _heroAction('RENEW SERVICE CASH', Icons.credit_score_rounded, Colors.greenAccent, isDark, onTap: () => _showCashEntryDialog('MessCard', isDark)),
        
        const SizedBox(height: 48),
        if (_expiringSoonCards.isNotEmpty) ...[
          _sectionHeader('EXPIRING SOON (<5D)', color: Colors.orangeAccent),
          const SizedBox(height: 16),
          ..._expiringSoonCards.map((m) => _buildMessCardTile(m, isDark, color: Colors.orangeAccent)).toList(),
          const SizedBox(height: 32),
        ],
        
        _sectionHeader('ACTIVE SERVICE CARDS', color: Colors.greenAccent),
        const SizedBox(height: 16),
        ..._activeMessCards.map((m) => _buildMessCardTile(m, isDark, color: Colors.greenAccent)).toList(),
        
        const SizedBox(height: 48),
        _sectionHeader('EXPIRED CARDS', color: Colors.redAccent),
        const SizedBox(height: 16),
        if (_expiredMessCards.isEmpty) _emptyState('NO EXPIRED CARDS', isDark)
        else ..._expiredMessCards.map((m) => _buildMessCardTile(m, isDark, color: Colors.redAccent, isExpired: true)).toList(),
      ],
    );
  }

  Widget _buildApprovalsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader('PENDING UPI VERIFICATIONS'),
        const SizedBox(height: 16),
        if (_pendingApprovals.isEmpty) _emptyState('NO PENDING APPROVALS', isDark)
        else ..._pendingApprovals.map((a) => _buildApprovalTile(a, isDark)).toList(),
      ],
    );
  }

  Widget _buildApprovalTile(dynamic a, bool isDark) {
    final pType = (a['payment_type'] ?? 'Rent').toString();
    final bool isRent = pType.toLowerCase().contains('rent');
    final bool isMess = pType.toLowerCase().contains('mess');
    final bool isWallet = pType.toLowerCase().contains('wallet');
    final iconData = isRent 
        ? Icons.bed_rounded 
        : (isMess ? Icons.restaurant_rounded : (isWallet ? Icons.account_balance_wallet_rounded : Icons.shopping_bag_rounded));

    final studentName = a['profiles']?['full_name'] ?? 'STUDENT';
    final amount = a['amount'] ?? 0;
    final dateStr = a['created_at'] != null ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(a['created_at'].toString())) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.indigoAccent.withOpacity(0.12),
              child: Icon(iconData, color: Colors.indigoAccent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          pType.toUpperCase(),
                          style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹$amount • $dateStr',
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.zoom_in_rounded, size: 14),
              label: const Text('PROOF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent.withOpacity(0.15),
                foregroundColor: Colors.indigoAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showScreenshotDialog(a['screenshot_url'], isDark),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('APPROVE & CONFIRM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _approvePayment(a),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('REJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.15),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _rejectPayment(a),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approvePayment(dynamic a) async {
    try {
      final pType = (a['payment_type'] ?? 'Rent').toString();
      final double amt = double.tryParse(a['amount']?.toString() ?? '0') ?? 0.0;
      final userId = a['user_id']?.toString() ?? '';

      if (pType == 'Rent' || pType.toLowerCase().contains('rent')) {
        // Record in fiscal_collections with schema safe fallback
        try {
          await _client.from('fiscal_collections').insert({
            'user_id': userId,
            'student_id': userId,
            'amount': amt,
            'total_amount': amt,
            'room_rent': amt,
            'collection_type': 'Rent',
            'payment_method': 'UPI',
            'collection_cycle': DateFormat('MMMM yyyy').format(DateTime.now()),
            'status': 'Approved',
          });
        } catch (_) {
          // Fallback if student_id or room_rent is missing in legacy schema cache
          await _client.from('fiscal_collections').insert({
            'user_id': userId,
            'amount': amt,
            'collection_type': 'Rent',
            'payment_method': 'UPI',
          });
        }
      } else if (pType == 'Mess' || pType == 'MessCard' || pType.toLowerCase().contains('mess')) {
        // Activate mess card aligned to the student's DOJ billing cycle
        final now = DateTime.now();
        DateTime cycleStart = now;
        DateTime cycleEnd = now.add(const Duration(days: 30));
        try {
          final enrollRes = await _client.from('hostel_enrollments').select('created_at').eq('user_id', userId).maybeSingle();
          final profileRes2 = await _client.from('profiles').select('date_of_joining').eq('id', userId).maybeSingle();
          final joinDateStr = enrollRes?['created_at'] ?? profileRes2?['date_of_joining'];
          if (joinDateStr != null) {
            final joined = DateTime.parse(joinDateStr.toString());
            final joinDay = joined.day > 28 ? 28 : joined.day;
            final candidateStart = DateTime(now.year, now.month, joinDay);
            if (now.isBefore(candidateStart)) {
              final prevMonth = now.month == 1 ? 12 : now.month - 1;
              final prevYear  = now.month == 1 ? now.year - 1 : now.year;
              cycleStart = DateTime(prevYear, prevMonth, joinDay);
              cycleEnd   = candidateStart;
            } else {
              cycleStart = candidateStart;
              final nextMonth = now.month == 12 ? 1 : now.month + 1;
              final nextYear  = now.month == 12 ? now.year + 1 : now.year;
              cycleEnd = DateTime(nextYear, nextMonth, joinDay);
            }
          }
        } catch (_) {}
        try {
          await _client.from('mess_cards').upsert({
            'user_id': userId,
            'start_date': cycleStart.toIso8601String(),
            'expiry_date': cycleEnd.toIso8601String(),
            'card_type': 'Standard',
            'status': 'Active',
            'card_number': 'MC-${userId.substring(0, 8).toUpperCase()}',
          }, onConflict: 'user_id');
        } catch (_) {
          await _client.from('mess_cards').upsert({
            'user_id': userId,
            'start_date': cycleStart.toIso8601String(),
            'expiry_date': cycleEnd.toIso8601String(),
            'card_type': 'Standard',
            'status': 'Active',
          }, onConflict: 'user_id');
        }
      } else if (pType.toLowerCase().contains('shop') || pType.toLowerCase().contains('mandi') || pType.toLowerCase().contains('fastfood')) {
        // Mark related shop order paid
        if (a['order_id'] != null) {
          try {
            await _client.from('shop_orders').update({
              'payment_status': 'Paid',
              'order_status': 'Confirmed'
            }).eq('id', a['order_id']);
          } catch (_) {}
        }
      } else if (pType.toLowerCase().contains('wallet')) {
        // Credit student wallet
        try {
          final profileRes = await _client.from('profiles').select('balance').eq('id', userId).maybeSingle();
          final curBal = double.tryParse(profileRes?['balance']?.toString() ?? '0') ?? 0.0;
          await _client.from('profiles').update({'balance': curBal + amt}).eq('id', userId);
          await _client.from('wallet_transactions').insert({
            'user_id': userId,
            'amount': amt,
            'transaction_type': 'UPI_APPROVAL',
            'status': 'completed',
          });
        } catch (_) {}
      }

      try {
        await _client.from('payment_approvals').update({
          'status': 'Approved',
          'admin_notes': 'Verified and approved by admin',
        }).eq('id', a['id']);
      } catch (colErr) {
        debugPrint('payment_approvals update with admin_notes failed, updating without: $colErr');
        await _client.from('payment_approvals').update({
          'status': 'Approved',
        }).eq('id', a['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved ${a['payment_type']} of ₹${a['amount']} successfully!'), backgroundColor: Colors.greenAccent),
        );
      }
      _loadFinanceData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _rejectPayment(dynamic a) async {
    final noteCtrl = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('REJECT PAYMENT PROOF', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('State reason for rejection so the student can rectify and resubmit:', style: GoogleFonts.outfit(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. UTR mismatch, blurry screenshot, invalid amount',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('REJECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      final reason = noteCtrl.text.trim().isEmpty ? 'Payment proof unverified' : noteCtrl.text.trim();
      try {
        await _client.from('payment_approvals').update({
          'status': 'Rejected',
          'admin_notes': reason,
        }).eq('id', a['id']);
      } catch (colErr) {
        debugPrint('payment_approvals reject with admin_notes failed, retrying without: $colErr');
        await _client.from('payment_approvals').update({
          'status': 'Rejected',
        }).eq('id', a['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment proof marked as Rejected ($reason)'), backgroundColor: Colors.redAccent),
        );
      }
      _loadFinanceData();
    }
  }

  void _showCashEntryDialog(String type, bool isDark) async {
     final userSearchCtrl = TextEditingController();
     double defaultAmt = 0;
     try {
       final cat = type == 'Rent' ? 'Hostel' : (type == 'Mess' ? 'Mess' : 'Laundry');
       final feeRow = await _client.from('fee_structure').select().eq('category', cat).limit(1).maybeSingle();
       if (feeRow != null && feeRow['price'] != null) {
         defaultAmt = (feeRow['price'] as num).toDouble();
       }
     } catch (_) {}
     final amountCtrl = TextEditingController(text: defaultAmt > 0 ? defaultAmt.toInt().toString() : '');
     List<dynamic> searchResults = [];

     if (!mounted) return;
     showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: AlertDialog(
       backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
       title: Text('ADMIN ${type.toUpperCase()}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
       content: Column(mainAxisSize: MainAxisSize.min, children: [
         TextField(controller: userSearchCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(labelText: 'SEARCH STUDENT NAME', labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10)), onChanged: (v) async {
            if (v.length > 2) {
               final r = await _client.from('profiles').select().ilike('full_name', '%$v%').limit(5);
               setModalState(() => searchResults = r);
            }
         }),
         if (searchResults.isNotEmpty) Container(height: 80, child: ListView(children: searchResults.map((s) => ListTile(title: Text(s['full_name'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 11)), onTap: () { userSearchCtrl.text = s['full_name']; setModalState(() { searchResults = [s]; }); })).toList())),
         const SizedBox(height: 16),
         TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(labelText: 'AMOUNT (₹)', labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10))),
       ]),
       actions: [
         TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
         ElevatedButton(onPressed: () async {
            if (searchResults.isEmpty) return;
            final student = searchResults.first;
            if (type == 'Rent') {
               await _client.from('fiscal_collections').insert({'user_id': student['id'], 'amount': double.parse(amountCtrl.text), 'collection_type': 'Rent', 'payment_method': 'Cash'});
             } else if (type == 'Mess') {
                 // DOJ-aligned billing cycle for cash entries
                 final now2 = DateTime.now();
                 DateTime cs = now2; DateTime ce = now2.add(const Duration(days: 30));
                 try {
                   final er = await _client.from('hostel_enrollments').select('created_at').eq('user_id', student['id']).maybeSingle();
                   final pr2 = await _client.from('profiles').select('date_of_joining').eq('id', student['id']).maybeSingle();
                   final jd = er?['created_at'] ?? pr2?['date_of_joining'];
                   if (jd != null) {
                     final j2 = DateTime.parse(jd.toString());
                     final jday = j2.day > 28 ? 28 : j2.day;
                     final cand = DateTime(now2.year, now2.month, jday);
                     if (now2.isBefore(cand)) {
                       final pm = now2.month == 1 ? 12 : now2.month - 1;
                       final py = now2.month == 1 ? now2.year - 1 : now2.year;
                       cs = DateTime(py, pm, jday); ce = cand;
                     } else {
                       cs = cand;
                       final nm = now2.month == 12 ? 1 : now2.month + 1;
                       final ny = now2.month == 12 ? now2.year + 1 : now2.year;
                       ce = DateTime(ny, nm, jday);
                     }
                   }
                 } catch (_) {}
                 await _client.from('mess_cards').upsert({
                   'user_id': student['id'],
                   'start_date': cs.toIso8601String(),
                   'expiry_date': ce.toIso8601String(),
                   'card_type': 'Standard',
                   'status': 'Active',
                   'card_number': 'MC-${student['id'].toString().substring(0, 8).toUpperCase()}',
                 }, onConflict: 'user_id');
             } else if (type == 'Wallet') {
               // Admin direct top-up logic
               final currentBal = (student['balance'] ?? 0.0) as num;
               final add = double.parse(amountCtrl.text);
               await _client.from('profiles').update({'balance': currentBal + add}).eq('id', student['id']);
               await _client.from('wallet_transactions').insert({
                 'user_id': student['id'],
                 'amount': add,
                 'transaction_type': 'ADMIN_RECHARGE',
                 'status': 'completed',
               });
            }
            Navigator.pop(ctx);
            _loadFinanceData();
         }, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent), child: const Text('CONFIRM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
       ],
     ))));
  }

  // REUSABLE HELPERS
  Future<void> _sendWhatsAppReminder({
    required String phone,
    required String studentName,
    required String title,
    required double amount,
    String? details,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = Uri.encodeComponent(
      'Hello $studentName,\n\n'
      'This is an official payment notice from Campus Administration regarding your *$title*.\n\n'
      'Pending Amount Due: ₹${amount.toInt()}\n'
      '${details != null && details.isNotEmpty ? "Details: $details\n" : ""}'
      'Date Issued: ${DateFormat("dd MMM yyyy").format(DateTime.now())}\n\n'
      'Please clear your dues promptly via the Campus App or UPI to avoid interruption of hostel/mess services.\n'
      'Thank you.'
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place call')));
    }
  }

  Widget _buildResidentTile(dynamic s, bool isDark, {bool isDefaulter = false}) {
     final enrollment = s['hostel_rooms'] != null ? s : s['hostel_enrollments']?[0];
     final room = s['hostel_rooms'] ?? enrollment?['hostel_rooms'];
     final profile = s['profiles'] ?? s;
     bool isVerified = profile?['is_verified'] ?? false;
     
     final double total = double.tryParse(enrollment?['total_price']?.toString() ?? '0') ?? 0;
     final double paid = double.tryParse(enrollment?['paid_amount']?.toString() ?? '0') ?? 0;
     final double due = (total - paid).clamp(0, double.infinity);
     final String phone = profile?['phone_no'] ?? s['phone_no'] ?? '';
     final String name = profile?['full_name'] ?? 'STUDENT';
     final String roomNum = room != null ? room['room_number']?.toString() ?? '' : '';

     return Container(
       margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: isDefaulter ? Colors.redAccent.withOpacity(0.06) : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)), 
         borderRadius: BorderRadius.circular(24), 
         border: Border.all(color: isDefaulter ? Colors.redAccent.withOpacity(0.4) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), width: isDefaulter ? 1.5 : 1)
       ),
       child: Column(children: [
         Row(children: [
           UserAvatar(imageUrl: profile?['avatar_url'], radius: 25, verified: isVerified, name: name),
           const SizedBox(width: 16),
           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(due > 0 ? 'PENDING DUE: ₹${due.toInt()}' : 'CLEARED', style: TextStyle(color: due > 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
           ])),
           if (room != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('ROOM $roomNum', style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900))),
         ]),
         const SizedBox(height: 16),
         Divider(color: isDark ? Colors.white10 : Colors.black12),
         const SizedBox(height: 12),
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _miniContact(Icons.phone_outlined, phone.isNotEmpty ? phone : 'N/A', Colors.greenAccent, isDark),
            _miniContact(Icons.verified_user_outlined, isVerified ? 'VERIFIED' : 'PENDING', isVerified ? Colors.blueAccent : Colors.orangeAccent, isDark),
            _miniContact(Icons.bloodtype_outlined, s['blood_group'] ?? 'UNK', Colors.redAccent, isDark),
         ]),
         if (isDefaulter && phone.isNotEmpty) ...[
           const SizedBox(height: 14),
           Row(
             children: [
               Expanded(
                 child: ElevatedButton.icon(
                   onPressed: () => _sendWhatsAppReminder(
                     phone: phone,
                     studentName: name,
                     title: 'Hostel Accommodation Rent',
                     amount: due,
                     details: 'Room $roomNum dues pending. Total Fee: ₹${total.toInt()}, Paid: ₹${paid.toInt()}',
                   ),
                   icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                   label: const Text('WHATSAPP REMINDER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                   style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
                 ),
               ),
               const SizedBox(width: 8),
               ElevatedButton.icon(
                 onPressed: () => _makePhoneCall(phone),
                 icon: const Icon(Icons.call_rounded, size: 14, color: Colors.white),
                 label: const Text('CALL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
               ),
             ],
           ),
         ],
       ]),
     );
  }

  Widget _buildMessCardTile(dynamic m, bool isDark, {Color color = Colors.indigoAccent, bool isExpired = false}) {
    final profile = m['profiles'];
    if (m['expiry_date'] == null) return const SizedBox.shrink();
    final expiry = DateTime.parse(m['expiry_date']);
    final isExpiringSoon = !isExpired && expiry.difference(DateTime.now()).inDays <= 3;
    final displayColor = isExpired ? Colors.redAccent : (isExpiringSoon ? Colors.amberAccent : color);
    final String phone = profile?['phone_no'] ?? '';
    final String name = profile?['full_name'] ?? 'STUDENT';
    final double cardPrice = double.tryParse(m['price']?.toString() ?? '2500') ?? 2500;

    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: displayColor.withOpacity(isExpired ? 0.08 : 0.04), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: displayColor.withOpacity(isExpired ? 0.5 : 0.2), width: isExpired ? 1.5 : 1)
      ),
      child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: displayColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.restaurant_rounded, color: displayColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (isExpired) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)), child: const Text('EXPIRED', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900))),
                  ] else if (isExpiringSoon) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(6)), child: const Text('EXPIRING SOON', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w900))),
                  ],
                ],
              ),
              Text('Expires: ${DateFormat('MMM dd, yyyy').format(expiry)} (${isExpired ? "EXPIRED" : "${expiry.difference(DateTime.now()).inDays} days left"})', style: TextStyle(color: displayColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: displayColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(m['card_type'].toString().toUpperCase(), style: TextStyle(color: displayColor, fontSize: 8, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12), Divider(color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               _miniDetail('PHONE', phone.isNotEmpty ? phone : 'N/A', Colors.white24, isDark),
               _miniDetail('STATUS', isExpired ? 'RENEWAL REQD' : (isExpiringSoon ? 'EXPIRING' : 'ACTIVE'), displayColor, isDark),
          ]),
          if ((isExpired || isExpiringSoon) && phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendWhatsAppReminder(
                      phone: phone,
                      studentName: name,
                      title: 'Mess Card Renewal (${m['card_type']})',
                      amount: cardPrice,
                      details: 'Mess Card ${isExpired ? "expired on ${DateFormat('dd MMM').format(expiry)}" : "expires on ${DateFormat('dd MMM').format(expiry)}"}. Renewal Plan: ₹${cardPrice.toInt()}',
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                    label: const Text('WHATSAPP RENEWAL NOTICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(phone),
                  icon: const Icon(Icons.call_rounded, size: 14, color: Colors.white),
                  label: const Text('CALL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                ),
              ],
            ),
          ],
      ]),
    );
  }



  Widget _buildMessAnalyticsGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _analyticsMetric('ACTIVE', '${_activeMessCards.length}', Colors.greenAccent, isDark),
              _analyticsMetric('EXPIRING', '${_expiringSoonCards.length}', Colors.orangeAccent, isDark),
              _analyticsMetric('EXPIRED', '${_expiredMessCards.length}', Colors.redAccent, isDark),
          ]),
      ]),
    );
  }

  Widget _buildRentalTile(dynamic r, bool isDark) {
    final profile = r['profiles'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: Colors.indigoAccent.withOpacity(0.1), child: const Icon(Icons.person_outline, color: Colors.indigoAccent, size: 16)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile?['full_name'] ?? 'STUDENT', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Type: ${r['collection_type'] ?? 'Rent'}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
            ])),
            Text('₹${(r['amount'] ?? 0).toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
            if (r['receipt_screenshot_url'] != null)
              IconButton(icon: const Icon(Icons.image_search_rounded, color: Colors.indigoAccent, size: 18), onPressed: () => _showScreenshotDialog(r['receipt_screenshot_url'], isDark)),
          ]),
          const SizedBox(height: 16), Divider(color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _miniDetail('RENT', '₹${(r['room_rent'] ?? 0).toInt()}', isDark ? Colors.white38 : Colors.black45, isDark),
            _miniDetail('POWER', '₹${(r['electricity_charges'] ?? 0).toInt()}', Colors.amberAccent, isDark),
            _miniDetail('MISC', '₹${(r['misc_charges'] ?? 0).toInt()}', Colors.pinkAccent, isDark),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              final studentId = r['student_id'] ?? profile?['id'];
              if (studentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentRentMessHistoryScreen(
                      studentId: studentId.toString(),
                      studentName: profile?['full_name'] ?? 'STUDENT',
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.indigoAccent, size: 13),
                  const SizedBox(width: 6),
                  Text('VIEW COMPLETE BREAKDOWN & INVOICE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildPayrollTab(bool isDark) {
    return ListView(padding: const EdgeInsets.all(24), children: [
        _sectionHeader('PAYROLL ANALYTICS'), const SizedBox(height: 16),
        _buildPayrollAnalyticsGrid(isDark),
        const SizedBox(height: 32),
        _sectionHeader('DISBURSEMENT LOGS'), const SizedBox(height: 16),
        ..._payrollLogs.map((p) => _buildPayrollTile(p, isDark)).toList(),
    ]);
  }

  Widget _buildPayrollAnalyticsGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _analyticsMetric('PAID', '$_employeesPaidCount', Colors.greenAccent, isDark),
              _analyticsMetric('PENDING', '${_totalEmployeesCount - _employeesPaidCount}', Colors.orangeAccent, isDark),
              _analyticsMetric('AMT PAID', '₹${(_payrollPaidTotal/1000).toStringAsFixed(1)}K', Colors.indigoAccent, isDark),
          ]),
      ]),
    );
  }

  Widget _buildPayrollTile(dynamic p, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(children: [
          Row(children: [
            const Icon(Icons.badge_outlined, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['profiles']?['full_name'] ?? 'STAFF', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Period: ${DateFormat('MMM yyyy').format(DateTime.parse(p['month']))}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
               Text('₹${(p['amount'] ?? 0).toInt()}', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 20)),
               Text('NET PAY', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _payrollMetric('BASE', '₹${(p['base_salary'] ?? 0).toInt()}', isDark ? Colors.white38 : Colors.black45, isDark),
            _payrollMetric('BONUS', '+₹${(p['allowance'] ?? 0).toInt()}', Colors.blueAccent, isDark),
            _payrollMetric('DEDUCT', '-₹${((p['deductions'] ?? 0) + (p['advances'] ?? 0)).toInt()}', Colors.redAccent, isDark),
          ]),
      ]),
    );
  }

  Widget _buildShopTab(bool isDark) {
    double totalRevenue = 0;
    for (var o in _shopOrders) {
      if (o['order_status'] != 'Cancelled') totalRevenue += (o['total_price'] ?? 0).toDouble();
    }
    
    return ListView(padding: const EdgeInsets.all(24), children: [
        _sectionHeader('SHOP REVENUE ANALYTICS'), const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.pinkAccent.withOpacity(0.1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _analyticsMetric('TOTAL REV', '₹${(totalRevenue/1000).toStringAsFixed(1)}K', Colors.pinkAccent, isDark),
              _analyticsMetric('ORDERS', '${_shopOrders.length}', Colors.indigoAccent, isDark),
              _analyticsMetric('PENDING', '${_shopOrders.where((o) => o['order_status'] == 'Pending').length}', Colors.orangeAccent, isDark),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _sectionHeader('ORDER PIPELINE'), const SizedBox(height: 16),
        ..._shopOrders.map((o) => _buildShopOrderTile(o, isDark)).toList(),
    ]);
  }

  Widget _buildShopOrderTile(dynamic o, bool isDark) {
    bool isUPI = o['payment_method'] == 'UPI';
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(children: [
        Icon(isUPI ? Icons.qr_code_rounded : Icons.account_balance_wallet_outlined, color: o['payment_method'] == 'MessCard' ? Colors.blueAccent : (isUPI ? Colors.orangeAccent : Colors.pinkAccent), size: 20),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(o['profiles']?['full_name'] ?? 'CUSTOMER', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
           Text('Status: ${o['order_status']}', style: TextStyle(color: o['order_status'] == 'Pending' ? Colors.orangeAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        ])),
        if (isUPI && o['upi_screenshot_url'] != null) 
          IconButton(icon: const Icon(Icons.image_outlined, color: Colors.indigoAccent), onPressed: () => _showScreenshotDialog(o['upi_screenshot_url'], isDark)),
        Text('₹${(o['total_price'] ?? 0).toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
      ]),
    );
  }

  void _showScreenshotDialog(String? url, bool isDark) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No screenshot attached.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                  maxWidth: 600,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16181A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: Colors.indigoAccent, size: 18),
                            const SizedBox(width: 8),
                            Text('PAYMENT PROOF VERIFICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                            const Spacer(),
                            Text('Pinch to zoom', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 260,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                                  color: Colors.indigoAccent,
                                ),
                              );
                            },
                            errorBuilder: (c, e, s) => Container(
                              height: 200,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 36),
                                  const SizedBox(height: 8),
                                  Text('Unable to load receipt preview\n$url', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('DISMISS PREVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xFF16181A), const Color(0xFF08090A)] : [const Color(0xFFF1F5F9), Colors.white]), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL BALANCE', style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const Icon(Icons.security_rounded, color: Colors.greenAccent, size: 16),
          ]),
          const SizedBox(height: 12),
          Text('₹${_liquidity.toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: _heroAction('GENERATE REPORT', Icons.summarize_outlined, Colors.indigoAccent, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _heroAction('UNIVERSAL LEDGER', Icons.book_outlined, isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalCampusLedger())))),
          ]),
      ]),
    );
  }

  Widget _buildRentalAnalyticsGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _analyticsMetric('COLLECTED', '₹${(_collectedRent / 1000).toStringAsFixed(1)}K', Colors.greenAccent, isDark),
              _analyticsMetric('TO COLLECT', '₹${((_totalExpectedRent - _collectedRent) / 1000).toStringAsFixed(1)}K', Colors.redAccent, isDark),
          ]),
          const SizedBox(height: 24), Divider(color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _analyticsMetric('STUDENTS PAID', '$_studentsPaidCount', Colors.indigoAccent, isDark),
              _analyticsMetric('PENDING', '${_totalStudentsCount - _studentsPaidCount}', Colors.orangeAccent, isDark),
          ]),
      ]),
    );
  }

  Widget _analyticsMetric(String l, String v, Color c, bool isDark) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const SizedBox(height: 4), Text(v, style: GoogleFonts.outfit(color: c, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1))]);
  
  Widget _buildRevenueGraph(bool isDark) => Container(height: 200, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader('REVENUE TRENDS / 7D'), const Spacer(), Center(child: Text('GRAPH DATA SYNCING...', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 10)))]));
  
  Widget _heroAction(String l, IconData i, Color bg, bool isDark, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 55,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i, color: bg == Colors.greenAccent ? Colors.black : Colors.white, size: 16),
          const SizedBox(width: 12),
          Text(l, style: TextStyle(color: bg == Colors.greenAccent ? Colors.black : Colors.white60, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    ),
  );
  
  Widget _sectionHeader(String l, {Color color = Colors.indigoAccent}) => Text(l, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.5));
  
  Widget _statBox(String l, String v, IconData i, Color c, bool isDark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(i, color: c, size: 20), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w900))])]));
  
  Widget _miniDetail(String l, String v, Color c, bool isDark) => Column(children: [Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)), Text(l, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1))]);
  
  Widget _payrollMetric(String l, String v, Color c, bool isDark) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1)), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 11))]);
  
  Widget _buildLedgerTab(bool isDark) {
     // 🧬 MISSION-CRITICAL: Consolidation of Day Book and Khata Book
     List<dynamic> combinedLogs = [];
     for (var e in _hostelStudents) {
       final paid = double.tryParse(e['paid_amount']?.toString() ?? '0') ?? 0;
       if (paid > 0) combinedLogs.add({'type': 'RENT_IN', 'val': paid, 'date': e['updated_at'] ?? e['created_at'], 'name': e['profiles']?['full_name'] ?? 'RESIDENT'});
     }
     for (var s in _shopOrders) {
       if (s['order_status'] != 'Cancelled') combinedLogs.add({'type': 'SHOP_IN', 'val': (s['total_price'] ?? 0).toDouble(), 'date': s['created_at'], 'name': s['profiles']?['full_name'] ?? 'CUSTOMER'});
     }
     for (var p in _payrollLogs) {
       combinedLogs.add({'type': 'PAYROLL_OUT', 'val': double.tryParse(p['amount']?.toString() ?? '0') ?? 0, 'date': p['month'], 'name': p['profiles']?['full_name'] ?? 'EMPLOYEE'});
     }
     for (var m in _dayBookEntries) {
       final isInc = m['entry_type'] == 'Income';
       combinedLogs.add({'type': isInc ? 'MANUAL_IN' : 'MANUAL_OUT', 'val': (m['amount'] as num).toDouble(), 'date': m['created_at'], 'name': m['category'] ?? 'MANUAL'});
     }
     
     // Chronological Sort
     combinedLogs.sort((a,b) => DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));

     return ListView(
       padding: const EdgeInsets.all(24),
       children: [
         _sectionHeader('DAILY FINANCE LEDGER'),
         const SizedBox(height: 16),
         if (combinedLogs.isEmpty) _emptyState('NO TRANSACTIONS DETECTED', isDark)
         else ...combinedLogs.take(50).map((l) => _buildLedgerTile(l, isDark)).toList(),
         const SizedBox(height: 100),
       ],
     );
  }

  Widget _buildLedgerTile(dynamic l, bool isDark) {
     final type = l['type'];
     final isOut = type == 'PAYROLL_OUT';
     final color = isOut ? Colors.redAccent : Colors.greenAccent;
     final icon = isOut ? Icons.arrow_outward_rounded : Icons.south_west_rounded;
     final date = DateTime.parse(l['date'].toString());
     
     return Container(
       margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
       child: Row(children: [
         Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 14)),
         const SizedBox(width: 16),
         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l['name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
            Text('${type.toString().replaceAll('_', ' ')} • ${DateFormat('MMM dd, hh:mm a').format(date)}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
         ])),
         Text('${isOut ? '-' : '+'}₹${l['val'].toInt()}', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
       ]),
     );
  }

  Widget _miniContact(IconData i, String v, Color c, bool isDark) => Row(children: [Icon(i, color: c, size: 10), const SizedBox(width: 6), Text(v, style: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold))]);
  
  Widget _miniStat(String l, String v, Color c, bool isDark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 4), Text(v, style: GoogleFonts.outfit(color: c, fontSize: 18, fontWeight: FontWeight.w900))]));

  Widget _emptyState(String msg, bool isDark) => Container(padding: const EdgeInsets.all(40), child: Center(child: Text(msg, style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold))));
}
