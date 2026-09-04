import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/csv_range_dialog.dart';
import '../../utils/csv_web_helper.dart';

class AdminMessMenuScreen extends StatefulWidget {
  const AdminMessMenuScreen({super.key});

  @override
  State<AdminMessMenuScreen> createState() => _AdminMessMenuScreenState();
}

class _AdminMessMenuScreenState extends State<AdminMessMenuScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _menu = [];
  final List<String> _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  DateTime _selectedWeekDate = DateTime.now();

  int get _currentWeekNumber {
    final firstDayOfYear = DateTime(_selectedWeekDate.year, 1, 1);
    final daysDiff = _selectedWeekDate.difference(firstDayOfYear).inDays;
    return (daysDiff / 7).ceil();
  }

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final weekNum = _currentWeekNumber;
      final year = _selectedWeekDate.year;

      // Try fetching week-specific menu
      var res = await _client
          .from('mess_menu')
          .select()
          .eq('week_number', weekNum)
          .eq('year', year)
          .order('id');

      // If no menu configured for this specific week yet, fallback to default schedule (week_number 0 or any baseline)
      if (res.isEmpty) {
        res = await _client.from('mess_menu').select().eq('week_number', 0).order('id');
      }
      // If still empty, fetch any available rows
      if (res.isEmpty) {
        res = await _client.from('mess_menu').select().order('id');
      }

      if (mounted) setState(() { _menu = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2028),
      helpText: 'SELECT WEEK DATE TO VIEW / EDIT',
    );
    if (picked != null) {
      setState(() => _selectedWeekDate = picked);
      _fetchMenu();
    }
  }

  Future<void> _exportMessMenuToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Mess Menu Schedule',
      isImport: false,
    );
    if (range == null) return;

    try {
      final List<String> csvHeaders = [
        'week_number',
        'year',
        'day',
        'breakfast',
        'lunch',
        'tea',
        'dinner',
        'updated_at'
      ];
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));

      // Fetch all menus from database or use currently loaded menu
      List<dynamic> allMenus = [];
      try {
        allMenus = await _client.from('mess_menu').select().order('day');
      } catch (_) {
        allMenus = _menu;
      }
      if (allMenus.isEmpty) {
        allMenus = _menu;
      }

      for (var item in allMenus) {
        final List<String> row = [
          item['week_number']?.toString() ?? '0',
          item['year']?.toString() ?? '2026',
          '"${(item['day']?.toString() ?? '').replaceAll('"', '""')}"',
          '"${(item['breakfast']?.toString() ?? '').replaceAll('"', '""')}"',
          '"${(item['lunch']?.toString() ?? '').replaceAll('"', '""')}"',
          '"${(item['tea']?.toString() ?? '').replaceAll('"', '""')}"',
          '"${(item['dinner']?.toString() ?? '').replaceAll('"', '""')}"',
          item['updated_at']?.toString() ?? item['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'mess_menu_schedule_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Mess Menu Schedule Export ($dateLabel)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final weekStart = _selectedWeekDate.subtract(Duration(days: _selectedWeekDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel = '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM yyyy').format(weekEnd)} (Wk $_currentWeekNumber)';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MESS SCHEDULE MANAGER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
            Text(weekLabel, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            tooltip: 'Export Menu (CSV/Dates)',
            icon: const Icon(Icons.file_download_rounded, color: Colors.indigoAccent),
            onPressed: _exportMessMenuToCSV,
          ),
          IconButton(
            tooltip: 'Pick Week',
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), 
            onPressed: _pickWeek,
          ),
          IconButton(
            tooltip: 'Refresh Menu',
            icon: const Icon(Icons.refresh_rounded, color: Colors.indigoAccent), 
            onPressed: _fetchMenu,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : LayoutBuilder(
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
              final day = _days[i];
              final dayData = _menu.firstWhere((m) => (m['day']?.toString().toUpperCase() == day), orElse: () => {'day': day});
              return _buildDayCard(dayData, isDark);
            },
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: _days.length,
          itemBuilder: (context, i) {
            final day = _days[i];
            final dayData = _menu.firstWhere((m) => (m['day']?.toString().toUpperCase() == day), orElse: () => {'day': day});
            return _buildDayCard(dayData, isDark);
          },
        );
      }
    ),
    );
  }

  Widget _buildDayCard(dynamic data, bool isDark) {
    final String day = data['day'] ?? 'UNKNOWN';
    final textColor = isDark ? Colors.white : Colors.black;
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 3)),
                _editBtn(() => _showEditBottomSheet(data, isDark), isDark),
              ],
            ),
            const SizedBox(height: 24),
            _menuRow('BREAKFAST', data['breakfast'] ?? 'Manual Deployment Required', Icons.wb_sunny_rounded, Colors.amberAccent, isDark),
            _menuRow('LUNCH', data['lunch'] ?? 'Manual Deployment Required', Icons.wb_twilight_rounded, Colors.orangeAccent, isDark),
            _menuRow('TEA', data['tea'] ?? 'Manual Deployment Required', Icons.coffee_rounded, Colors.purpleAccent, isDark),
            _menuRow('DINNER', data['dinner'] ?? 'Manual Deployment Required', Icons.nightlight_round, Colors.indigoAccent, isDark),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(String label, String val, IconData icon, Color c, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: c, size: 14)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const SizedBox(height: 4), Text(val, style: GoogleFonts.outfit(color: isDark?Colors.white70:Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, height: 1.4))])),
        ],
      ),
    );
  }

  Widget _editBtn(VoidCallback onTap, bool isDark) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.edit_note_rounded, color: Colors.indigoAccent, size: 20)));
  }

  void _showEditBottomSheet(dynamic data, bool isDark) {
    final bCtrl = TextEditingController(text: data['breakfast']);
    final lCtrl = TextEditingController(text: data['lunch']);
    final tCtrl = TextEditingController(text: data['tea']);
    final dCtrl = TextEditingController(text: data['dinner']);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(32, 40, 32, MediaQuery.of(ctx).viewInsets.bottom + 40),
        decoration: BoxDecoration(color: isDark?const Color(0xFF16181A):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RECONFIGURE_${data['day'].toUpperCase()}_MENU', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 32),
              _menuInput('BREAKFAST_MENU', bCtrl, isDark),
              _menuInput('LUNCH_MENU', lCtrl, isDark),
              _menuInput('TEA_CONFIG', tCtrl, isDark),
              _menuInput('DINNER_SYSTEM', dCtrl, isDark),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, height: 65, child: ElevatedButton(onPressed: () async {
                 try {
                   final weekNum = _currentWeekNumber;
                   final year = _selectedWeekDate.year;
                   final updatePayload = {
                     'week_number': weekNum,
                     'year': year,
                     'day': data['day'],
                     'breakfast': bCtrl.text.trim(),
                     'lunch': lCtrl.text.trim(),
                     'tea': tCtrl.text.trim(),
                     'dinner': dCtrl.text.trim(),
                   };

                   // 1. Save specific week menu
                   await _client.from('mess_menu').upsert(
                     updatePayload,
                     onConflict: 'week_number, year, day',
                   );

                   // 2. Also keep default base schedule in sync if editing current week
                   await _client.from('mess_menu').upsert({
                     'week_number': 0,
                     'year': 2026,
                     'day': data['day'],
                     'breakfast': bCtrl.text.trim(),
                     'lunch': lCtrl.text.trim(),
                     'tea': tCtrl.text.trim(),
                     'dinner': dCtrl.text.trim(),
                   }, onConflict: 'week_number, year, day');

                   if (mounted) {
                     Navigator.pop(ctx);
                     _fetchMenu();
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${data['day']} (WK $weekNum) MENU SAVED TO DATABASE'), backgroundColor: Colors.indigoAccent));
                   }
                 } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPLOYMENT_ERROR: $e'), backgroundColor: Colors.redAccent));
                 }
              }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: Text('DEPLOY_SCHEDULE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)))),
            ],
          ),
        ),
      ),
    );
  }

  void _checkDateMenu() async {
     final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2026));
     if (d != null) {
       final dayName = DateFormat('EEEE').format(d).toUpperCase();
       final menu = _menu.firstWhere((m) => m['day']?.toString().toUpperCase() == dayName, orElse: () => null);
       if (mounted) {
         showDialog(
           context: context,
           builder: (ctx) => AlertDialog(
             backgroundColor: Theme.of(context).scaffoldBackgroundColor,
             title: Text(dayName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
             content: menu == null ? const Text('No menu configured for this day.') : Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('B: ${menu['breakfast'] ?? 'N/A'}'),
                 Text('L: ${menu['lunch'] ?? 'N/A'}'),
                 Text('T: ${menu['tea'] ?? 'N/A'}'),
                 Text('D: ${menu['dinner'] ?? 'N/A'}'),
               ],
             ),
             actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('DISMISS'))],
           )
         );
       }
     }
  }

  Widget _menuInput(String l, TextEditingController c, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(controller: c, maxLines: 2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: l, labelStyle: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1), filled: true, fillColor: isDark?Colors.white.withOpacity(0.02):Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: isDark?Colors.white10:Colors.black12)))),
    );
  }
}
