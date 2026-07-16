import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/receipt_service.dart';

class PayrollTerminalScreen extends StatefulWidget {
  final dynamic profileOverride;
  const PayrollTerminalScreen({super.key, this.profileOverride});

  @override
  State<PayrollTerminalScreen> createState() => _PayrollTerminalScreenState();
}

class _PayrollTerminalScreenState extends State<PayrollTerminalScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _currentMonth = DateTime.now();
  Map<String, dynamic>? _profile;
  List<dynamic> _payoutHistory = [];
  Map<String, int> _attendanceStats = {'present': 0, 'half': 0, 'unpaid': 0, 'paid_leave': 0, 'off_duty': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null && widget.profileOverride == null) return;

    final profileId = widget.profileOverride != null ? widget.profileOverride['id'] : user!.id;

    try {
      final pRes = await _client.from('profiles').select().eq('id', profileId).maybeSingle();
      
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final attRes = await _client.from('attendance')
          .select()
          .eq('user_id', profileId)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String());

      Map<String, int> stats = {'present': 0, 'half': 0, 'unpaid': 0, 'paid_leave': 0, 'off_duty': 0};
      for (var a in attRes) {
        final s = a['status']?.toString().toLowerCase() ?? '';
        if (s == 'present') stats['present'] = (stats['present'] ?? 0) + 1;
        else if (s == 'half_day') stats['half'] = (stats['half'] ?? 0) + 1;
        else if (s == 'leave' || s == 'unpaid_leave') stats['unpaid'] = (stats['unpaid'] ?? 0) + 1;
        else if (s == 'paid_leave') stats['paid_leave'] = (stats['paid_leave'] ?? 0) + 1;
        else if (s == 'off_duty') stats['off_duty'] = (stats['off_duty'] ?? 0) + 1;
      }

      final hRes = await _client.from('payment_logs')
          .select()
          .eq('user_id', profileId)
          .eq('payment_type', 'SALARY')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = pRes;
          _payoutHistory = hRes;
          _attendanceStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('PAYROLL_COMMAND', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 4)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildBackgroundAura(isDark),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                // Desktop/Wide View: 2-column split
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildMonthNavigator(isDark),
                            const SizedBox(height: 32),
                            if (_profile != null) _buildCurrentBreakup(_profile!, isDark),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.black12),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            if (_profile != null) _buildHistorySection(isDark),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Mobile View: Default single-column scrolling view
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildMonthNavigator(isDark),
                          const SizedBox(height: 32),
                          if (_profile != null) ...[
                            _buildCurrentBreakup(_profile!, isDark),
                            const SizedBox(height: 40),
                            _buildHistorySection(isDark),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundAura(bool isDark) {
    return Positioned(
      top: -100, 
      right: -100, 
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 120, sigmaY: 120), 
        child: Container(
          width: 400, 
          height: 400, 
          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.05), shape: BoxShape.circle)
        )
      )
    );
  }



  Widget _buildMonthNavigator(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)); _loadData(); }),
          Column(
            children: [
              Text(DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              Text('ACTIVE_CYCLE', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
          IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)); _loadData(); }),
        ],
      ),
    );
  }

  Widget _buildCurrentBreakup(dynamic p, bool isDark) {
    final double salary = double.tryParse((p['salary'] ?? 0).toString()) ?? 0;
    final double dailyAllowance = double.tryParse((p['allowance'] ?? 0).toString()) ?? 0;
    final double profileAdvances = double.tryParse((p['advances'] ?? 0).toString()) ?? 0;
    final double profileDues = double.tryParse((p['dues_penalty'] ?? 0).toString()) ?? 0;

    final int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final int presentCount = _attendanceStats['present'] ?? 0;
    final int offDutyCount = _attendanceStats['off_duty'] ?? 0;
    final int paidLeaveCount = _attendanceStats['paid_leave'] ?? 0;
    final int halfDayCount = _attendanceStats['half'] ?? 0;
    final int unpaidCount = _attendanceStats['unpaid'] ?? 0;

    final double dailyRate = salary / daysInMonth;
    final double lopDays = unpaidCount + (halfDayCount * 0.5);
    final double lopsPrice = lopDays * dailyRate;
    final double totalAllowance = presentCount * dailyAllowance;

    final double net = (salary + totalAllowance - lopsPrice - profileAdvances - profileDues).clamp(0, double.infinity);

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NET_DISBURSEMENT', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('₹${net.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w900)),
                ]),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.greenAccent),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildStatBar(daysInMonth, presentCount, offDutyCount, lopDays, isDark),
            const SizedBox(height: 40),
            _ledgerItem('GROSS_BASE', '₹${salary.toInt()}', Icons.work_outline_rounded, Colors.blueAccent, isDark),
            _ledgerItem('FIELD_BONUS', '₹${totalAllowance.toInt()}', Icons.auto_graph_rounded, Colors.greenAccent, isDark),
            _ledgerItem('ATTENDANCE_LOP', '-₹${lopsPrice.toInt()}', Icons.event_busy_rounded, Colors.orangeAccent, isDark),
            if (profileAdvances > 0) _ledgerItem('ADVANCES_LOG', '-₹${profileAdvances.toInt()}', Icons.payments_outlined, Colors.redAccent, isDark),
            if (profileDues > 0) _ledgerItem('FINES_PENALTIES', '-₹${profileDues.toInt()}', Icons.gavel_rounded, Colors.redAccent, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBar(int total, int present, int off, double lop, bool isDark) {
    return Row(
      children: [
        _miniMetric('TOTAL', '$total', isDark),
        _miniMetric('PRESENT', '$present', isDark, color: Colors.greenAccent),
        _miniMetric('OFF_DUTY', '$off', isDark, color: Colors.blueAccent),
        _miniMetric('LOP_DAYS', '$lop', isDark, color: Colors.redAccent),
      ],
    );
  }

  Widget _miniMetric(String label, String val, bool isDark, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
          Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _ledgerItem(String label, String val, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHistorySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VERIFIED_HISTORICAL_LOGS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 2)),
        const SizedBox(height: 24),
        if (_payoutHistory.isEmpty) 
          _emptyHistory(isDark)
        else
          ..._payoutHistory.map((h) => _historyCard(h, isDark)).toList(),
      ],
    );
  }

  Widget _historyCard(dynamic h, bool isDark) {
    final date = DateFormat('MMMM yyyy').format(DateTime.parse(h['created_at']));
    return FadeInRight(
      child: GestureDetector(
        onTap: () {
          // Prepare payslip arguments
          final record = {
            'id': h['id'],
            'salary_amount': h['amount'] ?? 0,
            'allowances': h['allowances'] ?? 0,
            'advances_taken': h['advances'] ?? 0,
            'deductions': h['deductions'] ?? 0,
            'leaves_taken': h['leaves_taken'] ?? 0,
            'month': date,
          };
          ReceiptService.generateSalaryReceipt(record, _profile?['full_name']);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(date.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('TAP TO SHARE PAYSLIP PDF', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)),
              ])),
              Text('₹${(h['amount'] as num).toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.greenAccent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHistory(bool isDark) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 16),
          Text('NO_HISTORICAL_DATA_IDENTIFIED', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2)),
        ],
      ),
    );
  }
}
