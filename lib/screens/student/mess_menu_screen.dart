import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../mess_menu_calendar_screen.dart';

class MessMenuScreen extends StatefulWidget {
  const MessMenuScreen({super.key});

  @override
  State<MessMenuScreen> createState() => _MessMenuScreenState();
}

class _MessMenuScreenState extends State<MessMenuScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _menu = [];
  DateTime _selectedDate = DateTime.now();

  final List<String> _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

  int get _weekNumber {
    final firstDayOfYear = DateTime(_selectedDate.year, 1, 1);
    final diff = _selectedDate.difference(firstDayOfYear).inDays;
    return (diff / 7).ceil();
  }

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    setState(() => _isLoading = true);
    try {
      final week = _weekNumber;
      final year = _selectedDate.year;

      var res = await _client
          .from('mess_menu')
          .select()
          .eq('week_number', week)
          .eq('year', year)
          .order('id');

      if (res.isEmpty) {
        res = await _client.from('mess_menu').select().eq('week_number', 0).order('id');
      }
      if (res.isEmpty) {
        res = await _client.from('mess_menu').select().order('id');
      }

      if (mounted) {
        setState(() {
          _menu = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectWeekCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2028),
      helpText: 'SELECT WEEK DATE',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel = '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM yyyy').format(weekEnd)}';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MESS MENU', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
            Text(weekLabel, style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            tooltip: 'Choose Week',
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.orangeAccent),
            onPressed: _selectWeekCalendar,
          ),
          IconButton(
            tooltip: 'Calendar Archive',
            icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.indigoAccent), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessMenuCalendarScreen())),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                  if (crossCount > 1) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: _days.length,
                      itemBuilder: (context, i) {
                        final d = _days[i];
                        final dayData = _menu.firstWhere((m) => m['day']?.toString().toUpperCase() == d, orElse: () => {
                          'day': d,
                          'breakfast': 'Poha & Hot Tea',
                          'lunch': 'Dal Tadka & Rice',
                          'tea': 'Snacks & Tea',
                          'dinner': 'Seasonal Sabzi & Roti',
                          'calories': '2200'
                        });
                        return FadeInUp(
                          delay: Duration(milliseconds: i * 50),
                          child: _buildDayCard(dayData, isDark),
                        );
                      },
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _days.length,
                    itemBuilder: (context, i) {
                      final d = _days[i];
                      final dayData = _menu.firstWhere((m) => m['day']?.toString().toUpperCase() == d, orElse: () => {
                        'day': d,
                        'breakfast': 'Poha & Hot Tea',
                        'lunch': 'Dal Tadka & Rice',
                        'tea': 'Snacks & Tea',
                        'dinner': 'Seasonal Sabzi & Roti',
                        'calories': '2200'
                      });
                      return FadeInUp(
                        delay: Duration(milliseconds: i * 100),
                        child: _buildDayCard(dayData, isDark),
                      );
                    },
                  );
                }
              ),
            ],
          ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildDayCard(Map<String, dynamic> data, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data['day'], style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text('${data['calories']} KCAL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 20),
          _mealItem('BREAKFAST', data['breakfast'], Icons.wb_sunny_outlined, Colors.amberAccent, isDark),
          const SizedBox(height: 12),
          _mealItem('LUNCH', data['lunch'], Icons.wb_cloudy_outlined, Colors.blueAccent, isDark),
          const SizedBox(height: 12),
          _mealItem('TEA-TIME', data['tea'], Icons.local_cafe_outlined, Colors.orangeAccent, isDark),
          const SizedBox(height: 12),
          _mealItem('DINNER', data['dinner'], Icons.nightlight_round_outlined, Colors.purpleAccent, isDark),
        ],
      ),
    );
  }

  Widget _mealItem(String type, String menu, IconData icon, Color c, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: c.withOpacity(0.6), size: 16),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(menu, style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
