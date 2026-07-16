import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

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
      
      // 🧬 FETCH STRATEGY: Universal Data Ingestion (Including Room & Khata Links)
      final dayBookRes = await _client.from('day_book_entries').select('*, profiles:user_id(*), related_user:target_user_id(*), related_room:related_room_id(*)').order('created_at', ascending: false);
      final enrollRes = await _client.from('hostel_enrollments').select('*, profiles:user_id(*)');
      final shopRes = await _client.from('shop_orders').select('*, profiles:user_id(*)').order('created_at', ascending: false);
      final payrollRes = await _client.from('payroll_records').select('*, profiles:user_id(*)').order('month', ascending: false);
      final walletRes = await _client.from('wallet_transactions').select('*, profiles:user_id(*)').order('created_at', ascending: false);
      
      if (user != null) {
        final profile = await _client.from('profiles').select('balance').eq('id', user.id).maybeSingle();
        _adminWalletBalance = (profile?['balance'] as num? ?? 0).toDouble();
      }

      List<dynamic> combined = [];
      Map<String, dynamic> kMap = {};
      _totalIn = 0; _totalOut = 0; _totalOutstandingLent = 0;

      // 🧺 Day Book (Maintenance, Damages, Khata)
      for (var e in dayBookRes) {
        final double v = (e['amount'] as num).toDouble();
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
        final total = double.tryParse(e['total_price']?.toString() ?? '0') ?? 0;
        final paid = double.tryParse(e['paid_amount']?.toString() ?? '0') ?? 0;
        final due = total - paid;
        if (due > 0) {
           final uid = e['user_id'];
           if (!kMap.containsKey(uid)) kMap[uid] = {'name': e['profiles']?['full_name'] ?? 'Res', 'lent': total, 'recovered': paid, 'history': []};
           else { kMap[uid]['lent'] += total; kMap[uid]['recovered'] += paid; }
        }
        if (paid > 0) {
          _totalIn += paid;
          combined.add({...e, 'origin': 'Rent', 'val': paid, 'is_income': true, 'title': 'Rent: ${e['profiles']?['full_name']}', 'date': DateTime.parse(e['updated_at'] ?? e['created_at'])});
        }
      }

      kMap.forEach((uid, data) {
         data['net'] = (data['lent'] as double) - (data['recovered'] as double);
         if (data['net'] > 0) _totalOutstandingLent += data['net'];
      });

      // 🧺 Common Stores/Payroll (Skipped for brevity)
      for(var s in shopRes) if(s['order_status']!='Cancelled'){_totalIn+=(s['total_price']??0).toDouble(); combined.add({...s,'origin':'Shop','val':(s['total_price']??0).toDouble(),'is_income':true,'title':'Store Order','date':DateTime.parse(s['created_at'])});}
      for(var p in payrollRes) {final v=double.tryParse(p['amount']?.toString()??'0')??0; _totalOut+=v; combined.add({...p,'origin':'Payroll','val':v,'is_income':false,'title':'Staff Salary','date':DateTime.parse(p['month'])});}
      
      combined.sort((a,b) => b['date'].compareTo(a['date']));
      if (mounted) setState(() { _allTransactions = combined; _khataMap = kMap; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;
    final showSidebar = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('UNIVERSAL CAMPUS LEDGER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.receipt_long_rounded, color: Colors.indigoAccent), onPressed: () => _showAuditLogModal(isDark)),
        ],
        bottom: showSidebar 
          ? null 
          : TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              indicatorColor: Colors.indigoAccent,
              tabs: const [ Tab(text: 'LEDGER'), Tab(text: 'KHATA/DUES'), Tab(text: 'ANALYTICS') ],
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
                            _buildLedgerSidebarTile(0, 'LEDGER', Icons.receipt_long_rounded),
                            _buildLedgerSidebarTile(1, 'KHATA/DUES', Icons.account_balance_wallet_rounded),
                            _buildLedgerSidebarTile(2, 'ANALYTICS', Icons.analytics_rounded),
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
                           _buildLedgerTab(isDark),
                           _buildKhataTab(isDark),
                           _buildAnalyticsTab(isDark),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                   _buildLedgerTab(isDark),
                   _buildKhataTab(isDark),
                   _buildAnalyticsTab(isDark),
                ],
              );
            },
          ),
    );
  }

  Widget _buildLedgerSidebarTile(int index, String label, IconData icon) {
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

  // --- LEDGER TAB ---
  Widget _buildLedgerTab(bool isDark) {
    final filtered = _allTransactions.where((tx) => DateFormat('yyyy-MM-dd').format(tx['date']) == DateFormat('yyyy-MM-dd').format(_selectedDate)).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
         _buildModernCalendarHeader(isDark),
         const SizedBox(height: 24),
         _buildSummaryShield(isDark, filtered),
         const SizedBox(height: 32),
         _sectionHeader('DAILY TRANSACTION FLOW'),
         const SizedBox(height: 16),
         if (filtered.isEmpty) _emptyState(isDark)
         else ...filtered.map((tx) => FadeInUp(child: _buildTransactionTile(tx, isDark))).toList(),
         const SizedBox(height: 100),
      ],
    );
  }

  // --- KHATA TAB ---
  Widget _buildKhataTab(bool isDark) {
    final activeKhata = _khataMap.entries.where((e) => e.value['net'] != 0).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
         _buildWalletHeader(isDark),
         const SizedBox(height: 32),
         _sectionHeader('USER DUES & DAMAGE RECOVERIES'),
         const SizedBox(height: 16),
         if (activeKhata.isEmpty) _emptyState(isDark)
         else ...activeKhata.map((e) => _buildUserKhataTile(e.value, isDark)).toList(),
         const SizedBox(height: 100),
      ],
    );
  }

  // --- ANALYTICS TAB ---
  Widget _buildAnalyticsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
         _sectionHeader('OPERATIONAL VELOCITY'),
         const SizedBox(height: 24),
         _buildExpenseChart(isDark),
         const SizedBox(height: 48),
         _buildMetricGrid(isDark),
         const SizedBox(height: 100),
      ],
    );
  }

  // --- WIDGETS ---
  Widget _buildWalletHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A8A), Color(0xFF08090A)]), borderRadius: BorderRadius.circular(36), boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('AVAILABLE FIDELITY BALANCE', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Icon(Icons.shield_moon_rounded, color: Colors.indigoAccent, size: 16),
          ]),
          const SizedBox(height: 12),
          Text('₹${_adminWalletBalance.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('RECOVERABLE ASSETS: ₹${_totalOutstandingLent.toInt()}', style: TextStyle(color: Colors.amberAccent.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: _actionBtn(Icons.add_circle_outline_rounded, 'TOP UP', Colors.indigoAccent, () => _showTopUpModal(isDark))),
            const SizedBox(width: 12),
            Expanded(child: _actionBtn(Icons.assignment_turned_in_rounded, 'LOG AUDIT', Colors.white.withOpacity(0.1), () => _showAuditLogModal(isDark))),
          ]),
      ]),
    );
  }
Widget _actionBtn(
  IconData icon,
  String label,
  Color color,
  VoidCallback onTap,
) {
  final isPrimary = color == Colors.indigoAccent;

  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.indigoAccent
                : Colors.white.withOpacity(0.06), // 🔥 glass secondary
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary
                  ? Colors.indigoAccent
                  : Colors.white.withOpacity(0.15),
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: Colors.indigoAccent.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isPrimary ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  Widget _buildUserKhataTile(dynamic u, bool isDark) {
     final bool debt = u['net'] > 0;
     final Color color = debt ? Colors.redAccent : Colors.greenAccent;
     return Container(
       margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
       child: ExpansionTile(
         title: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.person_pin_rounded, color: color, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Text(u['name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13))),
            Text('₹${u['net'].abs().toInt()}', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
         ]),
         children: [
            ...((u['history'] ?? []) as List).map((h) => ListTile(
               dense: true, leading: Icon(h['entry_type'] == 'Income' ? Icons.south_west_rounded : Icons.north_east_rounded, color: h['entry_type'] == 'Income' ? Colors.greenAccent : Colors.redAccent, size: 14),
               title: Text(h['category'] ?? 'Audit Log', style: const TextStyle(color: Colors.white70, fontSize: 11)),
               subtitle: Text(DateFormat('MMM dd').format(DateTime.parse(h['transaction_date'] ?? h['created_at'])), style: const TextStyle(color: Colors.white24, fontSize: 8)),
               trailing: Text('₹${(h['amount'] as num).toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )).toList(),
         ],
       ),
     );
  }

  // --- MODALS ---
  void _showAuditLogModal(bool isDark) {
    String auditType = 'Maintenance (Exp)';
    String method = 'Cash';
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (c, setModalState) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HOSTEL AUDIT LOG', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 24),
          _modalSegment(['Maintenance (Exp)', 'Damage Fine (Dr)', 'Recovery (Cr)'], auditType, (v) => setModalState(() => auditType = v), isDark),
          const SizedBox(height: 20),
          _inputField('AMOUNT (₹)', _manualAmtCtrl, isDark, Icons.payments_rounded, isNumeric: true),
          const SizedBox(height: 20),
          Text('ENTITY SELECTION', style: TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _roomSelector(isDark, setModalState)),
            const SizedBox(width: 12),
            Expanded(child: _profileSelector(isDark, setModalState)),
          ]),
          const SizedBox(height: 20),
          _modalSegment(['Cash', 'UPI', 'Bank'], method, (v) => setModalState(() => method = v), isDark),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _submitAuditEntry(auditType, method),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('AUTHORIZE AUDIT ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ]),
      )),
    );
  }

  Widget _roomSelector(bool isDark, StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(child: DropdownButton<dynamic>(
        hint: Text('ROOM', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
        isExpanded: true, value: _selectedRoom, dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
        items: _rooms.map((r) => DropdownMenuItem(value: r, child: Text('UNIT ${r['room_number']}', style: TextStyle(color: isDark?Colors.white:Colors.black, fontSize: 12)))).toList(),
        onChanged: (v) => setModalState(() => _selectedRoom = v),
      )),
    );
  }

  Widget _profileSelector(bool isDark, StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(child: DropdownButton<dynamic>(
        hint: Text('USER', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
        isExpanded: true, value: _selectedProfile, dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
        items: _profiles.map((p) => DropdownMenuItem(value: p, child: Text(p['full_name'].toString().toUpperCase(), style: TextStyle(color: isDark?Colors.white:Colors.black, fontSize: 10, fontWeight: FontWeight.bold)))).toList(),
        onChanged: (v) => setModalState(() => _selectedProfile = v),
      )),
    );
  }

  Future<void> _submitAuditEntry(String type, String method) async {
     final amt = double.tryParse(_manualAmtCtrl.text);
     if (amt == null || amt <= 0) return;
     try {
       String entryType = 'Expense';
       String category = 'Miscellaneous';
       if (type == 'Recovery (Cr)') entryType = 'Income';
       if (type == 'Damage Fine (Dr)') {
          entryType = 'Expense'; // Money "spent" by student fine (Liability)
          category = 'Damage Fine';
       }
       if (type == 'Maintenance (Exp)') {
          entryType = 'Expense';
          category = 'Room Maintenance';
       }

       await _client.from('day_book_entries').insert({
         'entry_type': entryType,
         'amount': amt,
         'payment_method': method,
         'category': category,
         'target_user_id': _selectedProfile?['id'],
         'related_room_id': _selectedRoom?['id'],
         'user_id': _client.auth.currentUser!.id,
         'transaction_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
       });
       Navigator.pop(context);
       _manualAmtCtrl.clear(); _selectedProfile = null; _selectedRoom = null;
       _fetchUnifiedData();
     } catch (_) {}
  }

  // (Helper widgets: _modalSegment, _buildModernCalendarHeader, _statColumn, etc. are restored/updated as before)
  Widget _modalSegment(List<String> options, String selected, Function(String) onSel, bool isDark) {
    return Row(children: options.map((o) {
      bool sel = selected == o;
      return Expanded(child: GestureDetector(onTap: () => onSel(o), child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(o.toUpperCase(), style: TextStyle(color: sel ? Colors.white : (isDark ? Colors.white38 : Colors.black38), fontSize: 7, fontWeight: FontWeight.w900)))));
    }).toList());
  }

  Widget _buildModernCalendarHeader(bool isDark) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent, size: 20),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEEE').format(_selectedDate).toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
          ]),
          const Icon(Icons.arrow_drop_down_rounded, color: Colors.indigoAccent),
        ]),
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
