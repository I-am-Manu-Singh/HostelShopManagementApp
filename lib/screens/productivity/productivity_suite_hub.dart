import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'student/student_task_hub_screen.dart';
import 'academic_intelligence_hub_screen.dart';
import 'zen_protocol_screen.dart';
import 'workout_protocol_screen.dart';
import 'reminders_nexus_screen.dart';
import 'pomodoro_protocol_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../widgets/mini_music_player.dart';
import '../../services/music_service.dart';
import '../../widgets/habit_tracker_card.dart';
import 'daily_routine_screen.dart';
import 'productivity_calendar_screen.dart';
import 'focus_mode_screen.dart';
import 'campus_leaderboard_screen.dart';

class ProductivitySuiteHub extends StatefulWidget {
  const ProductivitySuiteHub({super.key});

  @override
  State<ProductivitySuiteHub> createState() => _ProductivitySuiteHubState();
}

class _ProductivitySuiteHubState extends State<ProductivitySuiteHub> {
  int _currentIndex = 0;
  final _db = DatabaseService();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    MusicService().init();
    _pages = [
      const _PerformanceDashboard(),
      const StudentTaskHubScreen(),
      const AcademicIntelligenceHubScreen(),
      const _WellnessCabinet(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final navColor = isDark ? const Color(0xFF16181A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniMusicPlayer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 0),
            decoration: BoxDecoration(
              color: navColor,
              border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.indigoAccent,
              unselectedItemColor: isDark ? Colors.white24 : Colors.black26,
              selectedLabelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 10, letterSpacing: 0.5),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'STATS'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'TASKS'),
                BottomNavigationBarItem(icon: Icon(Icons.school_rounded), label: 'ACADEMICS'),
                BottomNavigationBarItem(icon: Icon(Icons.self_improvement_rounded), label: 'WELLNESS'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceDashboard extends StatefulWidget {
  const _PerformanceDashboard();

  @override
  State<_PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<_PerformanceDashboard> with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
   Map<String, dynamic>? _profile;
   List<Map<String, dynamic>> _reflections = [];
   DateTime _focusedDay = DateTime.now();
   DateTime? _selectedDay;
   bool _isLoading = true;
   late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _breathingController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await _db.fetchUserProfile();
      final reflectRes = await _db.fetchReflections();
      final routineRes = await _db.fetchDailyRoutine();
      
      // Calculate current protocol from routine
      Map<String, dynamic>? current;
      try {
        final now = TimeOfDay.now();
        final nowMins = now.hour * 60 + now.minute;
        for (var block in routineRes) {
          final start = _parseTime(block['start_time']);
          final end = _parseTime(block['end_time']);
          if (nowMins >= (start.hour * 60 + start.minute) && nowMins < (end.hour * 60 + end.minute)) {
            current = block;
            break;
          }
        }
      } catch(_) {}

      if (mounted) {
        setState(() {
          _profile = userRes;
          _reflections = reflectRes;
          _currentProtocol = current;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay _parseTime(String t) {
    final p = t.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Map<String, dynamic>? _currentProtocol;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dailyReflection = _reflections.where((r) => isSameDay(DateTime.parse(r['log_date'] ?? DateTime.now().toIso8601String()), _selectedDay)).toList();

    return _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)) : RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.indigoAccent,
      child: Stack(
        children: [
          _buildBreathingBg(),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 48),
              _buildHeader(isDark),
              const SizedBox(height: 32),
              _buildProductivityScore(isDark),
              const SizedBox(height: 32),
              _buildStudyBuddies(isDark),
              _buildFocusStats(isDark),
              const SizedBox(height: 32),
              _buildCurrentProtocolCard(isDark),
              const SizedBox(height: 32),
              _buildFocusModeBanner(isDark),
              const SizedBox(height: 32),
              _buildMasterCalendarBanner(isDark),
              const SizedBox(height: 32),
              _buildAnalyticsSummary(isDark),
              const SizedBox(height: 32),
              if (dailyReflection.isEmpty && isSameDay(_selectedDay, DateTime.now())) _buildReflectionPrompt(isDark),
              const SizedBox(height: 24),
              _buildDayReflectionCard(dailyReflection.firstOrNull, isDark),
              const SizedBox(height: 40),
              _buildHistoryStrip(isDark),
              const SizedBox(height: 120),
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
              Colors.indigoAccent.withOpacity(0.04 * _breathingController.value),
              Colors.transparent,
            ],
            radius: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMasterCalendarBanner(bool isDark) {
    return FadeInRight(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductivityCalendarScreen())),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181A) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(0.05), blurRadius: 20)],
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.calendar_month_rounded, color: Colors.pinkAccent)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MASTER CHRONICLE', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Unified view of exams, tasks & habits.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.pinkAccent, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentProtocolCard(bool isDark) {
    final title = _currentProtocol?['title'] ?? 'REST & RECHARGE';
    final endTime = _currentProtocol?['end_time'] ?? '--:--';
    final iconName = _currentProtocol?['icon_name'] ?? 'bolt';

    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyRoutineScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.indigoAccent.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle), child: Icon(_getIcon(iconName), color: Colors.indigoAccent, size: 24)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT PROTOCOL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Text(title.toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('UNTIL', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                  Text(endTime, style: const TextStyle(color: Colors.indigoAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'meditation': return Icons.self_improvement_rounded;
      case 'workout': return Icons.fitness_center_rounded;
      case 'lecture': return Icons.school_rounded;
      case 'coding': return Icons.code_rounded;
      case 'reading': return Icons.menu_book_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'sleep': return Icons.hotel_rounded;
      default: return Icons.bolt_rounded;
    }
  }

  Widget _buildHistoryStrip(bool isDark) {
    if (_reflections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT LOGS', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _reflections.length,
            itemBuilder: (ctx, i) {
              final r = _reflections[i];
              final date = DateTime.parse(r['log_date'] ?? DateTime.now().toIso8601String());
              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('MMM dd').format(date), style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${r['satisfaction_rating']}', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('RATING', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSummary(bool isDark) {
    if (_reflections.isEmpty) return const SizedBox.shrink();
    
    double avgSat = _reflections.map((r) => (r['satisfaction_rating'] ?? 0) as int).reduce((a, b) => a + b) / _reflections.length;
    double avgFocus = _reflections.map((r) => (r['focus_rating'] ?? 0) as int).reduce((a, b) => a + b) / _reflections.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('MY TRENDS', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 16),
       Row(children: [
          _analyticCard('AVG SATISFACTION', '${avgSat.toStringAsFixed(1)}/10', Icons.mood_rounded, Colors.tealAccent, isDark),
          const SizedBox(width: 12),
          _analyticCard('FOCUS LEVEL', '${avgFocus.toStringAsFixed(1)}/10', Icons.psychology_rounded, Colors.orangeAccent, isDark),
       ]),
    ]);
  }

  Widget _analyticCard(String t, String v, IconData i, Color c, bool isDark) {
    return Expanded(child: Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.2))),
       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c, size: 24),
          const SizedBox(height: 16),
          Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(t, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
       ]),
     ));
  }

  Widget _buildCalendar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) => setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        }),
        calendarStyle: CalendarStyle(
           selectedDecoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
           todayDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), shape: BoxShape.circle),
           defaultTextStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
           weekendTextStyle: const TextStyle(color: Colors.indigoAccent),
           outsideTextStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white : Colors.black),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildDayReflectionCard(Map<String, dynamic>? reflection, bool isDark) {
    if (reflection == null) return Center(child: Text('NO LOGS FOR SELECTED DAY', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)));
    final textColor = isDark ? Colors.white : Colors.black;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('DAY SUMMARY', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 16),
       Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.indigoAccent.withOpacity(0.1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _ratingBadge(reflection['satisfaction_rating'] ?? 0),
                Text('FOCUS: ${reflection['focus_rating']}/10', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
             ]),
             const SizedBox(height: 20),
             Text('"${reflection['feeling'] ?? "No message"}"', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18, fontStyle: FontStyle.italic)),
             const SizedBox(height: 12),
             Text(reflection['achievements'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.5)),
             if (reflection['goals_met'] != null && (reflection['goals_met'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: (reflection['goals_met'] as List).map((g) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(g, style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)))).toList()),
             ],
          ]),
       ),
    ]);
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('PROGRESS PANEL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 4),
       Text('STUDENT STATS', style: GoogleFonts.outfit(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildFocusModeBanner(bool isDark) {
    return FadeInLeft(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FocusModeScreen())),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRODUCTIVITY SHELL', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Enter Focus Mode to block distractions.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudyBuddies(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('STUDY BUDDIES', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CampusLeaderboardScreen())),
              child: Text('VIEW LEADERBOARD', style: TextStyle(color: Colors.indigoAccent.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<dynamic>>(
          future: Supabase.instance.client.from('profiles').select().eq('study_status', 'focusing').limit(5),
          builder: (context, snapshot) {
            final buddies = snapshot.data ?? [];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.indigoAccent.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  if (buddies.isNotEmpty)
                    SizedBox(
                      height: 32,
                      width: buddies.length * 24.0,
                      child: Stack(
                        children: List.generate(buddies.length, (i) => Positioned(
                          left: i * 20.0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                              child: Text(buddies[i]['full_name']?[0] ?? 'P', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        )),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      buddies.isEmpty ? 'Be the first one to start focusing today!' : '${buddies.length} Students are currently in Deep Focus!',
                      style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildFocusStats(bool isDark) {
    final int xp = (_profile?['xp'] ?? _profile?['xp_total'] ?? 0) as int;
    final int level = (_profile?['student_level'] ?? 1) as int;
    final double hours = ((_profile?['total_focus_time'] ?? 0) / 3600).toDouble();

    return Row(children: [
       _statBox('XP', '$xp', Colors.indigoAccent, isDark),
       const SizedBox(width: 12),
       _statBox('LEVEL', '$level', Colors.orangeAccent, isDark),
       const SizedBox(width: 12),
       _statBox('HOURS', hours.toStringAsFixed(1), Colors.greenAccent, isDark),
    ]);
  }

  Widget _statBox(String l, String v, Color c, bool isDark) {
    return Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.2))), child: Column(children: [
       Text(v, style: GoogleFonts.outfit(color: c, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
       const SizedBox(height: 4),
       Text(l, style: TextStyle(color: c.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
    ])));
  }

  Widget _buildProductivityScore(bool isDark) {
    int score = 84; // Mock score for now
    String status = score > 80 ? "EXCELLENT" : (score > 60 ? "GOOD" : "NEED FOCUS");
    Color color = score > 80 ? Colors.greenAccent : (score > 60 ? Colors.orangeAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 80, height: 80, child: CircularProgressIndicator(value: score / 100, strokeWidth: 8, color: color, backgroundColor: color.withOpacity(0.1), strokeCap: StrokeCap.round)),
              Text('$score', style: GoogleFonts.outfit(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRODUCTIVITY SCORE', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                Text(status, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Based on focus consistency & app retention.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionPrompt(bool isDark) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.2), isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6)]), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text('HOW WAS YOUR DAY?', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           Text('Take a moment to log your thoughts and progress.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
           const SizedBox(height: 24),
           SizedBox(
             width: double.infinity, height: 55,
             child: ElevatedButton(
                onPressed: () => _showReflectionModal(isDark),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('LOG MY DAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
             ),
           ),
        ]),
      ),
    );
  }

  Widget _ratingBadge(int r) {
    Color c = r > 7 ? Colors.greenAccent : (r > 4 ? Colors.orangeAccent : Colors.redAccent);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('SATISFACTION: $r/10', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)));
  }

  void _showReflectionModal(bool isDark) {
     final achiveCtrl = TextEditingController();
     final feelCtrl = TextEditingController();
     int satisfaction = 7;
     int focus = 8;

     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
           builder: (context, setModalState) => Container(
              padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(context).viewInsets.bottom + 28),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text('DAILY REFLECTION', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                 const SizedBox(height: 24),
                 TextField(controller: feelCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputDeco('Overall mood / mental state today?', isDark)),
                 const SizedBox(height: 16),
                 TextField(controller: achiveCtrl, maxLines: 3, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputDeco('Top achievements today...', isDark)),
                 const SizedBox(height: 24),
                 Text('SATISFACTION RATING: $satisfaction', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                 Slider(min: 1, max: 10, divisions: 9, activeColor: Colors.indigoAccent, value: satisfaction.toDouble(), onChanged: (v) => setModalState(() => satisfaction = v.toInt())),
                 const SizedBox(height: 32),
                 SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                    onPressed: () async {
                       await _db.createReflection(achiveCtrl.text, focus, feelCtrl.text, satisfaction, []);
                       Navigator.pop(ctx);
                       _loadData();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('SAVE REFLECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                 )),
              ]),
           ),
        ),
     );
  }

  InputDecoration _inputDeco(String h, bool isDark) => InputDecoration(hintText: h, hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20));
}

class _WellnessCabinet extends StatelessWidget {
  const _WellnessCabinet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final db = DatabaseService();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Text('WELLNESS HUB', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text('MIND & BODY', style: GoogleFonts.outfit(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        _wellnessItem(context, 'DAILY PROTOCOL', 'CORE_MOMENTUM & FOCUS SESSIONS', Icons.bolt_rounded, Colors.orangeAccent, const DailyRoutineScreen(), isDark),
        _wellnessItem(context, 'MEDITATION', 'Simple breathing & mindfulness', Icons.self_improvement_rounded, Colors.tealAccent, const ZenProtocolScreen(), isDark),
        _wellnessItem(context, 'FOCUS TIMER', 'Pomodoro sessions for deep work', Icons.timer_rounded, Colors.indigoAccent, const PomodoroProtocolScreen(), isDark),
        _wellnessItem(context, 'WORKOUTS', 'Log your physical activity & exercises', Icons.fitness_center_rounded, Colors.greenAccent, const WorkoutProtocolScreen(), isDark),
        _wellnessItem(context, 'REMINDERS', 'Stay hydrated and check posture', Icons.notifications_active_rounded, Colors.indigoAccent, const RemindersNexusScreen(), isDark),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('DAILY HABITS', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersNexusScreen())),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('CUSTOMIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: Colors.indigoAccent),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: db.fetchReminders(),
          builder: (context, snapshot) {
            final habits = snapshot.data?.where((r) => r['reminder_type'] == 'Habit').toList() ?? [];
            if (habits.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                child: Center(child: Text('NO HABITS CONFIGURED', style: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black12, fontWeight: FontWeight.bold, fontSize: 12))),
              );
            }
            return Column(
              children: habits.map<Widget>((h) => HabitTrackerCard(
                title: h['title'],
                subtitle: h['time'] ?? 'Daily',
                isCompleted: h['is_completed'] ?? false,
                lastWeekStatus: const [true, true, false, true, true, false, false],
                onToggle: () => db.toggleReminder(h['id'], !(h['is_completed'] ?? false)),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _wellnessItem(BuildContext context, String title, String desc, IconData icon, Color c, Widget screen, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: c.withOpacity(0.1))),
        child: Row(children: [
           Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: c, size: 28)),
           const SizedBox(width: 20),
           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(desc, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
           ])),
           Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 16),
        ]),
      ),
    );
  }
}
