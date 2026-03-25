import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../models/shop.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String type; // 'hostel' or 'mess' or 'staff'
  final String? userId; // Optional for admin mode
  const AttendanceCalendarScreen({super.key, required this.type, this.userId});

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Attendance>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final client = Supabase.instance.client;
    final targetId = widget.userId ?? client.auth.currentUser!.id;
    
    final response = await client
        .from('attendance')
        .select()
        .eq('user_id', targetId)
        .eq('attendance_type', widget.type)
        .order('date', ascending: false);
        
    final Map<DateTime, List<Attendance>> newEvents = {};
    for (var a in (response as List)) {
      final model = Attendance.fromJson(a);
      final date = DateTime(model.date.year, model.date.month, model.date.day);
      if (newEvents[date] == null) newEvents[date] = [];
      newEvents[date]!.add(model);
    }
    if (mounted) {
      setState(() {
        _events = newEvents;
        _isLoading = false;
      });
    }
  }

  List<Attendance> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('${widget.type.toUpperCase()} DOSSIER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : Column(
              children: [
                _buildCalendar(),
                const SizedBox(height: 20),
                Expanded(child: _buildEventList()),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2026, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        calendarStyle: CalendarStyle(
          markerDecoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
          defaultTextStyle: const TextStyle(color: Colors.white70),
          weekendTextStyle: const TextStyle(color: Colors.white38),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay!);
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_outlined, color: Colors.white12, size: 60),
            const SizedBox(height: 15),
            Text('No logs for this date', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final a = events[index];
        return FadeInUp(
          delay: Duration(milliseconds: 100 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(color: (a.status == 'Present' || a.status == 'present') ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                   child: Icon(widget.type == 'mess' ? Icons.fastfood_rounded : Icons.security_rounded, color: (a.status == 'Present' || a.status == 'present') ? Colors.greenAccent : Colors.redAccent, size: 16),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.type == 'staff' ? 'DUTY DEPLOYMENT' : (widget.type == 'mess' ? 'MEAL CONSUMPTION' : 'RESIDENT LOG'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (a.mealType != null) Text('TYPE: ${a.mealType}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))
                    else Text('STATUS: ${a.status.toUpperCase()}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text(a.status.toUpperCase(), style: TextStyle(color: (a.status == 'Present' || a.status == 'present') ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
              ],
            ),
          ),
        );
      },
    );
  }
}
