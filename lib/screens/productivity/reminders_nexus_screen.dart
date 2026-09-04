import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';

class RemindersNexusScreen extends StatefulWidget {
  const RemindersNexusScreen({super.key});

  @override
  State<RemindersNexusScreen> createState() => _RemindersNexusScreenState();
}

class _RemindersNexusScreenState extends State<RemindersNexusScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _reminders = [];

  final List<Map<String, dynamic>> _commonReminders = [
    {'title': 'DRINK WATER', 'type': 'hydration', 'desc': 'Remind me to drink water every hour', 'icon': Icons.water_drop_rounded, 'color': Colors.blueAccent},
    {'title': 'EYE REST (20-20-20)', 'type': 'eye_rest', 'desc': 'Take a break for your eyes every 20 mins', 'icon': Icons.visibility_rounded, 'color': Colors.tealAccent},
    {'title': 'FIX POSTURE', 'type': 'posture', 'desc': 'Check your sitting posture every 30 mins', 'icon': Icons.accessibility_new_rounded, 'color': Colors.orangeAccent},
  ];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final res = await _db.fetchReminders();
      if (mounted) {
        setState(() {
          _reminders = res;
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
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text('HEALTH REMINDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              Text('DAILY RITUALS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 16),
              ..._commonReminders.map((r) => _ritualCard(r, isDark)),
              const SizedBox(height: 40),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text('CUSTOM ALARMS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                 IconButton(onPressed: () => _showAddAlarmModal(isDark), icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent, size: 24)),
              ]),
              const SizedBox(height: 8),
              if (_reminders.isEmpty) Center(child: Text('NO CUSTOM ALARMS SET', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)))
              else ..._reminders.map((al) => _alarmCard(al, isDark)),
              const SizedBox(height: 48),
            ],
          ),
    );
  }

  Widget _ritualCard(Map<String, dynamic> r, bool isDark) {
    bool isActive = _reminders.any((rem) => rem['reminder_type'] == r['type'] && rem['is_active']);
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: r['color'].withOpacity(0.2))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: r['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(r['icon'] as IconData, color: r['color'], size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(r['title'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
           const SizedBox(height: 2),
           Text(r['desc'], style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
        ])),
        Switch(value: isActive, activeColor: r['color'], onChanged: (val) async {
           if (val) {
              await _db.createReminder(r['title'], r['type'], '09:00', [1,2,3,4,5]);
           } else {
              final activeRem = _reminders.firstWhere((rem) => rem['reminder_type'] == r['type'] && rem['is_active']);
              await _db.toggleReminder(activeRem['id'], false);
           }
           _loadReminders();
        }),
      ]),
    );
  }

  Widget _alarmCard(Map<String, dynamic> al, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(al['scheduled_time']?.substring(0, 5) ?? '00:00', style: GoogleFonts.outfit(color: textColor, fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
           const SizedBox(height: 4),
           Text(al['title'].toString().toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
        const Spacer(),
        Switch(value: al['is_active'] == true, activeColor: Colors.indigoAccent, onChanged: (val) async {
           await _db.toggleReminder(al['id'], val);
           _loadReminders();
        }),
      ]),
    );
  }

  void _showAddAlarmModal(bool isDark) {
    final titleCtrl = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 6, minute: 0);
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(context).viewInsets.bottom + 28),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text('NEW ALARM', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                 const SizedBox(height: 24),
                 TextField(controller: titleCtrl, style: TextStyle(color: textColor), decoration: _inputDeco('Alarm Name (e.g. Study Session)', isDark)),
                 const SizedBox(height: 20),
                 InkWell(
                    onTap: () async {
                       final t = await showTimePicker(context: context, initialTime: time);
                       if (t != null) setModalState(() => time = t);
                    },
                    child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.access_time_filled_rounded, color: Colors.indigoAccent, size: 20), const SizedBox(width: 12), Text('TIME: ${time.format(context)}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                 ),
                 const SizedBox(height: 32),
                 SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                    onPressed: () async {
                       await _db.createReminder(titleCtrl.text, 'custom_alarm', '${time.hour}:${time.minute}:00', [1,2,3,4,5]);
                       Navigator.pop(context);
                       _loadReminders();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('SET ALARM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                 )),
              ]),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDeco(String h, bool isDark) => InputDecoration(hintText: h, hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(20));
}
