import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../services/database_service.dart';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

class UniversalCampusLedger extends StatefulWidget {
  const UniversalCampusLedger({super.key});

  @override
  State<UniversalCampusLedger> createState() => _UniversalCampusLedgerState();
}

class _UniversalCampusLedgerState extends State<UniversalCampusLedger> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  final TextEditingController _reloadAmtCtrl = TextEditingController();
  final TextEditingController _manualAmtCtrl = TextEditingController();
  final TextEditingController _manualCatCtrl = TextEditingController();
  
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  
  List<dynamic> _allTransactions = [];
  Map<String, dynamic> _khataMap = {};
  List<dynamic> _profiles = [];
  List<dynamic> _rooms = [];
  dynamic _selectedProfile;
  dynamic _selectedRoom;
  
  double _totalIn = 0;
  double _totalOut = 0;
  double _totalOutstandingLent = 0;
  double _adminWalletBalance = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUnifiedData();
    _fetchLookups();
  }

  Future<void> _fetchLookups() async {
    try {
      final pRes = await _client.from('profiles').select().order('full_name');
      final rRes = await _client.from('hostel_rooms').select();
      if (mounted) setState(() { _profiles = pRes; _rooms = rRes; });
    } catch (_) {}
  }

  Future<void> _fetchUnifiedData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;

      List<dynamic> dayBookRes = [];
      try {
        dayBookRes = await _client.from('day_book_entries').select('*, profiles:user_id(*), related_user:target_user_id(*), related_room:related_room_id(*)').order('created_at', ascending: false);
      } catch (e) {
        debugPrint('Error day_book_entries: $e');
      }

      List<dynamic> enrollRes = [];
      try {
        enrollRes = await _client.from('hostel_enrollments').select('*, profiles:user_id(*)');
      } catch (e) {
        debugPrint('Error hostel_enrollments: $e');
      }

      List<dynamic> shopRes = [];
      try {
        shopRes = await _client.from('shop_orders').select('*, profiles:user_id(*)').order('created_at', ascending: false);
      } catch (e) {
        debugPrint('Error shop_orders: $e');
      }

      List<dynamic> payrollRes = [];
      try {
        payrollRes = await _client.from('payroll_records').select('*, profiles:user_id(*)').order('month', ascending: false);
      } catch (e) {
        debugPrint('Error payroll_records: $e');
      }

      List<dynamic> walletRes = [];
      try {
        walletRes = await _client.from('wallet_transactions').select('*, profiles:user_id(*)').order('created_at', ascending: false);
      } catch (e) {
        debugPrint('Error wallet_transactions: $e');
      }
      
      if (user != null) {
        try {
          final profile = await _client.from('profiles').select('balance').eq('id', user.id).maybeSingle();
          _adminWalletBalance = (profile?['balance'] as num? ?? 0).toDouble();
        } catch (_) {}
      }

      List<dynamic> combined = [];
      Map<String, dynamic> kMap = {};
      _totalIn = 0; _totalOut = 0; _totalOutstandingLent = 0;

      // 🧺 Day Book (Maintenance, Damages, Khata)
      for (var e in dayBookRes) {
        final double v = (e['amount'] as num? ?? 0.0).toDouble();
        final isInc = e['entry_type'] == 'Income';
        final ct = DateTime.parse(e['transaction_date'] ?? e['created_at']);
        if (isInc) _totalIn += v; else _totalOut += v;
        
        String title = e['category'] ?? 'Manual Log';
        if (e['related_user'] != null) {
           final rUser = e['related_user'];
           final uid = rUser['id'];
           if (!kMap.containsKey(uid)) kMap[uid] = {'name': rUser['full_name'], 'lent': 0.0, 'recovered': 0.0, 'history': []};
           if (isInc) kMap[uid]['recovered'] += v; else kMap[uid]['lent'] += v;
           kMap[uid]['history'].add(e);
           title = isInc ? 'Damage Recovery: ${rUser['full_name']}' : 'Lent: ${rUser['full_name']}';
        }
        if (e['related_room'] != null) {
           title = 'Maintenance: Room ${e['related_room']['room_number']}';
        }
        
        combined.add({...e, 'origin': 'Manual', 'val': v, 'is_income': isInc, 'title': title, 'date': ct});
      }

      // 🧺 Rent (Dues)
      for (var e in enrollRes) {
        final profile = e['profiles'] ?? {};
        final double rent = (e['total_price'] as num? ?? e['monthly_rent'] as num? ?? 0.0).toDouble();
        final double outstanding = (e['outstanding_dues'] as num? ?? 0.0).toDouble();
        final name = profile['full_name'] ?? 'Student';
        if (outstanding > 0) {
          _totalOutstandingLent += outstanding;
          final uid = e['user_id'];
          if (uid != null) {
            if (!kMap.containsKey(uid)) kMap[uid] = {'name': name, 'lent': 0.0, 'recovered': 0.0, 'history': []};
            kMap[uid]['lent'] += outstanding;
          }
          combined.add({
            'id': e['id'],
            'title': 'Outstanding Rent Dues: $name',
            'origin': 'Hostel Rent',
            'val': outstanding,
            'is_income': false,
            'date': DateTime.parse(e['created_at'] ?? DateTime.now().toIso8601String())
          });
        }
      }

      // 🧺 Shop Orders (UPI/Cash)
      for (var o in shopRes) {
        final profile = o['profiles'] ?? {};
        final double total = (o['total_price'] as num? ?? 0.0).toDouble();
        final status = o['order_status'] ?? 'Completed';
        if (status == 'Completed' || status == 'Delivered') {
          _totalIn += total;
          combined.add({
            'id': o['id'],
            'title': 'Canteen Order: ${profile['full_name'] ?? 'Customer'}',
            'origin': 'Campus Shop',
            'val': total,
            'is_income': true,
            'date': DateTime.parse(o['created_at'])
          });
        }
      }

      // 🧺 Payroll (Salary Expense)
      for (var p in payrollRes) {
        final profile = p['profiles'] ?? {};
        final double sal = (p['salary_amount'] as num? ?? 0.0).toDouble();
        final status = p['status']?.toString().toUpperCase() ?? 'PENDING';
        if (status == 'PAID') {
          _totalOut += sal;
          combined.add({
            'id': p['id'],
            'title': 'Salary Payout: ${profile['full_name'] ?? 'Employee'}',
            'origin': 'Payroll',
            'val': sal,
            'is_income': false,
            'date': DateTime.parse(p['paid_at'] ?? p['created_at'])
          });
        }
      }

      // 🧺 Wallet Topups
      for (var w in walletRes) {
        final profile = w['profiles'] ?? {};
        final double amt = (w['amount'] as num? ?? 0.0).toDouble();
        final type = w['transaction_type'] ?? 'Reload';
        if (type == 'Reload' || type == 'Topup') {
          _totalIn += amt;
          combined.add({
            'id': w['id'],
            'title': 'Wallet Topup: ${profile['full_name'] ?? 'User'}',
            'origin': 'Digital Wallet',
            'val': amt,
            'is_income': true,
            'date': DateTime.parse(w['created_at'])
          });
        }
      }

      // Compute lent balances
      kMap.forEach((key, val) {
        final double outstanding = (val['lent'] as double) - (val['recovered'] as double);
        if (outstanding > 0) _totalOutstandingLent += outstanding;
      });

      if (mounted) {
        setState(() {
          _allTransactions = combined;
          _khataMap = kMap;
          _isLoading = false;
        });
      }
    } catch (err) {
      debugPrint('General ledger load failure: $err');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── CSV Range-based Export ──────────────────────────────────────────────────

  Future<void> _exportLedgerCSV() async {
    final activeTab = _tabController.index; // 0 = Ledger, 1 = Khatabook
    final range = await showCsvRangeDialog(
      context: context,
      title: activeTab == 1 ? 'Khata Balances' : 'Unified DayBook Ledger',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      if (activeTab == 1) {
        // Export Khata
        buffer.writeln('User ID,Customer Name,Lent Amount (₹),Recovered Amount (₹),Balance Outstanding (₹)');
        _khataMap.forEach((uid, val) {
          final double lent = val['lent'] ?? 0.0;
          final double rec = val['recovered'] ?? 0.0;
          final double bal = lent - rec;
          buffer.writeln('$uid,"${val['name'].toString().replaceAll('"', '""')}",$lent,$rec,$bal');
        });
      } else {
        // Export Ledger
        buffer.writeln('Transaction ID,Title,Source,Amount (₹),Flow,Transaction Date');
        final filtered = _allTransactions.where((t) {
          final dt = t['date'] as DateTime;
          return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
        }).toList();

        for (var t in filtered) {
          buffer.writeln('${t['id'] ?? ''},"${t['title'].toString().replaceAll('"', '""')}","${t['origin']}",${t['val']},${t['is_income'] ? "IN" : "OUT"},${t['date']}');
        }
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = '${activeTab == 1 ? "khata" : "unified_ledger"}_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Ledger CSV');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Range-based Import ──────────────────────────────────────────────────

  Future<void> _importLedgerCSV() async {
    final activeTab = _tabController.index;
    final range = await showCsvRangeDialog(
      context: context,
      title: activeTab == 1 ? 'Khata Balances' : 'Unified DayBook Ledger',
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

      if (activeTab == 1) {
        // Import Khata: inserts manual DayBook entries to represent debts
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final cells = line.split(',');
          if (cells.length < 4) continue;

          final uid = cells[0].trim();
          final lentAmt = double.tryParse(cells[2].trim()) ?? 0.0;
          if (uid.isNotEmpty && lentAmt > 0) {
            await _client.from('day_book_entries').insert({
              'entry_type': 'Expense',
              'amount': lentAmt,
              'category': 'Imported Debt',
              'target_user_id': uid,
              'user_id': user?.id,
              'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            });
            successCount++;
          }
        }
      } else {
        // Import Ledger: inserts manual entries to day_book_entries
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final cells = line.split(',');
          if (cells.length < 5) continue;

          final title = cells[1].replaceAll('"', '').trim();
          final source = cells[2].replaceAll('"', '').trim();
          final amount = double.tryParse(cells[3].trim()) ?? 0.0;
          final flow = cells[4].trim();

          if (amount > 0) {
            await _client.from('day_book_entries').insert({
              'entry_type': flow == 'IN' ? 'Income' : 'Expense',
              'amount': amount,
              'category': '$source: $title',
              'user_id': user?.id,
              'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            });
            successCount++;
          }
        }
      }

      _fetchUnifiedData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $successCount transactions successfully.'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _commitManualTransaction() async {
    final amt = double.tryParse(_manualAmtCtrl.text);
    if (amt == null || amt <= 0) return;
    try {
      final user = _client.auth.currentUser;
      final category = _manualCatCtrl.text.isNotEmpty ? _manualCatCtrl.text : 'Miscellaneous';
      
      await _client.from('day_book_entries').insert({
        'entry_type': _totalOut >= 0 ? 'Expense' : 'Income', // Set type based on context
        'amount': amt,
        'category': category,
        'user_id': user?.id,
        'target_user_id': _selectedProfile?['id'],
        'related_room_id': _selectedRoom?['id'],
        'transaction_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });

      _manualAmtCtrl.clear();
      _manualCatCtrl.clear();
      _selectedProfile = null;
      _selectedRoom = null;
      _fetchUnifiedData();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TRANSACTION COMMITTED TO UNIVERSAL LEDGER'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showManualTransactionModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setStateModal) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(c).viewInsets.bottom + 24),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MANUAL LEDGER DISPATCH', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 24),
              _inputField('AMOUNT (₹)', _manualAmtCtrl, isDark, Icons.payments_rounded, isNumeric: true),
              const SizedBox(height: 16),
              _inputField('CATEGORY / REMARKS', _manualCatCtrl, isDark, Icons.tag_rounded),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: _selectedProfile,
                    hint: const Text('LINK TO MEMBER / DEBTOR (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
                    isExpanded: true,
                    onChanged: (val) => setStateModal(() => _selectedProfile = val),
                    items: _profiles.map((p) => DropdownMenuItem(value: p, child: Text(p['full_name']?.toString().toUpperCase() ?? 'USER', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: _selectedRoom,
                    hint: const Text('LINK TO BUILDING ROOM (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
                    isExpanded: true,
                    onChanged: (val) => setStateModal(() => _selectedRoom = val),
                    items: _rooms.map((r) => DropdownMenuItem(value: r, child: Text('${r['building_name']} - Room ${r['room_number']}'.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _commitManualTransaction,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('COMMIT ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Filter transaction list by date
    final dateFiltered = _allTransactions.where((tx) {
       final dt = tx['date'] as DateTime;
       return dt.year == _selectedDate.year && dt.month == _selectedDate.month && dt.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('UNIVERSAL LEDGER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importLedgerCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportLedgerCSV, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent, size: 24), onPressed: () => _showManualTransactionModal(isDark)),
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent, size: 24), onPressed: _pickDate),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
          labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'STATEMENT'),
            Tab(text: 'KHATA LEDGER'),
            Tab(text: 'ANALYTICS'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              Positioned(top: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle)))),
              TabBarView(
                controller: _tabController,
                children: [
                  // 1. Statements Tab
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildSummaryShield(isDark, dateFiltered),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionHeader('DAILY CHRONOLOGY'),
                          Text(DateFormat('MMM dd, yyyy').format(_selectedDate).toUpperCase(), style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (dateFiltered.isEmpty) _emptyState(isDark)
                      else ...dateFiltered.map((tx) => _buildTransactionTile(tx, isDark)),
                    ],
                  ),
                  
                  // 2. Khata Ledger Tab
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.indigoAccent.withOpacity(0.1))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('OUTSTANDING LOANS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                              Text('₹${_totalOutstandingLent.toInt()}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                            ]),
                            IconButton(
                              icon: const Icon(Icons.wallet_giftcard_rounded, color: Colors.greenAccent, size: 28),
                              onPressed: () => _showTopUpModal(isDark),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _sectionHeader('ACTIVE MEMBERS BALANCES'),
                      const SizedBox(height: 16),
                      if (_khataMap.isEmpty) _emptyState(isDark)
                      else ..._khataMap.entries.map((entry) {
                        final val = entry.value;
                        final double lent = val['lent'] ?? 0.0;
                        final double rec = val['recovered'] ?? 0.0;
                        final double outstanding = lent - rec;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(val['name']?.toString().toUpperCase() ?? 'MEMBER', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Lent: ₹${lent.toInt()} | Recovered: ₹${rec.toInt()}', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                              ]),
                              Text('₹${outstanding.toInt()}', style: GoogleFonts.outfit(color: outstanding > 0 ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                  
                  // 3. Analytics Tab
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _sectionHeader('CASHFLOW ANALYTICS'),
                      const SizedBox(height: 16),
                      _buildExpenseChart(isDark),
                      const SizedBox(height: 32),
                      _sectionHeader('FISCAL METRICS'),
                      const SizedBox(height: 16),
                      _buildMetricGrid(isDark),
                    ],
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildSummaryShield(bool isDark, List<dynamic> filtered) {
    double tin = 0; double tout = 0;
    for (var tx in filtered) { if (tx['is_income']) tin += tx['val']; else tout += tx['val']; }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.indigoAccent.withOpacity(0.1))),
      child: Row(children: [
        _statColumn('INFLOW', '₹${tin.toInt()}', Colors.greenAccent),
        Container(width: 1, height: 40, color: Colors.indigoAccent.withOpacity(0.1)),
        _statColumn('OUTFLOW', '₹${tout.toInt()}', Colors.redAccent),
        Container(width: 1, height: 40, color: Colors.indigoAccent.withOpacity(0.1)),
        _statColumn('NET CASH', '₹${(tin - tout).toInt()}', Colors.indigoAccent),
      ]),
    );
  }

  Widget _statColumn(String l, String v, Color c) => Expanded(child: Column(children: [Text(l, style: const TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)), Text(v, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 18))]));

  Widget _buildTransactionTile(dynamic tx, bool isDark) {
    final bool isInc = tx['is_income'] ?? false;
    final Color color = isInc ? Colors.greenAccent : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(isInc ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 18)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(tx['title'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
           Text(tx['origin']?.toString().toUpperCase() ?? 'Khatabook', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ])),
        Text('${isInc ? "+" : "-"}₹${tx['val'].toInt()}', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
      ]),
    );
  }

  Widget _buildExpenseChart(bool isDark) {
    Map<String, double> dailyData = {};
    final now = DateTime.now(); for (int i = 6; i >= 0; i--) { dailyData[DateFormat('EE').format(now.subtract(Duration(days: i)))] = 0; }
    for (var tx in _allTransactions) { if (!tx['is_income']) { final dt = tx['date'] as DateTime; if (now.difference(dt).inDays < 7) { final day = DateFormat('EE').format(dt); dailyData[day] = (dailyData[day] ?? 0) + tx['val']; } } }
    final chartData = dailyData.values.toList(); final chartLabels = dailyData.keys.toList();
    return Container(height: 250, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))), child: LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: FlTitlesData(topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => val.toInt() >= 0 && val.toInt() < chartLabels.length ? Text(chartLabels[val.toInt()], style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)) : const SizedBox()))), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: List.generate(chartData.length, (i) => FlSpot(i.toDouble(), chartData[i])), isCurved: true, color: Colors.indigoAccent, barWidth: 3, belowBarData: BarAreaData(show: true, color: Colors.indigoAccent.withOpacity(0.1)))])));
  }

  void _showTopUpModal(bool isDark) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => StatefulBuilder(builder: (c, setModalState) => Container(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24), decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('FISCAL RELOAD', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 32), _inputField('AMOUNT (₹)', _reloadAmtCtrl, isDark, Icons.payments_rounded, isNumeric: true), const SizedBox(height: 32), ElevatedButton(onPressed: () async { final amount = double.tryParse(_reloadAmtCtrl.text); if (amount == null || amount <= 0) return; await DatabaseService().reloadWallet(amount, 'RELOAD: UPI_PROTOCOL'); Navigator.pop(context); _reloadAmtCtrl.clear(); _fetchUnifiedData(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('AUTHORIZE RELOAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)))]))));
  }

  void _pickDate() async { final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now()); if (picked != null) { setState(() => _selectedDate = picked); _fetchUnifiedData(); } }

  Widget _inputField(String l, TextEditingController c, bool isDark, IconData icon, {bool isNumeric = false}) { return Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: TextField(controller: c, keyboardType: isNumeric ? TextInputType.number : TextInputType.text, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold), decoration: InputDecoration(icon: Icon(icon, color: Colors.indigoAccent, size: 18), border: InputBorder.none, labelText: l, labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900)))); }

  Widget _buildMetricGrid(bool isDark) { double totalOut = _allTransactions.where((t) => !t['is_income']).fold(0, (sum, t) => sum + t['val']); return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.5, children: [_metricCard('DAILY AVG', '₹${(totalOut / 30).toStringAsFixed(0)}', Colors.greenAccent, isDark), _metricCard('WEEKLY BURN', '₹${(totalOut / 4).toStringAsFixed(0)}', Colors.orangeAccent, isDark), _metricCard('MONTHLY EST', '₹${totalOut.toInt()}', Colors.indigoAccent, isDark), _metricCard('UTILIZATION', '82%', Colors.purpleAccent, isDark)]); }

  Widget _metricCard(String l, String v, Color c, bool isDark) { return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 4), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold))])); }

  Widget _sectionHeader(String label) => Text(label, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  Widget _emptyState(bool isDark) => Container(padding: const EdgeInsets.all(40), child: Center(child: Text('NO DATA DETECTED FOR THIS PERIOD', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold))));
}
