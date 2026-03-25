import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';

class ProductivityCalendarScreen extends StatefulWidget {
  const ProductivityCalendarScreen({super.key});

  @override
  State<ProductivityCalendarScreen> createState() => _ProductivityCalendarScreenState();
}

class _ProductivityCalendarScreenState extends State<ProductivityCalendarScreen> {
  final _db = DatabaseService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  // Unified data
  List<Map<String, dynamic>> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db.fetchExamDeadlines(),
        _db.fetchSyllabus(),
        _db.fetchReflections(),
        _db.fetchMeditationLogs(),
        _db.fetchWorkoutLogs(),
        _db.fetchFocusLogs(),
        _db.fetchReminders(),
      ]);

      List<Map<String, dynamic>> combined = [];
      
      // Add types to each for display
      for (var e in results[0]) combined.add({...e, 'cal_type': 'Exam', 'date': e['exam_date']});
      for (var e in results[1]) combined.add({...e, 'cal_type': 'Test', 'date': e['test_date']});
      for (var e in results[2]) combined.add({...e, 'cal_type': 'Log', 'date': e['log_date']});
      for (var e in results[3]) combined.add({...e, 'cal_type': 'Meditation', 'date': e['created_at']});
      for (var e in results[4]) combined.add({...e, 'cal_type': 'Workout', 'date': e['created_at']});
      for (var e in results[5]) combined.add({...e, 'cal_type': 'Focus', 'date': e['created_at']});
      
      if (mounted) {
        setState(() {
          _allEvents = combined;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _allEvents.where((e) {
      final date = DateTime.parse(e['date'].toString());
      return isSameDay(date, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : Colors.black;

    final selectedDayEvents = _getEventsForDay(_selectedDay!);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MASTER_CHRONICLE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: Colors.indigoAccent, size: 20), onPressed: _loadAllData),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)) : Column(
        children: [
          _buildCalendar(isDark, textColor),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildAgendaHeader(isDark),
                const SizedBox(height: 20),
                if (selectedDayEvents.isEmpty) 
                   _buildEmptyAgenda(isDark)
                else 
                   ...selectedDayEvents.map((e) => _buildEventTile(e, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        eventLoader: _getEventsForDay,
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle),
          markerDecoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
          markersMaxCount: 4,
          defaultTextStyle: TextStyle(color: textColor),
          weekendTextStyle: const TextStyle(color: Colors.pinkAccent),
          outsideTextStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          formatButtonDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          formatButtonTextStyle: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold),
          titleTextStyle: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildAgendaHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'AGENDA FOR ${DateFormat('MMM dd').format(_selectedDay!).toUpperCase()}',
          style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        Text('${_getEventsForDay(_selectedDay!).length} ENTRIES', style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyAgenda(bool isDark) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.event_busy_rounded, color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), size: 100),
          const SizedBox(height: 16),
          Text('NO DATA FOR THIS VECTOR', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> e, bool isDark) {
    final type = e['cal_type'];
    Color color;
    IconData icon;
    String title = '';
    String sub = '';

    switch (type) {
      case 'Exam':
        color = Colors.pinkAccent;
        icon = Icons.event_note_rounded;
        title = e['exam_title'] ?? 'EXAM';
        sub = DateFormat('HH:mm').format(DateTime.parse(e['date'].toString()));
        break;
      case 'Test':
        color = Colors.indigoAccent;
        icon = Icons.menu_book_rounded;
        title = e['subject'] ?? 'UNIT TEST';
        sub = 'Syllabus Deadline';
        break;
      case 'Log':
        color = Colors.tealAccent;
        icon = Icons.mood_rounded;
        title = 'DAY REFLECTION';
        sub = 'Satisfaction: ${e['satisfaction_rating']}/10';
        break;
      case 'Meditation':
        color = Colors.cyanAccent;
        icon = Icons.spa_rounded;
        title = 'ZEN SESSION';
        sub = '${e['duration_minutes']} Mins Logged';
        break;
      case 'Workout':
        color = Colors.orangeAccent;
        icon = Icons.fitness_center_rounded;
        title = 'KINETIC SESSION';
        sub = '${e['duration_minutes']} Mins Logged';
        break;
      case 'Focus':
        color = Colors.deepPurpleAccent;
        icon = Icons.timer_rounded;
        title = 'FOCUS STASIS';
        sub = '${(e['duration_seconds'] / 60).round()} Mins Focused';
        break;
      default:
        color = Colors.grey;
        icon = Icons.event_rounded;
    }

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(sub, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(type.toString().toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}
