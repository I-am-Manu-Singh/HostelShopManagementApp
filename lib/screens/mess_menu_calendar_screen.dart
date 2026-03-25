import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class MessMenuCalendarScreen extends StatefulWidget {
  const MessMenuCalendarScreen({super.key});

  @override
  State<MessMenuCalendarScreen> createState() => _MessMenuCalendarScreenState();
}

class _MessMenuCalendarScreenState extends State<MessMenuCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mock menu data for different days
  final Map<int, Map<String, String>> _weeklyMenu = {
    1: {'B': 'Poha & Chai', 'L': 'Rajma Chawal', 'D': 'Paneer & Roti', 'Kcal': '2100'},
    2: {'B': 'Aloo Paratha', 'L': 'Kadhi Chawal', 'D': 'Mix Veg & Roti', 'Kcal': '2300'},
    3: {'B': 'Idli Sambhar', 'L': 'Chole Bhature', 'D': 'Dal Tadka & Rice', 'Kcal': '2250'},
    4: {'B': 'Oatmeal & Fruits', 'L': 'Veg Biryani', 'D': 'Malai Kofta & Roti', 'Kcal': '2400'},
    5: {'B': 'Sandwich & Coffee', 'L': 'Pasta & Salad', 'D': 'Palak Paneer', 'Kcal': '2150'},
    6: {'B': 'Puri Bhaji', 'L': 'Fried Rice', 'D': 'Special Thali', 'Kcal': '2600'},
    7: {'B': 'Stuffed Paratha', 'L': 'Paneer Lababdar', 'D': 'Veg Pulao & Raita', 'Kcal': '2500'},
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
        },
      ),
    );
  }

  Widget _buildDayMenu() {
    if (_selectedDay == null) return const SizedBox();
    final menu = _weeklyMenu[_selectedDay!.weekday]!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROVISIONING FOR ${_selectedDay!.day} ${_getMonthName(_selectedDay!.month).toUpperCase()}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
          const SizedBox(height: 16),
          _mealBox('BREAKFAST', menu['B']!, Icons.wb_sunny_outlined, Colors.amberAccent),
          const SizedBox(height: 12),
          _mealBox('LUNCH', menu['L']!, Icons.wb_cloudy_outlined, Colors.blueAccent),
          const SizedBox(height: 12),
          _mealBox('DINNER', menu['D']!, Icons.nightlight_round_outlined, Colors.purpleAccent),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ENERGY ESTIMATE', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                Text('${menu['Kcal']} KCAL', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
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
