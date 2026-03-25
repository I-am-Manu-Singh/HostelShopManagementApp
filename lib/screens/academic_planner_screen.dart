import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';

class AcademicPlannerScreen extends StatefulWidget {
  const AcademicPlannerScreen({super.key});

  @override
  State<AcademicPlannerScreen> createState() => _AcademicPlannerScreenState();
}

class _AcademicPlannerScreenState extends State<AcademicPlannerScreen> {
  final _db = DatabaseService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _deadlines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _db.fetchExamDeadlines(),
      _db.fetchSyllabus(),
      _db.fetchAcademicTargets(),
    ]);

    if (mounted) {
      setState(() {
        _deadlines = results[0];
        _syllabus = results[1];
        _targets = results[2];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _syllabus = [];
  List<Map<String, dynamic>> _targets = [];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : Colors.black;

    final selectedDayEvents = _deadlines.where((d) => isSameDay(DateTime.parse(d['exam_date']), _selectedDay)).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ACADEMIC PLANNER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              eventLoader: (day) {
                final d = _deadlines.where((d) => isSameDay(DateTime.parse(d['exam_date']), day));
                final s = _syllabus.where((s) => isSameDay(DateTime.parse(s['test_date']), day));
                return [...d, ...s];
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), shape: BoxShape.circle),
                markerDecoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                defaultTextStyle: TextStyle(color: textColor),
                outsideTextStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                formatButtonDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                formatButtonTextStyle: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold),
                titleTextStyle: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white : Colors.black),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ),
          const Divider(height: 32),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AGENDA FOR ${DateFormat('MMMM dd').format(_selectedDay!).toUpperCase()}',
                      style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent, size: 20),
                      onPressed: () => _showAddDeadlineModal(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (selectedDayEvents.isEmpty)
                  FadeInUp(
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 48),
                          Icon(Icons.calendar_month_rounded, color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), size: 100),
                          const SizedBox(height: 16),
                          Text('NO IMPORTANT DATES YET', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...selectedDayEvents.map((e) => _buildEventItem(e, isDark)),
                  ..._syllabus.where((s) => isSameDay(DateTime.parse(s['test_date']), _selectedDay)).map((s) => _buildSyllabusItem(s, isDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.pinkAccent.withOpacity(0.2))),
        child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.event_note_rounded, color: Colors.pinkAccent, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(event['exam_title'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
               Text(DateFormat('EEEE, h:mm a').format(DateTime.parse(event['exam_date'])), style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
        ]),
      ),
    );
  }

  Widget _buildSyllabusItem(Map<String, dynamic> s, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
        child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.menu_book_rounded, color: Colors.indigoAccent, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(s['subject'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
               Text('SYLLABUS TARGET DATE', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
        ]),
      ),
    );
  }

  void _showAddDeadlineModal() {
    final titleCtrl = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(builder: (c, setModalState) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(c).viewInsets.bottom + 32),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADD IMPORTANT DATE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 20),
            TextField(controller: titleCtrl, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), decoration: InputDecoration(hintText: 'Event Title...', filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: time);
                if (t != null) setModalState(() => time = t);
              },
              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.schedule, color: Colors.indigoAccent, size: 16), const SizedBox(width: 12), Text(time.format(context), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26))])),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              final fullDateTime = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, time.hour, time.minute);
              await _db.createExamDeadline(titleCtrl.text, fullDateTime);
              Navigator.pop(c);
              _loadEvents();
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('ENGAGE PLANNER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      )),
    );
  }
}
