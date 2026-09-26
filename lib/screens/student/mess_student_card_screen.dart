import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'mess_menu_screen.dart';
import 'student_payment_screen.dart';

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
  double _messPackagePrice = 0.0;

  // DOJ-based billing cycle (synchronized with StudentPaymentScreen)
  DateTime? _cycleStart;
  DateTime? _cycleEnd;
  int _cycleDays = 30;

  Map<String, dynamic>? _todayMenuFromDb;

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
      final enrollment = await _client.from('hostel_enrollments').select().eq('user_id', user.id).maybeSingle();

      // Fetch live mess menu from database for today
      Map<String, dynamic>? liveMenu;
      try {
        final now = DateTime.now();
        final dayName = DateFormat('EEEE').format(now);
        // Calculate week of year
        final firstDayOfYear = DateTime(now.year, 1, 1);
        final weekNum = ((now.difference(firstDayOfYear).inDays + firstDayOfYear.weekday - 1) / 7).floor() + 1;
        
        // 1. Try to find menu for specific week
        final specificWeekMenu = await _client.from('mess_menu').select()
            .ilike('day', dayName)
            .eq('week_number', weekNum)
            .maybeSingle();

        if (specificWeekMenu != null) {
          liveMenu = specificWeekMenu;
        } else {
          // 2. Try default schedule (week_number 0 or any available)
          final defaultMenu = await _client.from('mess_menu').select()
              .ilike('day', dayName)
              .maybeSingle();
          liveMenu = defaultMenu;
        }
      } catch (_) {}
      
      // Determine Mess card package price dynamically from card record or fee_structure
      double messPrice = card != null && card['price'] != null ? (card['price'] as num).toDouble() : 0.0;
      try {
        final feeRes = await _client.from('fee_structure').select().eq('category', 'Mess').maybeSingle();
        if (feeRes != null && feeRes['price'] != null) {
          messPrice = (feeRes['price'] as num).toDouble();
        }
      } catch (_) {}

      // ── DOJ-based billing cycle (same logic as StudentPaymentScreen) ─────
      DateTime? cycleStart;
      DateTime? cycleEnd;
      int cycleDuration = 30;
      // Use enrollment.created_at first, then profile.date_of_joining as fallback
      final joinDateStr = enrollment?['created_at'] ?? profile?['date_of_joining'];
      if (joinDateStr != null) {
        try {
          final joined = DateTime.parse(joinDateStr.toString());
          final now = DateTime.now();
          final joinDay = joined.day;
          final safeDay = joinDay > 28 ? 28 : joinDay;
          final candidateStart = DateTime(now.year, now.month, safeDay);
          if (now.isBefore(candidateStart)) {
            final prevMonth = now.month == 1 ? 12 : now.month - 1;
            final prevYear = now.month == 1 ? now.year - 1 : now.year;
            cycleStart = DateTime(prevYear, prevMonth, safeDay);
            cycleEnd = candidateStart;
          } else {
            cycleStart = candidateStart;
            final nextMonth = now.month == 12 ? 1 : now.month + 1;
            final nextYear = now.month == 12 ? now.year + 1 : now.year;
            cycleEnd = DateTime(nextYear, nextMonth, safeDay);
          }
          cycleDuration = cycleEnd.difference(cycleStart).inDays;
        } catch (_) {}
      }

      if (mounted) {
        final now = DateTime.now();
        // Count attendance within the current billing cycle
        final cycleAtt = cycleStart != null
            ? att.where((a) {
                try {
                  final d = DateTime.parse(a['date'].toString());
                  return !d.isBefore(cycleStart!) && d.isBefore(cycleEnd ?? now.add(const Duration(days: 1)));
                } catch (_) { return false; }
              }).length
            : att.length;
        final attended = cycleAtt;
        int skipped = (cycleStart != null ? now.difference(cycleStart!).inDays : now.day) - attended;
        if (skipped < 0) skipped = 0;

        setState(() {
          _profile = profile;
          _card = card;
          _attendance = att;
          _attendedDays = attended;
          _skippedDays = skipped;
          _messPackagePrice = messPrice;
          _todayMenuFromDb = liveMenu;
          _cycleStart = cycleStart;
          _cycleEnd = cycleEnd;
          _cycleDays = cycleDuration;
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
    final daysRemaining = _cycleEnd != null
        ? _cycleEnd!.difference(DateTime.now()).inDays.clamp(0, _cycleDays)
        : (30 - DateTime.now().day).clamp(0, 30);
    return Row(
      children: [
        _statItem('ATTENDED', '$_attendedDays', Colors.greenAccent, cardColor, isDark),
        const SizedBox(width: 12),
        _statItem('SKIPPED', '$_skippedDays', Colors.redAccent, cardColor, isDark),
        const SizedBox(width: 12),
        _statItem('REMAINING', '$daysRemaining', Colors.blueAccent, cardColor, isDark),
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
    // ── Billing cycle: prefer DOJ-based cycle, fall back to card dates ───────
    String startStr;
    String expiryStr;
    if (_cycleStart != null && _cycleEnd != null) {
      startStr  = DateFormat('dd MMM yyyy').format(_cycleStart!);
      expiryStr = DateFormat('dd MMM yyyy').format(_cycleEnd!);
    } else if (_card != null && _card!['start_date'] != null) {
      startStr  = DateFormat('dd MMM yyyy').format(DateTime.parse(_card!['start_date'].toString()));
      expiryStr = _card!['expiry_date'] != null
          ? DateFormat('dd MMM yyyy').format(DateTime.parse(_card!['expiry_date'].toString()))
          : 'NO ACTIVE PLAN';
    } else if (_card != null && _card!['created_at'] != null) {
      startStr  = DateFormat('dd MMM yyyy').format(DateTime.parse(_card!['created_at'].toString()));
      expiryStr = 'NO ACTIVE PLAN';
    } else {
      startStr  = 'NOT STARTED';
      expiryStr = 'NO ACTIVE PLAN';
    }
    final planStr = _card != null ? (_card!['card_type'] ?? 'MESS PASS') : 'TRIAL ACCESS';
    final meals = _card?['meal_plan'] ?? 'BLTD';
    final int customDays = _cycleDays > 0 ? _cycleDays : (_card?['custom_days'] ?? 30);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('₹${_messPackagePrice.toInt()} ($customDays DAYS)', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(planStr.toString().toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 36),
          Text(_profile?['full_name']?.toUpperCase() ?? 'RESIDENT', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text('CYCLE: $startStr  ➔  $expiryStr', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$customDays-DAY PLAN PERIOD', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPaymentScreen(initialType: 'MessCard'))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(hasActiveCard ? 'RENEW / EXTEND' : 'ACTIVATE', style: GoogleFonts.outfit(color: Colors.deepOrange, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
    
    // Live database values with fallback
    final bFast = (_todayMenuFromDb?['breakfast']?.toString().trim().isNotEmpty == true)
        ? _todayMenuFromDb!['breakfast'].toString()
        : 'Poha & Chai';
    final lunch = (_todayMenuFromDb?['lunch']?.toString().trim().isNotEmpty == true)
        ? _todayMenuFromDb!['lunch'].toString()
        : 'Dal, Roti & Seasonal Sabzi';
    final tea = (_todayMenuFromDb?['tea']?.toString().trim().isNotEmpty == true)
        ? _todayMenuFromDb!['tea'].toString()
        : 'Snacks & Hot Tea';
    final dinner = (_todayMenuFromDb?['dinner']?.toString().trim().isNotEmpty == true)
        ? _todayMenuFromDb!['dinner'].toString()
        : 'Special Paneer / Curries & Rice';

    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('TODAY\'S MENU - $dayName', isDark),
              if (_todayMenuFromDb != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: const Text('LIVE ACTIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: Column(
              children: [
                _menuRow('BREAKFAST', bFast, Icons.wb_sunny_outlined, Colors.amberAccent),
                const Divider(height: 32, color: Colors.white10),
                _menuRow('LUNCH', lunch, Icons.wb_cloudy_outlined, Colors.blueAccent),
                const Divider(height: 32, color: Colors.white10),
                _menuRow('TEA & SNACKS', tea, Icons.local_cafe_outlined, Colors.orangeAccent),
                const Divider(height: 32, color: Colors.white10),
                _menuRow('DINNER', dinner, Icons.nightlight_round_outlined, Colors.purpleAccent),
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
