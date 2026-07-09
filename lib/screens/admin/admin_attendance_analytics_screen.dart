import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAttendanceAnalyticsScreen extends StatefulWidget {
  const AdminAttendanceAnalyticsScreen({super.key});

  @override
  State<AdminAttendanceAnalyticsScreen> createState() => _AdminAttendanceAnalyticsScreenState();
}

class _AdminAttendanceAnalyticsScreenState extends State<AdminAttendanceAnalyticsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _profiles = [];
  Map<String, List<String>> _marked = {'mess': [], 'gate': [], 'night': []};
  String _selectedType = 'mess';
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final profiles = await _client.from('profiles').select().inFilter('role', ['hostel_student', 'mess_student', 'staff']);
      final attendance = await _client.from('attendance').select('user_id, attendance_type').eq('date', date);
      
      final Map<String, List<String>> markedMap = {'mess': [], 'gate': [], 'night': [], 'staff': []};
      for (var a in (attendance as List)) {
        final t = (a['attendance_type']?.toString().toLowerCase() ?? 'gate');
        if (!markedMap.containsKey(t)) markedMap[t] = [];
        markedMap[t]?.add(a['user_id'].toString());
      }

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(profiles);
          _marked = markedMap;
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
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final List<Map<String, dynamic>> filtered = _profiles.where((p) {
      bool roleMatch = false;
      if (_selectedType == 'mess') roleMatch = p['role'] == 'mess_student' || p['role'] == 'hostel_student';
      else if (_selectedType == 'gate' || _selectedType == 'night') roleMatch = p['role'] == 'hostel_student';
      else if (_selectedType == 'staff') roleMatch = p['role'] == 'staff';

      final searchMatch = p['full_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? true;
      return roleMatch && searchMatch;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ATTENDANCE ARCHIVE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), onPressed: _pickDate),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Column(
            children: [
              _buildTypeSelector(isDark),
              _buildDateBadge(isDark),
              _buildStatsBar(filtered, isDark),
              _buildSearchBar(isDark),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final isMarked = _marked[_selectedType]?.contains(p['id']) ?? false;
                    return _buildUserTile(p, isMarked, isDark);
                  },
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
      _loadData();
    }
  }

  Widget _buildDateBadge(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text('DATE: ${DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase()}', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
          if (!DateFormat('yyyy-MM-dd').format(_selectedDate).contains(DateFormat('yyyy-MM-dd').format(DateTime.now()))) ...[
             const SizedBox(width: 8),
             GestureDetector(onTap: () { setState(() => _selectedDate = DateTime.now()); _loadData(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Text('RESET', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900)))),
          ]
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    final types = ['mess', 'gate', 'night', 'staff'];
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: types.length,
        itemBuilder: (context, i) {
          final t = types[i];
          final isSel = _selectedType == t;
          return GestureDetector(
            onTap: () => setState(() => _selectedType = t),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: isSel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(15)),
              alignment: Alignment.center,
              child: Text(t.toUpperCase(), style: GoogleFonts.outfit(color: isSel ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsBar(List<Map<String, dynamic>> filtered, bool isDark) {
    int total = filtered.length;
    int marked = _marked[_selectedType]?.where((id) => filtered.any((p) => p['id'] == id)).length ?? 0;
    int percentage = total > 0 ? (marked * 100 ~/ total) : 0;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.02):Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('CAPACITY', total.toString(), isDark),
          _statItem('LOGGED', marked.toString(), isDark, color: Colors.greenAccent),
          _statItem('PENDING', (total - marked).toString(), isDark, color: Colors.redAccent),
          _statItem('PRECISION', '$percentage%', isDark, color: Colors.indigoAccent),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, bool isDark, {Color? color}) {
    return Column(children: [Text(val, style: GoogleFonts.outfit(color: color ?? (isDark ? Colors.white : Colors.black), fontSize: 24, fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 2))]);
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(18), border: Border.all(color: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05))),
        child: Row(children: [const Icon(Icons.search, color: Colors.indigoAccent, size: 20), const SizedBox(width: 16), Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: 'SEARCH_PERSONNEL', hintStyle: TextStyle(color: isDark?Colors.white10:Colors.black12, fontWeight: FontWeight.bold), border: InputBorder.none)))]),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> p, bool isMarked, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(22), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: Colors.indigoAccent.withOpacity(0.1), backgroundImage: p['avatar_url']!=null ? NetworkImage(p['avatar_url']): null, child: p['avatar_url']==null?Text(p['full_name']?[0] ?? 'S', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)):null),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['full_name']?.toUpperCase() ?? 'PERSONNEL', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)), Text(p['role']?.toString().toUpperCase() ?? 'NONE', style: TextStyle(color: isDark ? Colors.white24 : Colors.black.withOpacity(0.24), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: isMarked ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(isMarked?Icons.verified_rounded:Icons.pending_actions_rounded, color: isMarked?Colors.greenAccent:Colors.redAccent, size: 12), const SizedBox(width: 8), Text(isMarked ? 'LOGGED' : 'PENDING', style: TextStyle(color: isMarked ? Colors.greenAccent : Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))])),
          ],
        ),
      ),
    );
  }
}
