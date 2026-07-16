import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../services/database_service.dart';
import 'mess_gate_terminal_screen.dart';
import '../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

class CentralAttendanceLogScreen extends StatefulWidget {
  const CentralAttendanceLogScreen({super.key});

  @override
  State<CentralAttendanceLogScreen> createState() => _CentralAttendanceLogScreenState();
}

class _CentralAttendanceLogScreenState extends State<CentralAttendanceLogScreen> {
  final _db = DatabaseService();
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _personnel = [];
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  String _activeTab = 'mess';

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final String roleFilter = _activeTab == 'staff' ? 'staff' : (_activeTab == 'mess' ? 'mess_student' : 'hostel_student');
      var profileQuery = _client.from('profiles').select().eq('role', roleFilter);
      
      // 🧠 IMPROVED: For Mess tab, also fetch 'hostel_student' who might need a mess card
      if (_activeTab == 'mess') {
        profileQuery = _client.from('profiles').select().inFilter('role', ['hostel_student', 'mess_student', 'HOSTEL_STUDENT', 'MESS_STUDENT']);
      }
      final profiles = await profileQuery.order('full_name');
      
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendanceRes = await _client.from('attendance')
          .select()
          .eq('attendance_type', _activeTab == 'staff' ? 'staff' : _activeTab)
          .eq('date', dateStr);

      if (mounted) {
        setState(() {
          _personnel = (profiles as List).map((p) {
            final pAtt = (attendanceRes as List).where((a) => a['user_id'] == p['id']).toList();
            p['_attendance'] = pAtt;
            return Map<String, dynamic>.from(p);
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAttendance(String pid, String type, {String? mealType}) async {
    final ok = await _db.markAttendance(
      type: type, 
      studentId: pid, 
      mealType: mealType, 
      date: _selectedDate,
      status: 'Present'
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked ${mealType ?? type} for user'), backgroundColor: Colors.indigoAccent, duration: const Duration(seconds: 1)));
      _loadAttendanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark?const Color(0xFF08090A):Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final filtered = _personnel.where((s) => s['full_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? true).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('CENTRAL ATTENDANCE LOG', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent, size: 22),
            onPressed: _exportAttendanceMonthly,
            tooltip: 'Export Monthly CSV',
          ),
          IconButton(icon: const Icon(Icons.calendar_today_rounded, color: Colors.indigoAccent, size: 20), onPressed: _pickDate),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'kiosk',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessGateTerminalScreen())),
            backgroundColor: Colors.indigoAccent,
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
            label: Text('GATE TERMINAL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'issue',
            onPressed: () => _issueCard(isDark),
            backgroundColor: Colors.orangeAccent,
            icon: const Icon(Icons.add_card_rounded, color: Colors.black, size: 20),
            label: Text('RENEW MESS CARD', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Column(
            children: [
              _buildStatsHeader(filtered, isDark),
              _buildTabSwitcher(isDark),
              _buildSearchHeader(isDark),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _buildPersonnelCard(filtered[i], isDark),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime.now());
    if (d != null) {
      setState(() => _selectedDate = d);
      _loadAttendanceData();
    }
  }

  Future<void> _exportAttendanceMonthly() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: '$_activeTab Attendance',
      isImport: false,
    );
    if (range == null) return;

    setState(() => _isLoading = true);

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(range.startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(range.endDate);

      final daysList = <DateTime>[];
      for (int i = 0; i <= range.endDate.difference(range.startDate).inDays; i++) {
        daysList.add(range.startDate.add(Duration(days: i)));
      }

      // Fetch profiles matching current active tab type
      final String roleFilter = _activeTab == 'staff' ? 'staff' : (_activeTab == 'mess' ? 'mess_student' : 'hostel_student');
      var profileQuery = _client.from('profiles').select().eq('role', roleFilter);
      if (_activeTab == 'mess') {
        profileQuery = _client.from('profiles').select().inFilter('role', ['hostel_student', 'mess_student', 'HOSTEL_STUDENT', 'MESS_STUDENT']);
      }
      final profiles = await profileQuery.order('full_name');
      final List<dynamic> targetProfiles = profiles as List;

      // Fetch attendance logs for this type and date range
      final attRes = await _client.from('attendance')
          .select()
          .eq('attendance_type', _activeTab == 'staff' ? 'staff' : _activeTab)
          .gte('date', startStr)
          .lte('date', endStr);
      final List<dynamic> rangeAttendance = attRes as List;

      // Make CSV Headers: Name, Role, User ID, Date 1, Date 2, ...
      final buffer = StringBuffer();
      final headers = ['Name', 'Role', 'User ID'];
      for (final day in daysList) {
        headers.add(DateFormat('yyyy-MM-dd').format(day));
      }
      buffer.writeln(headers.join(','));

      for (final p in targetProfiles) {
        final row = [
          '"${(p['full_name'] ?? '').toString().replaceAll('"', '""')}"',
          p['role'] ?? '',
          p['id'] ?? '',
        ];

        for (final day in daysList) {
          final targetDateStr = DateFormat('yyyy-MM-dd').format(day);
          final dayPunches = rangeAttendance.where((a) => a['user_id'] == p['id'] && a['date'] == targetDateStr).toList();
          
          if (dayPunches.isEmpty) {
            row.add('A'); // Absent
          } else {
            if (_activeTab == 'mess') {
              final meals = dayPunches.map((a) => a['meal_type']?.toString() ?? 'Present').join(';');
              row.add('"$meals"');
            } else {
              row.add('P'); // Present
            }
          }
        }
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = '${_activeTab}_attendance_$dateLabel.csv';
      final csvContent = buffer.toString();

      if (kIsWeb) {
        downloadCsvFile(csvContent, filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(csvContent);
        await Share.shareXFiles([XFile(file.path)], text: '${_activeTab.toUpperCase()} Attendance Export');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Monthly attendance exported to $filename'),
          backgroundColor: Colors.greenAccent.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export comprehensive log: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatsHeader(List<dynamic> filtered, bool isDark) {
     int marked = filtered.where((p) => (p['_attendance'] as List).isNotEmpty).length;
     int total = filtered.length;
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
       child: Row(children: [
         _miniStat('TOTAL', '$total', isDark),
         const SizedBox(width: 12),
         _miniStat('MARKED', '$marked', isDark, c: Colors.greenAccent),
         const SizedBox(width: 12),
         _miniStat('PENDING', '${total - marked}', isDark, c: Colors.redAccent),
       ]),
     );
  }

  Widget _miniStat(String l, String v, bool isDark, {Color? c}) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.02):Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05))), child: Column(children: [Text(v, style: GoogleFonts.outfit(color: c ?? (isDark?Colors.white:Colors.black), fontSize: 18, fontWeight: FontWeight.w900)), Text(l, style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1))])));
  }

  Widget _buildTabSwitcher(bool isDark) {
    final tabs = ['MESS', 'GATE', 'NIGHT', 'STAFF'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: tabs.map((t) => Expanded(child: GestureDetector(onTap: () { setState(() => _activeTab = t.toLowerCase()); _loadAttendanceData(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _activeTab == t.toLowerCase() ? Colors.indigoAccent : Colors.transparent, width: 3))), child: Text(t, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: _activeTab == t.toLowerCase() ? Colors.indigoAccent : (isDark?Colors.white24:Colors.black26), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)))))).toList()),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: 'SEARCH_PERSONNEL...', hintStyle: TextStyle(color: isDark?Colors.white10:Colors.black12, fontWeight: FontWeight.bold), prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigoAccent, size: 20), filled: true, fillColor: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildPersonnelCard(dynamic p, bool isDark) {
    final attendance = p['_attendance'] as List;
    final textColor = isDark ? Colors.white : Colors.black;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(
          children: [
            Row(children: [
               CircleAvatar(radius: 20, backgroundColor: Colors.indigoAccent.withOpacity(0.1), child: Text(p['full_name']?[0] ?? 'U', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold))),
               const SizedBox(width: 16),
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(p['full_name']?.toUpperCase() ?? 'USER', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                 Text('ID: ${p['id'].toString().substring(0,8).toUpperCase()}', style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
               ])),
            ]),
            const SizedBox(height: 20),
            if (_activeTab == 'mess') _buildMessAttendancePunches(p['id'], attendance, isDark)
            else _buildSimpleAttendanceToggle(p['id'], attendance.isNotEmpty, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessAttendancePunches(String pid, List attendance, bool isDark) {
    final meals = ['Breakfast', 'Lunch', 'Tea', 'Dinner'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: meals.map((m) {
        final bool active = attendance.any((a) => a['meal_type'] == m);
        return GestureDetector(
          onTap: active ? null : () => _markAttendance(pid, 'mess', mealType: m),
          child: Column(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: active ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04)), shape: BoxShape.circle, border: Border.all(color: active ? Colors.indigoAccent : (isDark?Colors.white12:Colors.black12))), child: Center(child: active ? const Icon(Icons.check, color: Colors.white, size: 20) : Text(m[0], style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontWeight: FontWeight.w900)))),
            const SizedBox(height: 8),
            Text(m.toUpperCase(), style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 6, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildSimpleAttendanceToggle(String pid, bool isPresent, bool isDark) {
    return SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: isPresent ? null : () => _markAttendance(pid, _activeTab == 'staff' ? 'staff' : _activeTab), style: ElevatedButton.styleFrom(backgroundColor: isPresent?Colors.greenAccent.withOpacity(0.1):Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isPresent ? 'LOGGED' : 'MARK PRESENT', style: GoogleFonts.outfit(color: isPresent ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5))));
  }

  void _issueCard(bool isDark) async {
     // 🧠 FIXED: Fetch ALL potential students (hostel + mess) for the issuance modal
     final res = await _client.from('profiles').select().inFilter('role', ['hostel_student', 'mess_student']).order('full_name');
     if (mounted) {
       showModalBottomSheet(
         context: context, 
         isScrollControlled: true, 
         backgroundColor: Colors.transparent, 
         builder: (ctx) => _IssueMessCardModal(students: (res as List).map((e) => Map<String, dynamic>.from(e)).toList(), isDark: isDark)
       ).then((_) => _loadAttendanceData());
     }
  }
}

class _IssueMessCardModal extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final bool isDark;
  const _IssueMessCardModal({required this.students, required this.isDark});
  @override State<_IssueMessCardModal> createState() => _IssueMessCardModalState();
}

class _IssueMessCardModalState extends State<_IssueMessCardModal> {
  String? _sid;
  String _type = 'Full Month';
  List<String> _meals = ['B','L','T','D'];
  DateTime _exp = DateTime.now().add(const Duration(days: 30));

  @override Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      padding: EdgeInsets.fromLTRB(32, 40, 32, MediaQuery.of(context).viewInsets.bottom + 40),
      // height: MediaQuery.of(context).size.height * 0.85, // Avoid fixed height
      decoration: BoxDecoration(color: isDark?const Color(0xFF16181A):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            _label('PROTOCOL', 'COMPLEX MESS CARD PROTOCOL'),
            const SizedBox(height: 32),
            _label('ACTION', 'SELECT STUDENT'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16), 
              decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(16)), 
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sid, isExpanded: true, dropdownColor: isDark?const Color(0xFF16181A):Colors.white,
                  hint: Text('SEARCH_DATABASE...', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)), 
                  items: widget.students.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['full_name']?.toString().toUpperCase() ?? 'User', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(), 
                  onChanged: (v) => setState(() => _sid = v)
                ),
              ),
            ),
            const SizedBox(height: 24),
            _label('ACTION', 'CONTRACT TYPE'),
            const SizedBox(height: 12),
            Row(
              children: ['Half Month', 'Full Month', 'Quarterly'].map((t) {
                final isSel = _type == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = t;
                        if (t == 'Half Month') _exp = DateTime.now().add(const Duration(days: 15));
                        else if (t == 'Full Month') _exp = DateTime.now().add(const Duration(days: 30));
                        else if (t == 'Quarterly') _exp = DateTime.now().add(const Duration(days: 90));
                      });
                    }, 
                    child: Container(
                      margin: const EdgeInsets.only(right: 8), 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      decoration: BoxDecoration(
                        color: isSel ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.02):Colors.black.withOpacity(0.02)), 
                        borderRadius: BorderRadius.circular(15), 
                        border: Border.all(color: isSel ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05)))
                      ), 
                      alignment: Alignment.center, 
                      child: Text(t.toUpperCase(), style: TextStyle(color: isSel ? Colors.white : (isDark?Colors.white24:Colors.black26), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))
                    )
                  )
                );
              }).toList()
            ),
            const SizedBox(height: 24),
            _label('ACTION', 'MEAL PERMISSIONS'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: ['B','L','T','D'].map((m) {
                final isSelected = _meals.contains(m);
                final label = m=='B'?'BREAKFAST':m=='L'?'LUNCH':m=='T'?'TEA':'DINNER';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_meals.contains(m)) _meals.remove(m);
                      else _meals.add(m);
                    });
                  }, 
                  child: Column(
                    children: [
                      Container(
                        width: 55, height: 55, 
                        decoration: BoxDecoration(color: isSelected ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04)), shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05)))), 
                        alignment: Alignment.center, 
                        child: Text(m, style: TextStyle(color: isSelected?Colors.white:(isDark?Colors.white24:Colors.black26), fontWeight: FontWeight.w900, fontSize: 18))
                      ),
                      const SizedBox(height: 8),
                      Text(label, style: TextStyle(color: isDark?Colors.white10:Colors.black12, fontSize: 6, fontWeight: FontWeight.w900))
                    ],
                  )
                );
              }).toList()
            ),
            const SizedBox(height: 24),
            _label('ACTION', 'TERMINATION DATE'),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero, 
              title: Text(DateFormat('dd MMMM yyyy').format(_exp), style: TextStyle(color: isDark?Colors.white:Colors.black, fontWeight: FontWeight.w900, fontSize: 14)), 
              trailing: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), 
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _exp, firstDate: DateTime.now(), lastDate: DateTime(2026));
                if (d!=null) setState(() => _exp = d);
              }
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 65, 
              child: ElevatedButton(
                onPressed: _sid == null ? null : () async {
                  final success = await DatabaseService().issueMessCardComplex(userId: _sid!, type: _type, meals: _meals.join(''), expiry: _exp);
                  if (mounted) {
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MESS_CARD_INITIALIZED_SUCCESSFULLY'), backgroundColor: Colors.greenAccent));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERROR_DURING_INITIALIZATION'), backgroundColor: Colors.redAccent));
                    }
                  }
                }, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), 
                child: Text('AUTHORIZE & DEPLOY CARD', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2))
              )
            ),
          ]
        ),
      )
    );
  }

  Widget _label(String prefix, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4), 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(prefix, style: TextStyle(color: Colors.indigoAccent, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 2)), 
        Text(t, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5))
      ]
    )
  );
}
