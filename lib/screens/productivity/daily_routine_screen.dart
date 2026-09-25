import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import 'dart:async';

class DailyRoutineScreen extends StatefulWidget {
  const DailyRoutineScreen({super.key});

  @override
  State<DailyRoutineScreen> createState() => _DailyRoutineScreenState();
}

class _DailyRoutineScreenState extends State<DailyRoutineScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  final _db = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _protocols = [];
  
  Timer? _taskTimer;
  int _timerSeconds = 0;
  String? _activeTaskId;
  List<Map<String, dynamic>> _healthReminders = [];
  List<Map<String, dynamic>> _clubReminders = [];
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _fetchProtocols();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final res = await _db.fetchReminders();
    if (mounted) {
      setState(() {
        _healthReminders = res.where((r) => r['category'] == 'Health' || r['reminder_type'] == 'hydration').toList();
        _clubReminders = res.where((r) => r['category'] == 'Club').toList();
      });
    }
  }

  Future<void> _fetchProtocols() async {
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final res = await _client.from('student_daily_routines').select()
            .or('user_id.eq.${user.id},student_id.eq.${user.id}')
            .order('start_time', ascending: true);
        
        if ((res as List).isNotEmpty) {
          _protocols = List<Map<String, dynamic>>.from(res);
        } else {
          // Initialize default routines for first-time student
          final defaults = [
            {'title': 'Morning Meditation & Planning', 'category': 'Wellness', 'start_time': '07:00', 'end_time': '07:30', 'duration': '30 min', 'icon_name': 'meditation', 'is_done': false},
            {'title': 'Academic Deep Focus Block', 'category': 'Deep Focus', 'start_time': '09:00', 'end_time': '11:00', 'duration': '120 min', 'icon_name': 'bolt', 'is_done': false},
            {'title': 'Campus Lectures & Lab Work', 'category': 'Academics', 'start_time': '11:30', 'end_time': '13:30', 'duration': '120 min', 'icon_name': 'lecture', 'is_done': false},
            {'title': 'Evening Workout Protocol', 'category': 'Fitness', 'start_time': '17:30', 'end_time': '18:30', 'duration': '60 min', 'icon_name': 'workout', 'is_done': false},
            {'title': 'Revision & Day Reflection', 'category': 'Review', 'start_time': '21:00', 'end_time': '21:45', 'duration': '45 min', 'icon_name': 'reading', 'is_done': false},
          ];
          for (var d in defaults) {
            try {
              await _client.from('student_daily_routines').insert({
                'user_id': user.id,
                'student_id': user.id,
                'title': d['title'],
                'category': d['category'],
                'start_time': d['start_time'],
                'end_time': d['end_time'],
                'icon_name': d['icon_name'],
                'is_done': false,
              });
            } catch (_) {}
          }
          final refreshed = await _client.from('student_daily_routines').select()
              .or('user_id.eq.${user.id},student_id.eq.${user.id}')
              .order('start_time', ascending: true);
          _protocols = (refreshed as List).isNotEmpty ? List<Map<String, dynamic>>.from(refreshed) : defaults;
        }
      }
    } catch (_) {
      _protocols = [
        {'id': 'p1', 'title': 'Core Focus Session', 'category': 'Focus', 'duration': '60 min', 'is_done': false},
        {'id': 'p2', 'title': 'Knowledge Revision', 'category': 'Academics', 'duration': '45 min', 'is_done': false},
      ];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer(String taskId, int minutes) {
    _taskTimer?.cancel();
    _activeTaskId = taskId;
    _timerSeconds = minutes * 60;
    
    _taskTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
        _markComplete(taskId);
      }
    });
  }

  void _markComplete(String id) async {
    setState(() {
      final idx = _protocols.indexWhere((p) => p['id']?.toString() == id);
      if (idx != -1) {
        _protocols[idx]['is_done'] = true;
      }
      if (_activeTaskId == id) {
        _activeTaskId = null;
        _taskTimer?.cancel();
      }
    });

    // Update remote Supabase record if valid UUID
    try {
      if (id.length > 20) {
        await _client.from('student_daily_routines').update({'is_done': true}).eq('id', id);
      }
    } catch (_) {}

    // Award XP
    _db.incrementXP(50);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PROTOCOL COMPLETED: +50 XP AWARDED'), backgroundColor: Colors.greenAccent));
  }

  @override
  void dispose() {
    _taskTimer?.cancel();
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('DAILY PROTOCOLS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent), onPressed: _showAddTaskModal),
        ],
      ),
      body: Stack(
        children: [
          _buildBreathingBg(),
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildSummaryCard(isDark),
                  const SizedBox(height: 32),
                  Text('ACTIVE SEQUENCE', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  ..._protocols.map((p) => _buildProtocolCard(p, isDark)),
                  const SizedBox(height: 32),
                  Text('HEALTH RITUALS', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  if (_healthReminders.isEmpty) _emptyData(isDark, 'NO HEALTH RITUALS ACTIVE')
                  else ..._healthReminders.map((r) => _reminderCard(r, isDark, Colors.tealAccent)),
                  const SizedBox(height: 32),
                  Text('CLUB ENGAGEMENTS', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  if (_clubReminders.isEmpty) _emptyData(isDark, 'NO CLUB REMINDERS')
                  else ..._clubReminders.map((r) => _reminderCard(r, isDark, Colors.orangeAccent)),
                  const SizedBox(height: 80),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildBreathingBg() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.indigoAccent.withOpacity(0.03 * _breathingController.value),
              Colors.transparent,
            ],
            radius: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _emptyData(bool isDark, String t) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01), borderRadius: BorderRadius.circular(24)), child: Center(child: Text(t, style: TextStyle(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))));

  Widget _reminderCard(Map<String, dynamic> r, bool isDark, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.notifications_active_rounded, color: color, size: 18)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text(r['title'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
             Text(r['scheduled_time'] ?? '00:00', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
          ])),
          IconButton(onPressed: () => _db.toggleReminder(r['id'], false).then((_)=>_loadReminders()), icon: Icon(Icons.check_circle_rounded, color: color.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    int done = _protocols.where((p) => p['is_done'] == true).length;
    double progress = _protocols.isEmpty ? 0 : done / _protocols.length;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CORE MOMENTUM', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Text('$done / ${_protocols.length} DONE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              CircularProgressIndicator(value: progress, color: Colors.white, backgroundColor: Colors.white24, strokeWidth: 5, strokeCap: StrokeCap.round),
            ],
          ),
          if (_activeTaskId != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('ACTIVE TIMER: ${_formatTime(_timerSeconds)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _activeTaskId = null),
                    child: const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int sec) {
    int m = sec ~/ 60;
    int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildProtocolCard(Map<String, dynamic> p, bool isDark) {
    final isDone = p['is_done'] == true;
    final isActive = _activeTaskId == p['id'];
    final textColor = isDark ? Colors.white : Colors.black;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isActive ? Colors.indigoAccent : (isDone ? Colors.greenAccent.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDone ? Colors.greenAccent.withOpacity(0.1) : Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isDone ? Icons.check_rounded : Icons.radio_button_unchecked_rounded, color: isDone ? Colors.greenAccent : Colors.indigoAccent),
          ),
          title: Text(p['title'], style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, decoration: isDone ? TextDecoration.lineThrough : null)),
          subtitle: Text('${p['category'].toString().toUpperCase()} • ${p['duration']}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          trailing: _buildCardActions(p, isDone, isActive),
        ),
      ),
    );
  }

  Widget _buildCardActions(Map<String, dynamic> p, bool isDone, bool isActive) {
    if (isDone) return const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 20);
    
    return IconButton(
      icon: Icon(isActive ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.indigoAccent, size: 32),
      onPressed: () => _startTimer(p['id'], 1), // Using 1 min for demo
    );
  }

  void _showAddTaskModal() {
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(ctx).viewInsets.bottom + 28),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADD NEW PROTOCOL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 24),
            TextField(controller: titleCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputDeco('Protocol Name (e.g. Deep Focus)', isDark)),
            const SizedBox(height: 16),
            TextField(controller: catCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputDeco('Category (e.g. Learning)', isDark)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isEmpty) return;
                  setState(() {
                    _protocols.insert(0, {
                      'id': DateTime.now().toString(),
                      'title': titleCtrl.text,
                      'category': catCtrl.text.isEmpty ? 'General' : catCtrl.text,
                      'duration': '25 min',
                      'is_done': false
                    });
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('ENGAGE PROTOCOL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String h, bool isDark) => InputDecoration(hintText: h, hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20));
}
