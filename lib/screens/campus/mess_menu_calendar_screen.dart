import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MessMenuCalendarScreen extends StatefulWidget {
  const MessMenuCalendarScreen({super.key});

  @override
  State<MessMenuCalendarScreen> createState() => _MessMenuCalendarScreenState();
}

class _MessMenuCalendarScreenState extends State<MessMenuCalendarScreen> {
  final _client = Supabase.instance.client;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = false;
  Map<String, dynamic>? _currentDayMenu;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchDayMenu(_selectedDay!);
  }

  int _getWeekNumber(DateTime dt) {
    final firstDayOfYear = DateTime(dt.year, 1, 1);
    final diff = dt.difference(firstDayOfYear).inDays;
    return (diff / 7).ceil();
  }

  Future<void> _fetchDayMenu(DateTime dt) async {
    setState(() => _isLoading = true);
    try {
      final dayName = DateFormat('EEEE').format(dt).toUpperCase();
      final weekNum = _getWeekNumber(dt);
      final year = dt.year;

      // 1. Try week specific menu
      var res = await _client
          .from('mess_menu')
          .select()
          .eq('day', dayName)
          .eq('week_number', weekNum)
          .eq('year', year)
          .maybeSingle();

      // 2. Fallback to default schedule (week_number 0)
      res ??= await _client
          .from('mess_menu')
          .select()
          .eq('day', dayName)
          .eq('week_number', 0)
          .maybeSingle();

      // 3. Fallback to any record for this day
      res ??= await _client
          .from('mess_menu')
          .select()
          .eq('day', dayName)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _currentDayMenu = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        title: Text('MENU ARCHIVE & FUTURE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 20),
          Expanded(child: _buildDayMenu()),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TableCalendar(
        firstDay: DateTime.utc(2025, 1, 1),
        lastDay: DateTime.utc(2026, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: Colors.white70),
          weekendTextStyle: const TextStyle(color: Colors.white38),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
          rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _fetchDayMenu(selectedDay);
        },
      ),
    );
  }

  Widget _buildDayMenu() {
    if (_selectedDay == null) return const SizedBox();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }
    
    final b = _currentDayMenu?['breakfast'] ?? 'Poha & Hot Chai';
    final l = _currentDayMenu?['lunch'] ?? 'Dal Tadka, Sabzi & Rice';
    final t = _currentDayMenu?['tea'] ?? 'Snacks & Evening Tea';
    final d = _currentDayMenu?['dinner'] ?? 'Paneer / Veg & Hot Rotis';
    final kcal = _currentDayMenu?['calories'] ?? '2250';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MENU FOR ${_selectedDay!.day} ${_getMonthName(_selectedDay!.month).toUpperCase()}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
          const SizedBox(height: 16),
          _mealBox('BREAKFAST', b, Icons.wb_sunny_outlined, Colors.amberAccent),
          const SizedBox(height: 12),
          _mealBox('LUNCH', l, Icons.wb_cloudy_outlined, Colors.blueAccent),
          const SizedBox(height: 12),
          _mealBox('TEA-TIME', t, Icons.local_cafe_outlined, Colors.orangeAccent),
          const SizedBox(height: 12),
          _mealBox('DINNER', d, Icons.nightlight_round_outlined, Colors.purpleAccent),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ENERGY ESTIMATE', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                Text('$kcal KCAL', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _mealBox(String label, String val, IconData icon, Color c) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: c, size: 20)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ])),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
