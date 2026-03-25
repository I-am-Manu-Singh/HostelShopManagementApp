import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminProcurementScreen extends StatefulWidget {
  const AdminProcurementScreen({super.key});

  @override
  State<AdminProcurementScreen> createState() => _AdminProcurementScreenState();
}

class _AdminProcurementScreenState extends State<AdminProcurementScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String _filterStatus = 'ALL';
  String? _filterEmployeeId;
  DateTime? _filterDate;
  
  List<dynamic> _procurements = [];
  List<dynamic> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchStaff();
    await _fetchProcurements();
  }

  Future<void> _fetchStaff() async {
    try {
      final res = await _client.from('profiles').select().inFilter('role', ['staff', 'admin', 'hostel_manager']);
      if (mounted) setState(() => _staffList = res);
    } catch (_) {}
  }

  Future<void> _fetchProcurements() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 🧠 FIXED: Join on requester_id. 
      var query = _client.from('procurements').select('*, profiles:requester_id(*)');
      
      if (_filterStatus != 'ALL') {
        query = query.eq('status', _filterStatus.toLowerCase().capitalize());
      }
      if (_filterEmployeeId != null) {
        query = query.eq('requester_id', _filterEmployeeId!);
      }
      if (_filterDate != null) {
         final dateStr = DateFormat('yyyy-MM-dd').format(_filterDate!);
         query = query.gte('created_at', '${dateStr}T00:00:00').lte('created_at', '${dateStr}T23:59:59');
      }

      final res = await query.order('created_at', ascending: false);
      if (mounted) setState(() { _procurements = res; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _client.from('procurements').update({'status': status}).eq('id', id);
      _fetchProcurements();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('PURCHASE REQUESTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: textColor), onPressed: _fetchProcurements),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRequestModal,
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: Text('NEW REQUEST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Column(
            children: [
              _buildAnalyticsHeader(isDark),
              _buildFilterSection(isDark),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchProcurements,
                  child: _procurements.isEmpty 
                  ? _emptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemCount: _procurements.length,
                      itemBuilder: (context, i) => FadeInUp(
                        delay: Duration(milliseconds: i * 50),
                        child: _buildProcurementCard(_procurements[i], cardColor, borderColor, isDark),
                      ),
                    ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildAnalyticsHeader(bool isDark) {
    int requested = _procurements.where((p) => (p['status']?.toString().toLowerCase() ?? '') == 'requested').length;
    int procured = _procurements.where((p) => (p['status']?.toString().toLowerCase() ?? '') == 'procured').length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(children: [
        _analyticBox('PENDING', '$requested', Colors.orangeAccent, isDark),
        const SizedBox(width: 12),
        _analyticBox('PROCURED', '$procured', Colors.greenAccent, isDark),
        const SizedBox(width: 12),
        _analyticBox('TICKETS', '${_procurements.length}', Colors.indigoAccent, isDark),
      ]),
    );
  }

  Widget _analyticBox(String l, String v, Color c, bool isDark) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.02):Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05))), child: Column(children: [Text(v, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: c)), Text(l, style: TextStyle(color: isDark?Colors.white24:Colors.black.withOpacity(0.24), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))])));
  }

  Widget _buildFilterSection(bool isDark) {
    final statuses = ['ALL', 'REQUESTED', 'PROCURED', 'CANCELLED'];
    return Column(
      children: [
        Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListView.builder( scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 24), itemCount: statuses.length, itemBuilder: (ctx, i) {
            final s = statuses[i];
            final sel = _filterStatus == s;
            return GestureDetector(
              onTap: () => setState(() { _filterStatus = s; _fetchProcurements(); }),
              child: Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: sel?Colors.indigoAccent:(isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(15)), alignment: Alignment.center, child: Text(s, style: GoogleFonts.outfit(color: sel?Colors.white:(isDark?Colors.white24:Colors.black26), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)))
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container( padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)), 
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _filterEmployeeId, dropdownColor: isDark?const Color(0xFF1E293B):Colors.white, hint: Text('STAFF_FILTER', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('ALL_REQUESTERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ..._staffList.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['full_name']?.toString().toUpperCase() ?? 'STAFF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                    ],
                    onChanged: (v) { setState(() => _filterEmployeeId = v); _fetchProcurements(); }
                  ),
                ))),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                     final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2026));
                     if (d != null) { setState(() => _filterDate = d); _fetchProcurements(); }
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _filterDate!=null?Colors.indigoAccent:(isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.calendar_month_rounded, color: _filterDate!=null?Colors.white:Colors.indigoAccent, size: 20))
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcurementCard(dynamic data, Color cardColor, Color borderColor, bool isDark) {
    final profile = data['profiles'];
    final status = data['status']?.toString().toUpperCase() ?? 'REQUESTED';
    final priority = data['priority']?.toString().toUpperCase() ?? 'NORMAL';
    bool isPending = status == 'REQUESTED';
    final textColor = isDark ? Colors.white : Colors.black;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['item_name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(radius: 8, backgroundColor: Colors.indigoAccent.withOpacity(0.1), backgroundImage: profile?['avatar_url']!=null?NetworkImage(profile['avatar_url']):null),
                      const SizedBox(width: 8),
                      Text('By: ${profile?['full_name'] ?? 'Personnel'}', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ],
                  ),
                ]),
              ),
              _priorityBadge(priority),
            ],
          ),
          const SizedBox(height: 20),
          Text(data['description'] ?? 'No operational specifics provided.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('dd MMM yyyy').format(DateTime.parse(data['created_at'])), style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 9, fontWeight: FontWeight.bold)),
              if (isPending) Row(children: [
                _miniActionBtn('DECLINE', Colors.redAccent.withOpacity(0.1), Colors.redAccent, () => _updateStatus(data['id'], 'Cancelled')),
                const SizedBox(width: 8),
                _miniActionBtn('APPROVE', Colors.greenAccent.withOpacity(0.1), Colors.greenAccent, () => _updateStatus(data['id'], 'Procured')),
              ]) else Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: status=='PROCURED'?Colors.greenAccent.withOpacity(0.1):Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: status=='PROCURED'?Colors.greenAccent:Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priorityBadge(String p) {
    Color color = Colors.blue;
    if (p == 'URGENT') color = Colors.orange;
    if (p == 'EMERGENCY') color = Colors.redAccent;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(p, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)));
  }

  Widget _miniActionBtn(String label, Color bg, Color text, VoidCallback onTap) {
    return GestureDetector( onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), child: Text(label, style: GoogleFonts.outfit(color: text, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1))));
  }

  void _showCreateRequestModal() {
     final itemCtrl = TextEditingController();
     final descCtrl = TextEditingController();
     String priority = 'Normal';
     
     showModalBottomSheet(
       context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
       builder: (ctx) => StatefulBuilder(
         builder: (ctx, setModalState) {
           final isDark = Theme.of(context).brightness == Brightness.dark;
           return Container(
             padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(ctx).viewInsets.bottom + 32),
             decoration: BoxDecoration(color: isDark?const Color(0xFF1E293B):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
             child: Column(
               mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('NEW PROCUREMENT REQUEST', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                 const SizedBox(height: 24),
                 _modalField(itemCtrl, 'ITEM_NAME', isDark),
                 const SizedBox(height: 16),
                 _modalField(descCtrl, 'SPECIFICATIONS_&_REASON', isDark, lines: 3),
                 const SizedBox(height: 24),
                 _priorityPicker(priority, (v) => setModalState(() => priority = v), isDark),
                 const SizedBox(height: 40),
                  SizedBox(width: double.infinity, height: 65, child: ElevatedButton(onPressed: () async {
                     try {
                       final user = _client.auth.currentUser;
                       if (user == null) throw 'Authentication Protocol Failure: No Active Session';
                       
                       await _client.from('procurements').insert({
                         'item_name': itemCtrl.text, 
                         'description': descCtrl.text, 
                         'priority': priority, 
                         'requester_id': user.id, 
                         'status': 'Requested'
                       });
                       
                       if (mounted) {
                         Navigator.pop(ctx);
                         _fetchProcurements();
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PROCUREMENT_REQUEST_SUBMITTED'), backgroundColor: Colors.indigoAccent));
                       }
                     } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SUBMISSION_ERROR: $e'), backgroundColor: Colors.redAccent));
                     }
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: Text('SUBMIT_REQUEST', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2))))
               ],
             ),
           );
         }
       )
     );
  }

  Widget _modalField(TextEditingController ctrl, String hint, bool isDark, {int lines = 1}) {
    return TextField(controller: ctrl, maxLines: lines, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 14, fontWeight: FontWeight.bold), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), contentPadding: const EdgeInsets.all(20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)))));
  }

  Widget _priorityPicker(String selected, Function(String) onSelect, bool isDark) {
    final ps = ['Normal', 'Urgent', 'Emergency'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PRIORITY', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const SizedBox(height: 12), Row(children: ps.map((p) => Expanded(child: GestureDetector(onTap: () => onSelect(p), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: selected == p ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(p.toUpperCase(), style: TextStyle(color: selected == p?Colors.white : (isDark?Colors.white24:Colors.black26), fontSize: 8, fontWeight: FontWeight.w900))))))).toList())]);
  }

  Widget _emptyState(bool isDark) {
     return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 48, color: isDark?Colors.white10:Colors.black12), const SizedBox(height: 16), Text('NO PURCHASING LOGS FOUND', style: GoogleFonts.outfit(color: isDark?Colors.white10:Colors.black12, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))]));
  }
}

extension StringExtension on String {
  String capitalize() => this.isNotEmpty ? '${this[0].toUpperCase()}${this.substring(1)}' : '';
}
