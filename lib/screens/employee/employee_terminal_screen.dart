import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../payment_ledger_screen.dart';
import '../my_attendance_screen.dart';
import '../policy_handbook_screen.dart';
import '../attendance_calendar_screen.dart';
import '../staff_task_hub_screen.dart';
import '../notifications_screen.dart';
import '../van_log_screen.dart';
import '../payroll_terminal_screen.dart';
import '../../services/database_service.dart';

class EmployeeTerminalScreen extends StatefulWidget {
  const EmployeeTerminalScreen({super.key});

  @override
  State<EmployeeTerminalScreen> createState() => _EmployeeTerminalScreenState();
}

class _EmployeeTerminalScreenState extends State<EmployeeTerminalScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  bool _isLoading = true;
  bool _hasCheckedIn = false;
  Map<String, dynamic>? _employeeData;
  Map<String, int> _attendanceMetrics = {'present': 0, 'half': 0, 'unpaid': 0, 'paid': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final profileRes = await client.from('profiles').select().eq('id', user!.id).maybeSingle();
      
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final att = await client.from('attendance').select().eq('user_id', user!.id).eq('date', dateStr).maybeSingle();

      final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
      final attList = await client.from('attendance').select().eq('user_id', user!.id).gte('date', monthStart);
      
      Map<String, int> metrics = {'present': 0, 'half': 0, 'unpaid': 0, 'paid': 0};
      for (var a in attList) {
        final s = a['status']?.toString().toLowerCase() ?? '';
        if (s == 'present') metrics['present'] = (metrics['present'] ?? 0) + 1;
        else if (s == 'half') metrics['half'] = (metrics['half'] ?? 0) + 1;
        else if (s == 'unpaid') metrics['unpaid'] = (metrics['unpaid'] ?? 0) + 1;
        else if (s == 'paid') metrics['paid'] = (metrics['paid'] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _employeeData = profileRes;
          _hasCheckedIn = att != null;
          _attendanceMetrics = metrics;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAttendance() async {
    if (_hasCheckedIn) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      final ok = await DatabaseService().markAttendance(type: 'staff');
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked Present for today.'), backgroundColor: Colors.indigoAccent));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
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
        title: Text('STAFF DASHBOARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.indigoAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          _liveBadge(isDark),
          const SizedBox(width: 16)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(),
              RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildAttendanceHero(isDark),
                    const SizedBox(height: 32),
                    _buildStaffMetrics(isDark),
                    const SizedBox(height: 32),
                    _buildAnnouncementsSection(),
                    const SizedBox(height: 32),
                    Text('TOOLS & SERVICES', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                    const SizedBox(height: 16),
                    _buildTerminalGrid(isDark),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _liveBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1))),
      child: Row(children: [const Icon(Icons.circle, color: Colors.greenAccent, size: 8), const SizedBox(width: 8), Text('ACTIVE', style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5))]),
    );
  }

  Widget _buildAttendanceHero(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle), child: Icon(Icons.check_circle_outline_rounded, color: _hasCheckedIn ? Colors.greenAccent : Colors.indigoAccent, size: 48)),
            const SizedBox(height: 24),
            Text(_hasCheckedIn ? 'CHECKED IN' : 'READY TO START?', style: GoogleFonts.outfit(color: textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(_hasCheckedIn ? "You are marked present for today" : "Tap below to mark your attendance", style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: _hasCheckedIn ? null : _markAttendance,
                style: ElevatedButton.styleFrom(backgroundColor: _hasCheckedIn ? Colors.greenAccent.withOpacity(0.1) : Colors.indigoAccent, disabledBackgroundColor: Colors.greenAccent.withOpacity(0.1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text(_hasCheckedIn ? "PRESENT" : "MARK ATTENDANCE", style: GoogleFonts.outfit(color: _hasCheckedIn ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalGrid(bool isDark) {
    final ops = [
      {'icon': Icons.account_balance_wallet_outlined, 'label': 'Ledger', 'color': Colors.greenAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentLedgerScreen()))},
      {'icon': Icons.event_note_outlined, 'label': 'History', 'color': Colors.redAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceCalendarScreen(type: 'staff')))},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks', 'color': Colors.orangeAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffTaskHubScreen()))},
      {'icon': Icons.menu_book_outlined, 'label': 'Policies', 'color': Colors.tealAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyHandbookScreen()))},
      {'icon': Icons.payments_outlined, 'label': 'Payroll', 'color': Colors.indigoAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollTerminalScreen()))},
      {'icon': Icons.local_shipping_outlined, 'label': 'Van Log', 'color': Colors.blueAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VanLogScreen()))},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 6 : (MediaQuery.of(context).size.width > 600 ? 4 : 3),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: ops.length,
      itemBuilder: (context, i) => _hubItem(ops[i], isDark),
    );
  }

  Widget _hubItem(Map<String, dynamic> op, bool isDark) {
    return GestureDetector(
      onTap: op['onTap'] as VoidCallback,
      child: Container(
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(op['icon'] as IconData, color: op['color'] as Color, size: 28),
          const SizedBox(height: 12),
          Text(op['label'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildStaffMetrics(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          Row(children: [const Icon(Icons.analytics_rounded, color: Colors.indigoAccent, size: 16), const SizedBox(width: 12), Text('MONTHLY STATS', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5))]),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _empStatMini('PRESENT', _attendanceMetrics['present'] ?? 0, Colors.greenAccent, isDark),
              _empStatMini('HALF DAY', _attendanceMetrics['half'] ?? 0, Colors.orangeAccent, isDark),
              _empStatMini('LEAVE', (_attendanceMetrics['paid'] ?? 0) + (_attendanceMetrics['unpaid'] ?? 0), Colors.redAccent, isDark),
              _empStatMini('XP', _employeeData?['xp'] ?? 0, Colors.indigoAccent, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empStatMini(String label, dynamic val, Color color, bool isDark) {
    return Column(
      children: [
        Text('$val', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ANNOUNCEMENTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: StreamBuilder(
            stream: Supabase.instance.client.from('global_announcements').stream(primaryKey: ['id']).order('created_at').limit(5),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyIntel();
              final data = snapshot.data!.where((b) => b['target_audience'] == 'ALL' || b['target_audience'] == 'STAFF').toList();
              if (data.isEmpty) return _emptyIntel();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: data.length,
                itemBuilder: (context, i) => _broadcastCard(data[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyIntel() {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.notifications_off_rounded, color: Colors.white10), SizedBox(height: 12), Text('NO RECENT ANNOUNCEMENTS', style: TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5))]),
    );
  }

  Widget _broadcastCard(dynamic b) {
    bool isUrgent = b['is_urgent'] ?? false;
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isUrgent ? Colors.redAccent.withOpacity(0.05) : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isUrgent ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(isUrgent ? Icons.error_outline : Icons.info_outline, color: isUrgent ? Colors.redAccent : Colors.indigoAccent, size: 14), const SizedBox(width: 8), Text(isUrgent ? 'URGENT' : 'INFO', style: TextStyle(color: isUrgent ? Colors.redAccent : Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
          const SizedBox(height: 12),
          Text(b['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(b['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
