import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/shop.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String type; // 'gate', 'mess', 'night', or 'staff'
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

  // Status → colour mapping shared across the screen
  static const Map<String, Color> _statusColors = {
    'present':   Color(0xFF4ADE80), // green
    'Present':   Color(0xFF4ADE80),
    'leave':     Color(0xFFFB923C), // orange
    'paid_leave':Colors.blue,
    'half_day':  Color(0xFFFACC15), // amber
    'off_duty':  Color(0xFF94A3B8), // slate
    'absent':    Color(0xFFF87171), // red
  };

  Color _colorForStatus(String status) =>
      _statusColors[status] ?? const Color(0xFFF87171);

  IconData _iconForType(String type) {
    switch (type) {
      case 'mess':  return Icons.fastfood_rounded;
      case 'night': return Icons.bedtime_rounded;
      default:      return Icons.security_rounded; // gate
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final client = Supabase.instance.client;
    final targetId = widget.userId ?? client.auth.currentUser?.id;
    if (targetId == null) return;

    try {
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
        newEvents.putIfAbsent(date, () => []).add(model);
      }
      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AttendanceCalendar error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Attendance> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF08090A) : const Color(0xFFF8FAFF);
    final textColor = isDark ? Colors.white : Colors.black;
    final stats = _computeMonthlyStats(); // Updated name

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.type.toUpperCase()} ATTENDANCE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: textColor,
                    letterSpacing: 2)),
            Text(DateFormat('MMMM yyyy').format(_focusedDay).toUpperCase(),
                style: GoogleFonts.outfit(
                    color: Colors.indigoAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor, size: 20),
            onPressed: _loadAttendance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : Column(
              children: [
                _buildCalendar(isDark, textColor),
                const SizedBox(height: 8),
                _buildLegend(isDark),
                const SizedBox(height: 8),
                _buildStatsWidget(stats, isDark), // Updated call
                const SizedBox(height: 8),
                Expanded(child: _buildEventList(isDark, textColor)),
              ],
            ),
    );
  }

  // Renamed data calculator
  Map<String, int> _computeMonthlyStats() {
    final stats = <String, int>{};
    for (final dayEvents in _events.values) {
      for (final a in dayEvents) {
        final key = a.status.toLowerCase();
        stats[key] = (stats[key] ?? 0) + 1;
      }
    }
    return stats;
  }

  Widget _buildCalendar(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: TableCalendar<Attendance>(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2028, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        onPageChanged: (fd) => setState(() => _focusedDay = fd),
        calendarBuilders: CalendarBuilders(
          // Custom marker dots coloured by status
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            final colours = events
                .map((e) => _colorForStatus(e.status))
                .toSet()
                .toList();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: colours.take(3).map((c) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              )).toList(),
            );
          },
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
              color: Colors.indigoAccent.withOpacity(0.2),
              shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(
              color: Colors.indigoAccent, shape: BoxShape.circle),
          defaultTextStyle: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500),
          weekendTextStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38),
          outsideTextStyle: TextStyle(
              color: isDark ? Colors.white12 : Colors.black12),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.outfit(
              color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
          rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
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

  Widget _buildLegend(bool isDark) {
    final entries = [
      ('Present',    const Color(0xFF4ADE80)),
      ('Leave',      const Color(0xFFFB923C)),
      ('Half Day',   const Color(0xFFFACC15)),
      ('Paid Leave', Colors.blue),
      ('Off Duty',   const Color(0xFF94A3B8)),
      ('Absent',     const Color(0xFFF87171)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: entries.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: e.$2, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(e.$1,
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ],
        )).toList(),
      ),
    );
  }
// Renamed UI builder
  Widget _buildStatsWidget(Map<String, int> stats, bool isDark) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final total = stats.values.fold(0, (a, b) => a + b);
    final present = (stats['present'] ?? 0) + (stats['Present'] ?? 0);
    final leave = (stats['leave'] ?? 0) + (stats['paid_leave'] ?? 0);
    final half = stats['half_day'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.indigoAccent.withOpacity(0.08) : Colors.indigoAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('$present', 'PRESENT', const Color(0xFF4ADE80), isDark),
          _statChip('$leave', 'LEAVE', const Color(0xFFFB923C), isDark),
          _statChip('$half', 'HALF', const Color(0xFFFACC15), isDark),
          _statChip('$total', 'TOTAL', Colors.indigoAccent, isDark),
        ],
      ),
    );
  }

  Widget _statChip(String val, String label, Color color, bool isDark) {
    return Column(
      children: [
        Text(val,
            style: GoogleFonts.outfit(
                color: color, fontWeight: FontWeight.w900, fontSize: 20)),
        Text(label,
            style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildEventList(bool isDark, Color textColor) {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (events.isEmpty) {
      final hasAnyEvent = _events.containsKey(
          DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day));
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasAnyEvent ? Icons.event_busy_outlined : Icons.calendar_today_outlined,
              color: isDark ? Colors.white12 : Colors.black12,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('MMMM d, yyyy').format(_selectedDay ?? _focusedDay).toUpperCase(),
              style: GoogleFonts.outfit(
                  color: Colors.indigoAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            Text('No records for this date',
                style: GoogleFonts.outfit(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            DateFormat('MMMM d, yyyy').format(_selectedDay ?? _focusedDay).toUpperCase(),
            style: GoogleFonts.outfit(
                color: Colors.indigoAccent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final a = events[index];
              final color = _colorForStatus(a.status);
              final statusLabel = a.status.toUpperCase().replaceAll('_', ' ');

              return FadeInUp(
                delay: Duration(milliseconds: 80 * index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                    boxShadow: isDark
                        ? []
                        : [BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Icon(_iconForType(a.type),
                            color: color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.type == 'mess'
                                  ? 'MEAL RECORD'
                                  : a.type == 'night'
                                      ? 'NIGHT CHECK-IN'
                                      : 'GATE LOG',
                              style: GoogleFonts.outfit(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            if (a.mealType != null)
                              Text('MEAL: ${a.mealType!.toUpperCase()}',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold))
                            else
                              Text(
                                  DateFormat('EEEE, MMM d').format(a.date).toUpperCase(),
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(statusLabel,
                            style: GoogleFonts.outfit(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
