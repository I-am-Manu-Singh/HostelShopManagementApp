import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminRoomInspectionScreen extends StatefulWidget {
  const AdminRoomInspectionScreen({super.key});

  @override
  State<AdminRoomInspectionScreen> createState() => _AdminRoomInspectionScreenState();
}

class _AdminRoomInspectionScreenState extends State<AdminRoomInspectionScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rooms = [];
  List<dynamic> _records = [];
  dynamic _selectedRoom;
  
  final _descCtrl = TextEditingController();
  final _resCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String _activeStatus = 'OK';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final rRes = await _client.from('hostel_rooms').select();
      final mRes = await _client.from('room_maintenance_records').select('*, hostel_rooms(*)').order('inspection_date', ascending: false);
      if (mounted) setState(() { _rooms = rRes; _records = mRes; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _logInspection() async {
    if (_selectedRoom == null) return;
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      final cost = double.tryParse(_costCtrl.text) ?? 0;
      
      // 1. Create Maintenance Record
      final res = await _client.from('room_maintenance_records').insert({
        'room_id': _selectedRoom['id'],
        'inspector_id': user?.id,
        'status': _activeStatus,
        'issue_description': _descCtrl.text,
        'resolution_details': _resCtrl.text,
        'actual_cost': cost,
      }).select().single();

      // 2. If cost > 0, log in Day Book automatically
      if (cost > 0) {
        await _client.from('day_book_entries').insert({
          'entry_type': 'Expense',
          'amount': cost,
          'category': 'Room Maintenance',
          'remark': 'Auto-logged from Inspection: ${_selectedRoom['room_number']}',
          'user_id': user?.id,
          'related_room_id': _selectedRoom['id'],
          'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
      }

      _descCtrl.clear(); _resCtrl.clear(); _costCtrl.clear();
      _fetchInitialData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('INSPECTION AUDIT COMMITTED'), backgroundColor: Colors.indigoAccent));
    } catch (_) {} finally { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text('ROOM INSPECTION & AUDIT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInspectionLauncher(isDark),
                const SizedBox(height: 40),
                _sectionHeader('HISTORICAL AUDIT LOG'),
                const SizedBox(height: 16),
                if (_records.isEmpty) _emptyState(isDark)
                else ..._records.map((r) => FadeInUp(child: _buildRecordTile(r, isDark))).toList(),
              ],
            ),
          ),
    );
  }

  Widget _buildInspectionLauncher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEW INSPECTION PROTOCOL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 24),
        _roomDropdown(isDark),
        const SizedBox(height: 16),
        _statusPicker(isDark),
        const SizedBox(height: 16),
        _buildInputField('ISSUE DESCRIPTION', _descCtrl, isDark, Icons.report_problem_outlined),
        const SizedBox(height: 16),
        _buildInputField('RESOLUTION DETAILS (IF ANY)', _resCtrl, isDark, Icons.build_circle_outlined),
        const SizedBox(height: 16),
        _buildInputField('REPAIR COST (₹)', _costCtrl, isDark, Icons.payments_outlined, isNumeric: true),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _logInspection,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('COMMIT INSPECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _roomDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(child: DropdownButton<dynamic>(
        hint: const Text('SELECT TARGET ROOM', style: TextStyle(fontSize: 12)),
        isExpanded: true, value: _selectedRoom, dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        items: _rooms.map((r) => DropdownMenuItem(value: r, child: Text('UNIT ${r['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        onChanged: (v) => setState(() => _selectedRoom = v),
      )),
    );
  }

  Widget _statusPicker(bool isDark) {
    final statuses = ['OK', 'Needs Repair', 'Repairing', 'Resolved'];
    return Row(children: statuses.map((s) {
       bool sel = _activeStatus == s;
       return Expanded(child: GestureDetector(onTap: () => setState(() => _activeStatus = s), child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(s.toUpperCase(), style: TextStyle(color: sel ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 7, fontWeight: FontWeight.w900)))));
    }).toList());
  }

  Widget _buildRecordTile(dynamic r, bool isDark) {
    final statusColor = r['status'] == 'OK' ? Colors.greenAccent : (r['status'] == 'Resolved' ? Colors.blueAccent : Colors.orangeAccent);
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('UNIT ${r['hostel_rooms']?['room_number'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(r['status'], style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold))),
         ]),
         const SizedBox(height: 8),
         Text(r['issue_description'] ?? 'Periodic check-up', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11)),
         const SizedBox(height: 12),
         Row(children: [
            Icon(Icons.calendar_month_rounded, size: 12, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(width: 4),
            Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(r['inspection_date'])), style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 9)),
            const Spacer(),
            if ((r['actual_cost'] ?? 0) > 0) Text('₹${r['actual_cost']}', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
         ]),
      ]),
    );
  }

  Widget _buildInputField(String l, TextEditingController c, bool isDark, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: c, keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
      decoration: InputDecoration(
        labelText: l, labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 16),
        filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
      ),
    );
  }

  Widget _sectionHeader(String label) => Text(label, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  Widget _emptyState(bool isDark) => Center(child: Text('NO INSPECTION HISTORY DETECTED', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 9, fontWeight: FontWeight.bold)));
}
