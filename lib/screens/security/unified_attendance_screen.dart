import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../student/attendance_screen.dart';
import '../admin/admin_attendance_analytics_screen.dart';

class UnifiedAttendanceScreen extends StatefulWidget {
  final String role;
  const UnifiedAttendanceScreen({super.key, required this.role});

  @override
  State<UnifiedAttendanceScreen> createState() => _UnifiedAttendanceScreenState();
}

class _UnifiedAttendanceScreenState extends State<UnifiedAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, bool> _markedToday = {'mess': false, 'gate': false, 'night': false};

  @override
  void initState() {
    super.initState();
    int tabCount = widget.role == 'mess_student' ? 1 : (widget.role == 'admin' ? 3 : 3);
    _tabController = TabController(length: tabCount, vsync: this);
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    try {
      final res = await _client
          .from('attendance')
          .select('attendance_type')
          .eq('user_id', user.id)
          .eq('date', date);
      final List types = (res as List)
          .map((e) => e['attendance_type']?.toString() ?? '')
          .toList();
      
      if (mounted) {
        setState(() {
          _markedToday['mess'] = types.contains('mess');
          _markedToday['gate'] = types.contains('gate');
          _markedToday['night'] = types.contains('night');
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    List<Widget> tabs = [];
    List<Widget> views = [];

    if (widget.role == 'hostel_student' || widget.role == 'admin') {
      tabs.addAll([
        _tab('GATE'),
        _tab('MESS'),
        _tab('NIGHT'),
      ]);
      views.addAll([
        AttendanceScreen(type: 'gate'),
        AttendanceScreen(type: 'mess'),
        AttendanceScreen(type: 'night'),
      ]);
    } else if (widget.role == 'mess_student') {
      tabs.add(_tab('MESS'));
      views.add(AttendanceScreen(type: 'mess'));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ATTENDANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (widget.role == 'admin')
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.indigoAccent), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAttendanceAnalyticsScreen()))
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
          unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
          tabs: tabs,
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : TabBarView(
            controller: _tabController,
            children: views,
          ),
    );
  }

  Widget _tab(String label) {
    bool marked = _markedToday[label.toLowerCase()] ?? false;
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (marked) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 10),
          ] else ...[
            const SizedBox(width: 4),
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 10),
          ],
        ],
      ),
    );
  }
}
