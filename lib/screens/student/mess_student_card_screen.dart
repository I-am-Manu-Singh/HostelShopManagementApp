import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'mess_menu_screen.dart';

class MessStudentCardScreen extends StatefulWidget {
  const MessStudentCardScreen({super.key});

  @override
  State<MessStudentCardScreen> createState() => _MessStudentCardScreenState();
}

class _MessStudentCardScreenState extends State<MessStudentCardScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _attendance = [];
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _card;
  int _attendedDays = 0;
  int _skippedDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    try {
      final profile = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      final card = await _client.from('mess_cards').select().eq('user_id', user.id).maybeSingle();
      final att = await _client.from('attendance').select().eq('user_id', user.id).eq('attendance_type', 'mess').order('date', ascending: false);

      if (mounted) {
        final now = DateTime.now();
        final attended = att.length;
        int skipped = now.day - attended;
        if (skipped < 0) skipped = 0;

        setState(() {
          _profile = profile;
          _card = card;
          _attendance = att;
          _attendedDays = attended;
          _skippedDays = skipped;
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MESS CARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    // Desktop/Wide View: 2-column layout split
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                FadeInDown(child: _buildPhysicalCard(_card != null, isDark)),
                                const SizedBox(height: 24),
                                _buildStatsRow(isDark),
                                const SizedBox(height: 32),
                                _buildQuickAction(isDark),
                              ],
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Colors.black12),
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTodayMenuSection(isDark),
                                const SizedBox(height: 48),
                                _buildSectionHeader('ATTENDANCE HISTORY', isDark),
                                const SizedBox(height: 16),
                                _buildAttendanceCalendar(isDark),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile View: Single column layout
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        FadeInDown(child: _buildPhysicalCard(_card != null, isDark)),
                        const SizedBox(height: 24),
                        _buildStatsRow(isDark),
                        const SizedBox(height: 32),
                        _buildTodayMenuSection(isDark),
                        const SizedBox(height: 32),
                        _buildQuickAction(isDark),
                        const SizedBox(height: 48),
                        _buildSectionHeader('ATTENDANCE HISTORY', isDark),
                        const SizedBox(height: 16),
                        _buildAttendanceCalendar(isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(top: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildStatsRow(bool isDark) {
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    return Row(
      children: [
        _statItem('ATTENDED', '$_attendedDays', Colors.greenAccent, cardColor, isDark),
        const SizedBox(width: 12),
        _statItem('SKIPPED', '$_skippedDays', Colors.redAccent, cardColor, isDark),
        const SizedBox(width: 12),
        _statItem('REMAINING', '${30 - DateTime.now().day}', Colors.blueAccent, cardColor, isDark),
      ],
    );
  }

  Widget _statItem(String label, String val, Color c, Color bg, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(children: [
          Text(val, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Align(alignment: Alignment.centerLeft, child: Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.orangeAccent, letterSpacing: 2)));
  }

  Widget _buildPhysicalCard(bool hasActiveCard, bool isDark) {
    final expiryStr = _card != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(_card!['expiry_date'])) : 'NO ACTIVE PLAN';
    final planStr = _card != null ? _card!['card_type'] : 'TRIAL ACCESS';
    final meals = _card?['meal_plan'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: hasActiveCard ? [const Color(0xFFFF8C00), const Color(0xFFFF4500)] : [Colors.grey.shade800, Colors.grey.shade900], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [(hasActiveCard ? Colors.orangeAccent : Colors.black).withOpacity(0.2)].map((c) => BoxShadow(color: c, blurRadius: 40, offset: const Offset(0, 20))).toList(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 28),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(planStr.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
          ]),
          const SizedBox(height: 48),
          Text(_profile?['full_name']?.toUpperCase() ?? 'RESIDENT', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('EXPIRES ON: $expiryStr', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mealBadge('BREAKFAST', meals.contains('B')),
              _mealBadge('LUNCH', meals.contains('L')),
              _mealBadge('TEA', meals.contains('T')),
              _mealBadge('DINNER', meals.contains('D')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMenuSection(bool isDark) {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now).toUpperCase();
    
    // Static mapping for demo (matching MessMenuScreen)
    final menuMap = {
      'MONDAY': {'B': 'Poha & Chai', 'L': 'Rajma Chawal', 'T': 'Samosa & Tea', 'D': 'Paneer & Roti'},
      'TUESDAY': {'B': 'Aloo Paratha', 'L': 'Kadadi Chawal', 'T': 'Biscuits & Coffee', 'D': 'Mix Veg & Roti'},
      'WEDNESDAY': {'B': 'Idli Sambhar', 'L': 'Chole Bhature', 'T': 'Bread Pakora & Tea', 'D': 'Dal Tadka & Rice'},
      'THURSDAY': {'B': 'Oatmeal & Fruits', 'L': 'Veg Biryani', 'T': 'Puff Pastry & Tea', 'D': 'Malai Kofta & Roti'},
      'FRIDAY': {'B': 'Sandwich & Coffee', 'L': 'Pasta & Salad', 'T': 'Maggie & Cold Drinks', 'D': 'Palak Paneer'},
      'SATURDAY': {'B': 'Puri Bhaji', 'L': 'Fried Rice', 'T': 'Dhokla & Tea', 'D': 'Special Thali'},
      'SUNDAY': {'B': 'Stuffed Paratha', 'L': 'Paneer Lababdar', 'T': 'Cake & Coffee', 'D': 'Veg Pulao & Raita'},
    };

    final todayMenu = menuMap[dayName] ?? menuMap['MONDAY']!;

    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('TODAY\'S MENU - $dayName', isDark),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: Column(
              children: [
                _menuRow('MORNING', todayMenu['B']!, Icons.wb_sunny_outlined, Colors.amberAccent),
                const Divider(height: 32, color: Colors.white10),
                _menuRow('AFTERNOON', todayMenu['L']!, Icons.wb_cloudy_outlined, Colors.blueAccent),
                const Divider(height: 32, color: Colors.white10),
                _menuRow('EVENING', todayMenu['T']!, Icons.local_cafe_outlined, Colors.orangeAccent),
                const Divider(height: 32, color: Colors.white10),
                _menuRow('NIGHT', todayMenu['D']!, Icons.nightlight_round_outlined, Colors.purpleAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(String type, String val, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.5), size: 18),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type, style: const TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          Text(val, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ],
    );
  }

  Widget _buildQuickAction(bool isDark) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessMenuScreen())),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.orangeAccent, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FULL MENU ARCHIVE', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Browse weekly provisioning schedule', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.orangeAccent, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mealBadge(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 45, height: 45,
          decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: active ? Colors.white54 : Colors.white10)),
          child: Center(child: Text(label[0], style: TextStyle(color: active ? Colors.white : Colors.white24, fontWeight: FontWeight.w900, fontSize: 18))),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: active ? Colors.white70 : Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAttendanceCalendar(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), 
        borderRadius: BorderRadius.circular(32), 
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MONTHLY LOG', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 24),
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now(),
            focusedDay: DateTime.now(),
            calendarFormat: CalendarFormat.month,
            headerVisible: false,
            daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold), weekendStyle: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: textColor),
              weekendTextStyle: const TextStyle(color: Colors.orangeAccent),
              todayDecoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) => _buildDayCell(day, isDark),
              todayBuilder: (context, day, focusedDay) => _buildDayCell(day, isDark, isToday: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, bool isDark, {bool isToday = false}) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final meals = _attendance.where((a) => a['date'] == dateStr).toList();
    final hasData = meals.isNotEmpty;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)) : (hasData ? Colors.orangeAccent.withOpacity(0.1) : Colors.transparent),
        shape: BoxShape.circle,
        border: Border.all(color: isToday ? (isDark ? Colors.white24 : Colors.black26) : (hasData ? Colors.orangeAccent.withOpacity(0.4) : Colors.transparent)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}', style: TextStyle(color: hasData ? Colors.orangeAccent : (isToday ? textColor : textColor.withOpacity(0.5)), fontWeight: isToday || hasData ? FontWeight.w900 : FontWeight.normal, fontSize: 12)),
            if (hasData)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(meals.length, (i) => Container(margin: const EdgeInsets.only(top: 2, right: 1), width: 3, height: 3, decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle))),
              ),
          ],
        ),
      ),
    );
  }
}
