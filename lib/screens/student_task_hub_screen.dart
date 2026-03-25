import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/database_service.dart';
import 'zen_protocol_screen.dart';
import 'workout_protocol_screen.dart';
import 'academic_intelligence_hub_screen.dart';
import 'reminders_nexus_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/eisenhower_matrix.dart';
import 'pomodoro_protocol_screen.dart';

class StudentTaskHubScreen extends StatefulWidget {
  const StudentTaskHubScreen({super.key});

  @override
  State<StudentTaskHubScreen> createState() => _StudentTaskHubScreenState();
}

class _StudentTaskHubScreenState extends State<StudentTaskHubScreen> {
  final _db = DatabaseService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String _selectedCategory = 'ALL';
  Map<String, dynamic> _stats = {'total': 0, 'completed': 0, 'rate': 0.0};
  final List<String> _categories = ['ALL', 'STUDY', 'PERSONAL', 'HOSTEL', 'WORK'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tasks = await _db.fetchStudentTasks(_selectedDate);
    final stats = await _db.fetchStudentDailyStats();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _stats = stats;
        _isLoading = false;
      });
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
        title: Text('MY TASKS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_active_rounded, color: Colors.indigoAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersNexusScreen()))),
          IconButton(icon: const Icon(Icons.school_rounded, color: Colors.indigoAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicIntelligenceHubScreen()))),
          IconButton(icon: const Icon(Icons.fitness_center_rounded, color: Colors.orangeAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutProtocolScreen()))),
          IconButton(icon: const Icon(Icons.self_improvement_rounded, color: Colors.tealAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ZenProtocolScreen()))),
          IconButton(icon: const Icon(Icons.analytics_outlined, color: Colors.indigoAccent), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskModal,
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlow(),
          Column(
            children: [
              _buildCalendarBar(isDark),
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _buildAnalyticsCard(isDark),
                          const SizedBox(height: 32),
                          EisenhowerMatrix(tasks: _tasks),
                          const SizedBox(height: 32),
                          _buildCategoryFilter(isDark),
                        const SizedBox(height: 32),
                        _buildMotivationalHeader(textColor),
                        const SizedBox(height: 32),
                        ..._tasks.isEmpty 
                          ? [_buildEmptyState(isDark)] 
                          : _tasks.map((t) => _buildTaskTimelineItem(t, isDark)).toList(),
                        const SizedBox(height: 32),
                        _buildCommunityFocusIntel(isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _analyticMini('TOTAL', '${_stats['total']}', isDark),
          _analyticMini('COMPLETED', '${_stats['completed']}', isDark),
          _analyticMini('RATE', '${((_stats['rate'] ?? 0.0) * 100).toInt()}%', isDark),
        ],
      ),
    );
  }

  Widget _analyticMini(String l, String v, bool isDark) {
    return Column(children: [ Text(v, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 24, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5))]);
  }

  Widget _buildBackgroundGlow() {
    return Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildCalendarBar(bool isDark) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().subtract(const Duration(days: 3)).add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 55,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(date).toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(date.day.toString(), style: GoogleFonts.outfit(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFocusCard() {
    final double rate = _stats['rate'] ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DAILY TASKS', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('${(rate * 100).toInt()}% COMPLETED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('${_stats['completed']} of ${_stats['total']} objectives cleared', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 60, height: 60, child: CircularProgressIndicator(value: rate, backgroundColor: Colors.white10, color: Colors.indigoAccent, strokeWidth: 8)),
            Icon(rate >= 1 ? Icons.check_circle_rounded : Icons.radar_rounded, color: Colors.indigoAccent, size: 24),
          ]),
        ],
      ),
    );
  }

  Widget _buildAcademicIntelSummary() {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicIntelligenceHubScreen())).then((_) => _loadData()),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.15), Colors.black.withOpacity(0.5)]), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
          child: Row(children: [
             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ACADEMIC INTELLIGENCE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('SYLLABUS & VAULT', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             ]),
             const Spacer(),
             const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.indigoAccent, size: 28),
          ]),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFocusCard(),
        const SizedBox(height: 32),
        _buildAcademicIntelSummary(), // NEW: Quick link to Academic Intel
      ],
    );
  }

  Widget _buildMotivationalHeader(Color textColor) {
    return FadeInLeft(
      child: Row(children: [
        const Icon(Icons.electric_bolt_rounded, color: Colors.orangeAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('FINISH YOUR TASKS TO ACHIEVE YOUR GOALS.', style: GoogleFonts.outfit(color: textColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1))),
      ]),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(Icons.assignment_turned_in_rounded, size: 60, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        const SizedBox(height: 16),
        Text('NO TASKS FOUND', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('Add a new task to start tracking.', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 12)),
      ],
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MY CATEGORIES', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                  ),
                  child: Text(cat, style: GoogleFonts.outfit(color: isSelected ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTimelineItem(dynamic task, bool isDark) {
    if (_selectedCategory != 'ALL' && task['category'] != _selectedCategory.toLowerCase()) return const SizedBox.shrink();
    bool isCompleted = task['is_completed'] ?? false;
    final textColor = isDark ? Colors.white : Colors.black;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              Text(task['start_time']?.toString().substring(0,5) ?? '00:00', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(width: 2, height: 60, color: isCompleted ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12)),
            ]),
            const SizedBox(width: 24),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                   await _db.updateStudentTask(task['id'], {'is_completed': !isCompleted});
                   _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.indigoAccent.withOpacity(0.05) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isCompleted ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                         Row(children: [
                            Icon(Icons.circle, color: task['priority'] == 'high' ? Colors.redAccent : (task['priority'] == 'medium' ? Colors.orangeAccent : Colors.blueAccent), size: 8),
                            const SizedBox(width: 12),
                            Text(task['title'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isCompleted ? Colors.indigoAccent : textColor.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14)),
                         ]),
                         if (isCompleted) const Icon(Icons.check_circle_rounded, color: Colors.indigoAccent, size: 20),
                      ]),
                      if (task['description'] != null) Text(task['description'], style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
                      const SizedBox(height: 16),
                      Row(children: [
                         _miniAction(Icons.timer_outlined, 'Focus', () => _launchPomodoro(task)),
                         const SizedBox(width: 12),
                         _miniAction(Icons.edit_note_rounded, 'Notes', () => _showWorkLogModal(task)),
                         const Spacer(),
                         if (!isCompleted && DateUtils.isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1))))
                           _miniAction(Icons.history_rounded, 'Move to Today', () => _rescheduleTask(task), color: Colors.orangeAccent),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniAction(IconData icon, String label, VoidCallback onTap, {Color color = Colors.indigoAccent}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [Icon(icon, color: color, size: 12), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900))]),
      ),
    );
  }

  Widget _buildCommunityFocusIntel(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
           const Icon(Icons.people_alt_rounded, color: Colors.indigoAccent, size: 14),
           const SizedBox(width: 8),
           Text('PEOPLE FOCUSING', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('study_status', 'focusing'),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyFocusIntel(isDark);
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, i) => _focusUserAvatar(snapshot.data![i], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyFocusIntel(bool isDark) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))), child: Center(child: Text('NO ONE IS CURRENTLY FOCUSING', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5))));
  }

  Widget _focusUserAvatar(dynamic user, bool isDark) {
    final name = user['full_name']?.toString() ?? 'SYSTEM_USER';
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(children: [
        Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(radius: 20, backgroundColor: isDark ? Colors.white10 : Colors.black12, child: Text(name[0], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12))),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF0F172A) : Colors.white, width: 2))),
        ]),
        const SizedBox(height: 4),
        Text(name.split(' ')[0], style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showAddTaskModal() {
    final titleCtrl = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    String recurrence = 'none';
    String priority = 'medium';
    String category = 'study';
    bool isUrgent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(builder: (c, setModalState) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(c).viewInsets.bottom + 32),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADD NEW TASK', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 20),
            Row(children: [
               Expanded(child: TextField(controller: titleCtrl, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), decoration: InputDecoration(hintText: 'Task Title...', filled: true, fillColor: Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))))),
               const SizedBox(width: 12),
               DropdownButton<String>(
                  value: priority,
                  dropdownColor: Theme.of(context).cardColor,
                  items: ['low', 'medium', 'high'].map((p) => DropdownMenuItem(value: p, child: Row(children: [Icon(Icons.circle, color: p == 'high' ? Colors.redAccent : (p == 'medium' ? Colors.orangeAccent : Colors.blueAccent), size: 10), const SizedBox(width: 8), Text(p.toUpperCase(), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 10))]))).toList(),
                  onChanged: (v) => setModalState(() => priority = v!),
               ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
               Expanded(child: GestureDetector(
                 onTap: () async {
                   final t = await showTimePicker(context: context, initialTime: startTime);
                   if (t != null) setModalState(() => startTime = t);
                 },
                 child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.schedule, color: Colors.indigoAccent, size: 16), const SizedBox(width: 12), Text(startTime.format(context), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)))])),
               )),
               const SizedBox(width: 12),
                Expanded(child: DropdownButton<String>(
                   value: recurrence,
                   dropdownColor: Theme.of(context).cardColor,
                   isExpanded: true,
                   underline: const SizedBox(),
                   items: ['none', 'daily', 'weekly'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase(), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 11)))).toList(),
                   onChanged: (v) => setModalState(() => recurrence = v!),
                )),
             ]),
             const SizedBox(height: 20),
             Row(children: [
                Expanded(child: DropdownButton<String>(
                   value: category,
                   dropdownColor: Theme.of(context).cardColor,
                   isExpanded: true,
                   underline: const SizedBox(),
                   items: ['study', 'personal', 'hostel', 'work'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase(), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 11)))).toList(),
                   onChanged: (v) => setModalState(() => category = v!),
                )),
                const SizedBox(width: 12),
                Text('URGENT', style: GoogleFonts.outfit(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold)),
                Switch(value: isUrgent, activeColor: Colors.redAccent, onChanged: (v) => setModalState(() => isUrgent = v)),
             ]),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () async {
               if (titleCtrl.text.isEmpty) return;
               await _db.addStudentTask({
                 'title': titleCtrl.text,
                 'task_date': _selectedDate.toIso8601String().split('T')[0],
                 'start_time': '${startTime.hour}:${startTime.minute}',
                 'recurrence': recurrence,
                 'priority': priority,
                 'category': category.toLowerCase(),
                 'is_urgent': isUrgent,
               });
               Navigator.pop(c);
               _loadData();
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('ADD TASK'))),
          ],
        ),
      )),
    );
  }

  void _showWorkLogModal(dynamic task) {
    final logCtrl = TextEditingController(text: task['log_entry']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(c).viewInsets.bottom + 32),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('TASK NOTES', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
             const SizedBox(height: 24),
             Text('Title: ${task['title']}', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold)),
             const SizedBox(height: 24),
             TextField(controller: logCtrl, maxLines: 5, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13), decoration: InputDecoration(hintText: 'What did you accomplish?', filled: true, fillColor: Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
             const SizedBox(height: 32),
             SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () async {
                await _db.updateStudentTask(task['id'], {'log_entry': logCtrl.text});
                Navigator.pop(c);
                _loadData();
             }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('SAVE NOTES'))),
          ],
        ),
      ),
    );
  }

  void _rescheduleTask(dynamic task) async {
     final nextDate = DateTime.now();
     await _db.updateStudentTask(task['id'], {
       'task_date': nextDate.toIso8601String().split('T')[0],
       'rescheduled_from': task['task_date'],
     });
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task moved to today.'), backgroundColor: Colors.indigoAccent));
     _loadData();
  }

  void _launchPomodoro(dynamic task) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => PomodoroProtocolScreen(taskName: task['title'], taskId: task['id'])));
  }
}
