import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';

class PaymentLedgerScreen extends StatefulWidget {
  const PaymentLedgerScreen({super.key});

  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  final _client = Supabase.instance.client;
  int _activeTab = 0; // 0: Ledger, 1: Analytics
  final TextEditingController _expNameCtrl = TextEditingController();
  final TextEditingController _expAmtCtrl = TextEditingController();
  final TextEditingController _reloadAmtCtrl = TextEditingController();
  String _expType = 'UPI';
  String _reloadMethod = 'UPI';
  bool _isLoading = true;
  bool _isProcessingReload = false;
  String _role = 'user';
  double _balance = 0;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final profile = await _client.from('profiles').select('role, balance').eq('id', user.id).maybeSingle();
      
      if (mounted) {
        setState(() {
          _role = profile?['role'] ?? 'user';
          _balance = (profile?['balance'] as num? ?? 0).toDouble();
        });
      }

      final bool isAdmin = (profile?['role'] ?? 'user') == 'admin';

      // 1. Fetch Room Allotments
      var hQuery = _client.from('hostel_enrollments').select('*, hostel_rooms(room_number), profiles(full_name)');
      if (!isAdmin) hQuery = hQuery.eq('user_id', user.id);
      final hostelRes = await hQuery.order('created_at', ascending: false);

      // 2. Fetch Shop Orders
      var oQuery = _client.from('shop_orders').select('*, profiles(full_name)');
      if (!isAdmin) oQuery = oQuery.eq('user_id', user.id);
      final ordersRes = await oQuery.order('created_at', ascending: false);

      // 3. Fetch Wallet Transactions
      var wQuery = _client.from('wallet_transactions').select('*, profiles(full_name)');
      if (!isAdmin) wQuery = wQuery.eq('user_id', user.id);
      final walletRes = await wQuery.order('created_at', ascending: false);

      // 4. Fetch Payment Approvals
      var apQuery = _client.from('payment_approvals').select('*, profiles(full_name)');
      if (!isAdmin) apQuery = apQuery.eq('user_id', user.id);
      final approvalsRes = await apQuery.order('created_at', ascending: false);

      List<dynamic> combined = [];

      for (var h in hostelRes) {
        double amt = double.tryParse(h['total_price']?.toString() ?? '0') ?? 0;
        combined.add({
          'title': (isAdmin ? '[${h['profiles']?['full_name'] ?? 'Student'}] ' : '') + 'Unit ${h['hostel_rooms']?['room_number'] ?? 'Room'} Booking',
          'amount': amt,
          'date': h['created_at'],
          'type': 'Hostel',
          'is_income': isAdmin,
          'icon': Icons.apartment_rounded,
          'color': Colors.indigoAccent,
        });
      }

      for (var o in ordersRes) {
        double amt = double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
        combined.add({
          'title': (isAdmin ? '[${o['profiles']?['full_name'] ?? 'Customer'}] ' : '') + 'Store Order #${o['id'].toString().substring(0, 5).toUpperCase()}',
          'amount': amt,
          'date': o['created_at'],
          'type': 'Shop',
          'is_income': isAdmin,
          'icon': Icons.shopping_cart_rounded,
          'color': Colors.pinkAccent,
        });
      }

      for (var w in walletRes) {
        double amt = double.tryParse(w['amount']?.toString() ?? '0') ?? 0;
        bool isIncome = isAdmin ? (amt < 0) : (amt > 0); 
        combined.add({
          'title': (isAdmin ? '[${w['profiles']?['full_name'] ?? 'User'}] ' : '') + (w['transaction_type'] ?? 'Wallet Transfer'),
          'amount': amt.abs(),
          'date': w['created_at'],
          'type': 'Wallet',
          'is_income': isIncome,
          'icon': Icons.account_balance_wallet_rounded,
          'color': Colors.greenAccent,
        });
      }

      for (var a in (approvalsRes as List)) {
        double amt = (a['amount'] as num).toDouble();
        combined.add({
          'title': (isAdmin ? '[${a['profiles']?['full_name'] ?? 'User'}] ' : '') + 'UPI DISPATCH: ${a['payment_type']}',
          'amount': amt,
          'date': a['created_at'],
          'type': 'Approval',
          'is_income': isAdmin,
          'status': a['status'], 
          'icon': Icons.hourglass_top_rounded,
          'color': a['status'] == 'Approved' ? Colors.greenAccent : (a['status'] == 'Rejected' ? Colors.redAccent : Colors.amberAccent),
        });
      }

      combined.sort((a, b) => DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));

      if (mounted) {
        setState(() {
          _transactions = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processReload() async {
    final amount = double.tryParse(_reloadAmtCtrl.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isProcessingReload = true);
    try {
      final success = await DatabaseService().reloadWallet(amount, 'REFILL: $_reloadMethod');
      if (mounted) {
        if (success) {
          _reloadAmtCtrl.clear();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RELOAD AUTHORIZED: SECURE PROTOCOL SUCCESSFUL'), backgroundColor: Colors.greenAccent));
          _fetchLedger();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RELOAD FAILED: COMMUNICATION ERROR'), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('COMMUNICATION ERROR: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isProcessingReload = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('FIDELITY FINANCE HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildBackgroundGlow(isDark),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    // Desktop/Wide View: 2-column layout split
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 24),
                            child: Column(
                              children: [
                                _buildWalletHeader(isDark),
                              ],
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Colors.black12),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTabSwitcher(isDark),
                              Expanded(
                                child: _activeTab == 0 
                                  ? ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      itemCount: _transactions.length,
                                      itemBuilder: (context, i) => _buildTransactionCard(_transactions[i], isDark),
                                    )
                                  : _buildAnalyticsView(isDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile View: Single column scrolling list
                  return Column(
                    children: [
                      _buildTabSwitcher(isDark),
                      Expanded(
                        child: _activeTab == 0 ? _buildLedgerView(isDark) : _buildAnalyticsView(isDark),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
      floatingActionButton: _activeTab == 0 ? FloatingActionButton.extended(
        onPressed: () => _showAddExpenseModal(isDark),
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('LOG EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
      ) : null,
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _tabBtn('HISTORY', 0, isDark),
          _tabBtn('ANALYTICS', 1, isDark),
        ],
      ),
    );
  }

  Widget _tabBtn(String l, int i, bool isDark) {
    bool sel = _activeTab == i;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _activeTab = i), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(l, style: GoogleFonts.outfit(color: sel ? Colors.white : (isDark ? Colors.white38 : Colors.black38), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5))))));
  }

  Widget _buildLedgerView(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildWalletHeader(isDark),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('RECENT ACTIVITY'),
              const SizedBox(height: 20),
              if (_transactions.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text('NO TRANSACTIONS RECORDED', style: TextStyle(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))))
              else
                ..._transactions.map((tx) => FadeInUp(child: _buildTransactionCard(tx, isDark))).toList(),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildWalletHeader(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF1E3A8A), const Color(0xFF08090A)]),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('AVAILABLE FIDELITY BALANCE', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const Icon(Icons.shield_moon_rounded, color: Colors.white24, size: 16),
          ]),
          const SizedBox(height: 16),
          Text('₹${_balance.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _headerButton(Icons.add_circle_outline_rounded, 'TOP UP', () => _showTopUpModal(isDark))),
              const SizedBox(width: 12),
              Expanded(child: _headerButton(Icons.ios_share_rounded, 'SEND', () {})),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))])),
    );
  }

  void _showTopUpModal(bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (c, setModalState) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text('FISCAL RELOAD', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
          const SizedBox(height: 32),
          _inputField('AMOUNT (₹)', _reloadAmtCtrl, isDark, Icons.payments_rounded, isNumeric: true),
          const SizedBox(height: 24),
          Text('SECURE METHOD', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _methodBtn('UPI', Icons.bolt_rounded, isDark, setModalState, true),
          _methodBtn('CARD', Icons.credit_card_rounded, isDark, setModalState, true),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isProcessingReload ? null : () => _processReload(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: _isProcessingReload ? const CircularProgressIndicator(color: Colors.white) : const Text('AUTHORIZE TOP-UP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ]),
      )),
    );
  }

  void _showAddExpenseModal(bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (ctx, setModalState) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text('MANUAL LOG', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
          const SizedBox(height: 32),
          _inputField('DESCRIPTION', _expNameCtrl, isDark, Icons.edit_note_rounded),
          const SizedBox(height: 20),
          _inputField('AMOUNT (₹)', _expAmtCtrl, isDark, Icons.payments_rounded, isNumeric: true),
          const SizedBox(height: 24),
          Row(children: [
            _methodBtn('UPI', Icons.bolt_rounded, isDark, setModalState, false),
            const SizedBox(width: 12),
            _methodBtn('CASH', Icons.money_rounded, isDark, setModalState, false),
          ]),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _logManualExpense(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('AUTHORIZE ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ]),
      )),
    );
  }

  Widget _inputField(String l, TextEditingController c, bool isDark, IconData icon, {bool isNumeric = false}) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: TextField(controller: c, keyboardType: isNumeric ? TextInputType.number : TextInputType.text, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold), decoration: InputDecoration(icon: Icon(icon, color: Colors.indigoAccent, size: 18), border: InputBorder.none, labelText: l, labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900))));
  }

  Widget _methodBtn(String t, IconData i, bool isDark, StateSetter setModalState, bool isReload) {
    bool sel = isReload ? (_reloadMethod == t) : (_expType == t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(onTap: () => setModalState(() => isReload ? (_reloadMethod = t) : (_expType = t)), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: sel ? Colors.indigoAccent.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)), borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))), child: Row(children: [Icon(i, color: sel ? Colors.indigoAccent : (isDark ? Colors.white24 : Colors.black26), size: 18), const SizedBox(width: 16), Text(t, style: GoogleFonts.outfit(color: sel ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black45), fontSize: 13, fontWeight: FontWeight.bold)), const Spacer(), if (sel) const Icon(Icons.check_circle_rounded, color: Colors.indigoAccent, size: 18)]))),
    );
  }

  Future<void> _logManualExpense(BuildContext context) async {
    final amt = double.tryParse(_expAmtCtrl.text);
    if (amt == null || amt <= 0 || _expNameCtrl.text.isEmpty) return;
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      await _client.from('wallet_transactions').insert({'user_id': user.id, 'amount': -amt, 'transaction_type': 'Expense: ${_expNameCtrl.text} (${_expType})'});
      Navigator.pop(context);
      _expNameCtrl.clear(); _expAmtCtrl.clear();
      _fetchLedger();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EXPENSE LOGGED SUCCESSFULLY'), backgroundColor: Colors.greenAccent));
    } catch (_) {}
  }

  Widget _buildAnalyticsView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader('SPENDING VELOCITY'),
        const SizedBox(height: 24),
        _buildExpenseChart(isDark),
        const SizedBox(height: 48),
        _buildMetricGrid(isDark),
      ],
    );
  }

  Widget _buildExpenseChart(bool isDark) {
    Map<String, double> dailyData = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) { dailyData[DateFormat('EE').format(now.subtract(Duration(days: i)))] = 0; }
    for (var tx in _transactions) {
      if (!(tx['is_income'] ?? false)) {
        final dt = DateTime.parse(tx['date'].toString());
        if (now.difference(dt).inDays < 7) {
          final day = DateFormat('EE').format(dt);
          dailyData[day] = (dailyData[day] ?? 0) + (tx['amount'] as num).toDouble();
        }
      }
    }
    final chartData = dailyData.values.toList();
    final chartLabels = dailyData.keys.toList();
    return Container(
      height: 250, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(28), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Column(children: [
        Expanded(child: LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: FlTitlesData(topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => val.toInt() >= 0 && val.toInt() < chartLabels.length ? Text(chartLabels[val.toInt()], style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)) : const SizedBox()))), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: List.generate(chartData.length, (i) => FlSpot(i.toDouble(), chartData[i])), isCurved: true, color: Colors.indigoAccent, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.indigoAccent.withOpacity(0.1)))]))),
        const SizedBox(height: 16),
        Text('7-DAY OUTFLOW TREND', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ]),
    );
  }

  Widget _buildMetricGrid(bool isDark) {
    double totalOut = _transactions.where((t) => !(t['is_income'] ?? false)).fold(0, (sum, t) => sum + (t['amount'] as num).toDouble());
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.5,
      children: [
        _metricCard('DAILY AVG', '₹${(totalOut / 30).toStringAsFixed(0)}', Colors.greenAccent, isDark),
        _metricCard('WEEKLY BURN', '₹${(totalOut / 4).toStringAsFixed(0)}', Colors.orangeAccent, isDark),
        _metricCard('MONTHLY EST', '₹${totalOut.toInt()}', Colors.indigoAccent, isDark),
        _metricCard('UTILIZATION', '82%', Colors.purpleAccent, isDark),
      ],
    );
  }

  Widget _metricCard(String l, String v, Color c, bool isDark) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 4), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold))]));
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx, bool isDark) {
    final bool isIncome = tx['is_income'] ?? false;
    final Color color = tx['color'] ?? (isIncome ? Colors.greenAccent : Colors.redAccent);
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(tx['icon'] ?? (isIncome ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded), color: color, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx['title'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(tx['date'].toString())), style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))])),
        const SizedBox(width: 12),
        Text('${isIncome ? "+" : "-"}₹${tx['amount'].toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      ]),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(top: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _sectionHeader(String label) {
    return Text(label, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  }
}
