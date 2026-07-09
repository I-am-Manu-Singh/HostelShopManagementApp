import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class MyAttendanceScreen extends StatefulWidget {
  final String? userId;
  const MyAttendanceScreen({super.key, this.userId});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  final _client = Supabase.instance.client;
  DateTime _currentMonth = DateTime.now();
  Map<int, String> _attendanceMap = {};
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final user = _client.auth.currentUser;
    if (user == null && widget.userId == null) return;
    final targetId = widget.userId ?? user!.id;
    
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final res = await _client.from('attendance')
          .select()
          .eq('user_id', targetId)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String());

      Map<int, String> newMap = {};
      for (var a in res) {
        final date = DateTime.parse(a['date']);
        newMap[date.day] = a['status'] ?? 'present';
      }

      // AGGREGATE ALL TIME METRICS for historical accuracy
      final allLogs = await _client.from('attendance').select('status').eq('user_id', targetId);
      int paid = 0, unpaid = 0, half = 0, off = 0;
      for (var l in (allLogs as List)) {
         final s = l['status']?.toString().toLowerCase();
         if (s == 'paid_leave') paid++;
         else if (s == 'leave' || s == 'unpaid_leave') unpaid++;
         else if (s == 'half_day') half++;
         else if (s == 'off_duty') off++;
      }

      if (mounted) setState(() { 
        _attendanceMap = newMap; 
        _metrics = {
           'paid_leaves': paid,
           'unpaid_leaves': unpaid,
           'half_days': half,
           'off_duty_days': off,
        };
        _isLoading = false; 
      });
    } catch (_) {
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
        title: Text('MY ATTENDANCE RECORD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          _buildMonthHeader(isDark, textColor),
          _buildMetrics(isDark),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)) : _buildCalendarGrid(isDark)),
          _buildLegend(isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.indigoAccent, size: 20), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)); _fetchAttendance(); }),
          Text(DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: textColor, letterSpacing: 2)),
          IconButton(icon: Icon(Icons.arrow_forward_ios_rounded, color: Colors.indigoAccent, size: 20), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)); _fetchAttendance(); }),
        ],
      ),
    );
  }

  Widget _metricsStat(String l, String v, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(v, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: c, height: 1)),
            const SizedBox(height: 4),
            Text(l, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: c.withOpacity(0.5), letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(bool isDark) {
    int paid = _metrics?['paid_leaves'] ?? 0;
    int unpaid = _metrics?['unpaid_leaves'] ?? 0;
    int halfDay = _metrics?['half_days'] ?? 0;
    int offDuty = _metrics?['off_duty_days'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          _metricsStat('PAID', '$paid', Colors.greenAccent, isDark),
          _metricsStat('UNPAID', '$unpaid', Colors.redAccent, isDark),
          _metricsStat('HALF', '$halfDay', Colors.orangeAccent, isDark),
          _metricsStat('OFF', '$offDuty', Colors.blueAccent, isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        int day = index + 1;
        String? status = _attendanceMap[day];
        Color color = _getStatusColor(status);
        bool isToday = isSameDay(DateTime.now(), DateTime(_currentMonth.year, _currentMonth.month, day));

        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isToday ? Colors.indigoAccent : color.withOpacity(0.2), width: isToday ? 2 : 1),
          ),
          child: Text('$day', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        );
      },
    );
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'present': return Colors.greenAccent;
      case 'paid_leave': return Colors.greenAccent;
      case 'leave': return Colors.redAccent;
      case 'unpaid_leave': return Colors.redAccent;
      case 'half_day': return Colors.orangeAccent;
      case 'off_duty': return Colors.blueAccent;
      default: return Colors.indigoAccent.withOpacity(0.3);
    }
  }

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('PRESENT', Colors.greenAccent, isDark),
              const SizedBox(width: 20),
              _legendItem('LEAVE', Colors.redAccent, isDark),
              const SizedBox(width: 20),
              _legendItem('HALF DAY', Colors.orangeAccent, isDark),
              const SizedBox(width: 20),
              _legendItem('OFF-DUTY', Colors.blueAccent, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1)),
      ],
    );
  }
}
