import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminAttendanceScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const AdminAttendanceScreen({super.key, required this.userId, required this.userName});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final _client = Supabase.instance.client;
  DateTime _currentMonth = DateTime.now();
  Map<int, String> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final res = await _client.from('attendance_logs')
          .select()
          .eq('user_id', widget.userId)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String());

      Map<int, String> newMap = {};
      for (var a in res) {
        final date = DateTime.parse(a['date']);
        newMap[date.day] = a['status'] ?? 'present';
      }

      if (mounted) setState(() { _attendanceMap = newMap; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAttendance(int day, String status) async {
    final date = DateTime(_currentMonth.year, _currentMonth.month, day);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    try {
      await _client.from('attendance_logs').upsert({
        'user_id': widget.userId,
        'date': dateStr,
        'status': status.toLowerCase(),
      });
      
      final logs = await _client.from('attendance_logs').select('status').eq('user_id', widget.userId);
      
      int paid = 0, unpaid = 0, half = 0, off = 0;
      for (var log in (logs as List)) {
        final s = log['status']?.toString().toLowerCase() ?? '';
        if (s == 'paid_leave') paid++;
        else if (s == 'leave' || s == 'unpaid_leave') unpaid++;
        else if (s == 'half_day') half++;
        else if (s == 'off_duty') off++;
      }
      
      await _client.from('profiles').update({
        'paid_leaves': paid,
        'unpaid_leaves': unpaid,
        'half_days': half,
        'off_duty_days': off,
      }).eq('id', widget.userId);

      _fetchAttendance();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: Text('STAFF ATTENDANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          _buildMonthHeader(textColor, isDark),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)) : _buildCalendarGrid(isDark)),
          _buildLegend(isDark),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: Icon(Icons.chevron_left_rounded, color: textColor), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)); _fetchAttendance(); }),
          Text(DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: textColor, letterSpacing: 1.5)),
          IconButton(icon: Icon(Icons.chevron_right_rounded, color: textColor), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)); _fetchAttendance(); }),
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

        return GestureDetector(
          onTap: () => _showStatusPicker(day, isDark),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text('$day', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
          ),
        );
      },
    );
  }

  void _showStatusPicker(int day, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MARK STATUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text('Date: ${DateFormat('MMMM dd').format(DateTime(_currentMonth.year, _currentMonth.month, day))}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent, fontSize: 12)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _statusOption(day, 'PRESENT', 'present', Colors.green, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _statusOption(day, 'HALF DAY', 'half_day', Colors.orange, isDark)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statusOption(day, 'PAID LEAVE', 'paid_leave', Colors.blue, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _statusOption(day, 'UNPAID', 'leave', Colors.red, isDark)),
              ],
            ),
            const SizedBox(height: 12),
            _statusOption(day, 'OFF DUTY', 'off_duty', Colors.grey, isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(int day, String label, String value, Color color, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _markAttendance(day, value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'paid_leave': return Colors.blue;
      case 'leave': return Colors.red;
      case 'unpaid_leave': return Colors.red;
      case 'half_day': return Colors.orange;
      case 'off_duty': return Colors.grey;
      default: return isDarkMode ? Colors.white10 : Colors.black12;
    }
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Widget _buildLegend(bool isDark) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _legendItem('PRESENT', Colors.green),
        _legendItem('LEAVE', Colors.red),
        _legendItem('HALF DAY', Colors.orange),
        _legendItem('PAID LV', Colors.blue),
        _legendItem('OFF', Colors.grey),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}
