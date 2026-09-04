import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import '../../models/hostel.dart';
import '../student/room_detail_screen.dart';
import 'admin_floor_visualizer_screen.dart';
import '../employee/staff_dossier_screen.dart';
import 'admin_edit_room_screen.dart'; // 🧬 Structural Editor Import

class AdminRoomIntelligenceScreen extends StatefulWidget {
  final String blockName; 
  const AdminRoomIntelligenceScreen({super.key, required this.blockName});

  @override
  State<AdminRoomIntelligenceScreen> createState() => _AdminRoomIntelligenceScreenState();
}

class _AdminRoomIntelligenceScreenState extends State<AdminRoomIntelligenceScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _enrollments = [];
  List<dynamic> _allRooms = [];
  List<dynamic> _feePackages = [];
  int? _selectedFloor;

  int _cleared = 0;
  int _pending = 0;
  double _totalDues = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final roomsRes = await _client.from('hostel_rooms').select().eq('building_name', widget.blockName).order('floor').order('room_number');
      final roomIds = (roomsRes as List).map((r) => r['id'].toString()).toSet();
      
      final enrollRes = await _client.from('hostel_enrollments').select('*, profiles(*), hostel_rooms(*)');
      List<dynamic> activeEnrollments = [];
      if (enrollRes is List && enrollRes.isNotEmpty) {
         activeEnrollments = (enrollRes as List).where((e) => roomIds.contains(e['room_id']?.toString())).toList();
      }
      
      double dues = 0;
      int clearedCount = 0;
      int pendingCount = 0;

      for (var e in activeEnrollments) {
        final double total = double.tryParse(e['total_price']?.toString() ?? '0') ?? 0;
        final double paid = double.tryParse(e['paid_amount']?.toString() ?? '0') ?? 0;
        final double due = (total - paid).clamp(0, double.infinity);
        e['_computed_due'] = due;
        if (due <= 0) clearedCount++;
        else { pendingCount++; dues += due; }
      }

      final pkgRes = await _client.from('fee_structure').select().eq('category', 'Hostel');
      
      if (mounted) {
        setState(() {
          _allRooms = roomsRes;
          _enrollments = activeEnrollments;
          _feePackages = pkgRes;
          _cleared = clearedCount;
          _pending = pendingCount;
          _totalDues = dues;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark?const Color(0xFF08090A):Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final floors = _allRooms.map((r) => int.tryParse(r['floor']?.toString() ?? '0') ?? 0).toSet().toList()..sort();
    final List<dynamic> filteredRooms = _allRooms.where((r) => _selectedFloor == null || (int.tryParse(r['floor']?.toString() ?? '0') ?? 0) == _selectedFloor).toList();
    final groupedFilteredRooms = groupBy(filteredRooms, (dynamic r) => int.tryParse(r['floor']?.toString() ?? '0') ?? 0);
    final sortedKeys = groupedFilteredRooms.keys.toList()..sort();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('BUILDING ROOMS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.add_business_rounded, color: Colors.indigoAccent), onPressed: () => _showAddRoomModal(isDark)),
          IconButton(icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.indigoAccent), onPressed: () => _showAssignStudentModal(isDark)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Column(
            children: [
              _buildFloorSelector(floors, isDark),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildOverviewSummary(isDark),
                      const SizedBox(height: 32),
                      _buildOperationalActions(isDark),
                      const SizedBox(height: 32),
                      ...sortedKeys.map((floor) {
                         final floorRooms = groupedFilteredRooms[floor]!;
                         return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Padding(
                               padding: const EdgeInsets.only(bottom: 16, top: 8),
                               child: Text('LEVEL $floor STRUCTURAL GRID', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                             ),
                             ...floorRooms.map((r) {
                                final roommates = _enrollments.where((e) => e['room_id']?.toString() == r['id']?.toString()).toList();
                                return _buildConsolidatedRoomCard(r, roommates, isDark);
                             }).toList(),
                             const SizedBox(height: 24),
                           ],
                         );
                      }).toList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildFloorSelector(List<int> floors, bool isDark) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: floors.length + 1,
        itemBuilder: (context, i) {
          final sFloor = i == 0 ? null : floors[i-1];
          final bool sel = _selectedFloor == sFloor;
          return GestureDetector(
            onTap: () => setState(() => _selectedFloor = sFloor),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(15)),
              alignment: Alignment.center,
              child: Text(i == 0 ? 'ALL FLOORS' : 'FLOOR $sFloor', style: GoogleFonts.outfit(color: sel?Colors.white:(isDark?Colors.white24:Colors.black26), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewSummary(bool isDark) {
     return Container(
       padding: const EdgeInsets.all(32),
       decoration: BoxDecoration(color: isDark?const Color(0xFF16181A):Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark?0.3:0.05), blurRadius: 20, offset: const Offset(0,10))]),
       child: Column(children: [
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.blockName.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)), Text('BUILDING DEPLOYMENT INTEL', style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2))]),
           const Icon(Icons.dns_rounded, color: Colors.indigoAccent, size: 28),
         ]),
         const SizedBox(height: 32),
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statItem('PENDING_DUE', '₹${_totalDues.toInt()}', Colors.redAccent, isDark),
            _statItem('CLEARANCE', '$_cleared', Colors.greenAccent, isDark),
            _statItem('DEFICIT', '$_pending', Colors.orangeAccent, isDark),
         ]),
       ]),
     );
  }

  Widget _statItem(String l, String v, Color c, bool isDark) {
    return Column(children: [Text(v, style: GoogleFonts.outfit(color: c, fontSize: 20, fontWeight: FontWeight.w900)), Text(l, style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.5))]);
  }

  Widget _buildOperationalActions(bool isDark) {
    return Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFloorVisualizerScreen(blockName: widget.blockName))),
        child: _actionBtn('VISUAL MAP', Icons.map_rounded, Colors.indigoAccent, isDark),
      )),
      const SizedBox(width: 12),
      Expanded(child: _actionBtn('BUILDING LIST', Icons.list_alt_rounded, isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), isDark)),
    ]);
  }

  Widget _actionBtn(String label, IconData icon, Color bg, bool isDark) {
    return Container(height: 55, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: bg == Colors.indigoAccent ? Colors.white : Colors.indigoAccent, size: 18), const SizedBox(width: 12), Text(label, style: GoogleFonts.outfit(color: bg == Colors.indigoAccent ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))]));
  }

  Widget _buildConsolidatedRoomCard(dynamic r, List<dynamic> roommates, bool isDark) {
    final bool isOccupied = roommates.isNotEmpty;
    final int capacity = int.tryParse(r['capacity']?.toString() ?? '1') ?? 1;
    final int vacantSlots = (capacity - roommates.length).clamp(0, capacity);

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181A) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(color: (isOccupied ? Colors.indigoAccent : Colors.orangeAccent).withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(child: Text(r['room_number'] ?? '?', style: GoogleFonts.outfit(color: isOccupied ? Colors.indigoAccent : Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 14))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ROOM ${r['room_number']} // ${r['room_type']?.toUpperCase() ?? 'UNIT'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                    Text('CAPACITY: $capacity • $vacantSlots SLOTS VACANT', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
                  ])),
                  _statusPill(isOccupied ? 'OCCUPIED' : 'VACANT', isOccupied ? Colors.indigoAccent : Colors.orangeAccent, isDark),
                ],
              ),
            ),
            if (isOccupied) ...[
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roommates.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 24, endIndent: 24),
                itemBuilder: (context, idx) {
                  final e = roommates[idx];
                  final profile = e['profiles'] as Map<String, dynamic>?;
                  final due = e['_computed_due'] ?? 0.0;
                  final bool isCleared = due <= 0;

                  return InkWell(
                    onTap: () => _showStudentManager(e, isDark),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                            backgroundImage: profile?['avatar_url'] != null && profile!['avatar_url'].toString().startsWith('http') ? NetworkImage(profile['avatar_url']) : null,
                            child: (profile?['avatar_url'] == null || !profile!['avatar_url'].toString().startsWith('http')) 
                               ? const Icon(Icons.person_outline_rounded, color: Colors.indigoAccent, size: 18) 
                               : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                             Text(profile?['full_name'] ?? 'TERMINAL_USER', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                             if (due > 0) Text('REMAINING DUES: ₹${due.toInt()}', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ])),
                          _pkgTag(isCleared ? 'PAID' : 'DUE', isCleared ? Colors.greenAccent : Colors.redAccent, isDark),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                   Expanded(child: _miniActionBtn('EDIT UNIT', Icons.edit_rounded, isDark, () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditRoomScreen(room: HostelRoom.fromJson(r))));
                      if (res == true) _fetchData();
                   })),
                   const SizedBox(width: 4),
                   if (vacantSlots > 0) 
                     Expanded(child: _miniActionBtn('ASSIGN', Icons.person_add_rounded, isDark, () => _showAssignStudentModal(isDark, targetedRoom: r))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentManager(dynamic e, bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
           CircleAvatar(radius: 30, backgroundImage: e['profiles']?['avatar_url'] != null ? NetworkImage(e['profiles']['avatar_url']) : null),
           const SizedBox(width: 16),
           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['profiles']?['full_name']?.toUpperCase() ?? 'STUDENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
              Text('RESIDENT_TERMINAL_ID: ${e['id'].toString().substring(0,8)}', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
           ])),
        ]),
        const SizedBox(height: 32),
        Row(children: [
           Expanded(child: _miniAction('PROFILE', Icons.person_outline_rounded, isDark, () => _showStudentProfile(e, isDark))),
           const SizedBox(width: 12),
           Expanded(child: _miniAction('LOG PAY', Icons.payments_outlined, isDark, () => _showLogTransaction(e, isDark))),
           const SizedBox(width: 12),
           Expanded(child: _miniAction('PHOTO', Icons.add_a_photo_outlined, isDark, () => _showPhotoUpdate(e, isDark))),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('DISMISS'))),
      ]),
    ));
  }

  Widget _miniActionBtn(String label, IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 14, color: Colors.indigoAccent), const SizedBox(width: 6), Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.indigoAccent))]),
      ),
    );
  }

  Widget _miniAction(String label, IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.indigoAccent, size: 14), const SizedBox(width: 8), Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 10))])),
    );
  }

  Widget _statusPill(String l, Color c, bool isDark) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)));
  }

  Widget _pkgTag(String l, Color c, bool isDark) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text(l.toUpperCase(), style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)));

  void _showStudentProfile(dynamic e, bool isDark) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDossierScreen(profile: e['profiles'])));
  }

  void _showLogTransaction(dynamic e, bool isDark) {
    final amtCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => Container(padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(c).viewInsets.bottom + 32), decoration: BoxDecoration(color: isDark?const Color(0xFF16181A):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('LOG SYSTEM PAYMENT', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 16),
       TextField(controller: amtCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: 'Amount Received', prefixText: '₹ ', filled: true, fillColor: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)), keyboardType: TextInputType.number),
       const SizedBox(height: 24),
       SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () async {
            final double amt = double.tryParse(amtCtrl.text) ?? 0;
            if (amt <= 0) return;
            final double newPaid = (double.tryParse(e['paid_amount'].toString()) ?? 0) + amt;
            await _client.from('hostel_enrollments').update({'paid_amount': newPaid}).eq('id', e['id']);
            Navigator.pop(c); _fetchData();
       }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('CONFIRM TRANSACTION'))),
    ])));
  }

  void _showPhotoUpdate(dynamic e, bool isDark) {
    final urlCtrl = TextEditingController(text: e['profiles']?['avatar_url']);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => Container(padding: EdgeInsets.fromLTRB(32, 24, 32, MediaQuery.of(c).viewInsets.bottom + 32), decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('UPDATE INTEL PHOTO', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 24),
       TextField(controller: urlCtrl, decoration: InputDecoration(labelText: 'Secure Image URL', labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26), filled: true, fillColor: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
       const SizedBox(height: 32),
       SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () async {
            await _client.from('profiles').update({'avatar_url': urlCtrl.text.trim()}).eq('id', e['profiles']['id']);
            Navigator.pop(c); _fetchData();
       }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: const Text('UPDATE BIOMETRICS'))),
    ])));
  }

  void _showAddRoomModal(bool isDark) {
    final numCtrl = TextEditingController();
    final flrCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '1');
    String? selType;
    if (_feePackages.isNotEmpty) selType = _feePackages[0]['service_name'];
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (c, setS) => Container(padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(ctx).viewInsets.bottom + 32), decoration: BoxDecoration(color: isDark?const Color(0xFF16181A):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))), child: Column(mainAxisSize: MainAxisSize.min, children: [
       Text('APPEND NEW UNIT', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 24),
       TextField(controller: numCtrl, style: const TextStyle(fontSize: 14), decoration: InputDecoration(labelText: 'Room Identifier')),
       TextField(controller: flrCtrl, decoration: InputDecoration(labelText: 'Floor Assignment (0-6)'), keyboardType: TextInputType.number),
       TextField(controller: capCtrl, decoration: InputDecoration(labelText: 'Unit Capacity'), keyboardType: TextInputType.number),
       const SizedBox(height: 16),
        if (_feePackages.isNotEmpty) DropdownButton<String>(value: _feePackages.any((t) => t['service_name'].toString() == selType) ? selType : _feePackages.first['service_name'].toString(), isExpanded: true, items: _feePackages.map((t) => DropdownMenuItem(value: t['service_name'].toString(), child: Text(t['service_name'].toString()))).toList(), onChanged: (v) => setS(() => selType = v!)),
       const SizedBox(height: 32),
       SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () async {
          if (selType == null) return;
          final double basePrice = double.tryParse(_feePackages.firstWhere((p) => p['service_name'] == selType)['price']?.toString() ?? '0') ?? 0;
          await _client.from('hostel_rooms').insert({'room_number': numCtrl.text, 'building_name': widget.blockName, 'floor': int.tryParse(flrCtrl.text) ?? 0, 'capacity': int.tryParse(capCtrl.text) ?? 1, 'room_type': selType, 'base_price': basePrice, 'is_active': true});
          Navigator.pop(ctx); _fetchData();
       }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: const Text('DEPLOY UNIT')))
    ]))));
  }

  void _showAssignStudentModal(bool isDark, {dynamic targetedRoom}) async {
    setState(() => _isLoading = true);
    final students = await _client.from('profiles').select().eq('role', 'hostel_student');
    final enrollRes = await _client.from('hostel_enrollments').select('*, hostel_rooms(*)');
    final vacantRooms = _allRooms.where((r) {
       final roomies = _enrollments.where((e) => e['room_id']?.toString() == r['id']?.toString()).toList();
       return roomies.length < (int.tryParse(r['capacity']?.toString() ?? '1') ?? 1);
    }).toList();
    setState(() => _isLoading = false);
    if (!mounted) return;
    String? selStudent; String? selRoom = targetedRoom?['id']?.toString(); dynamic currentEnrollment;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (c, setS) => Container(padding: EdgeInsets.fromLTRB(32, 24, 32, MediaQuery.of(ctx).viewInsets.bottom + 32), decoration: BoxDecoration(color: isDark?const Color(0xFF16181A):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('RESIDENT DEPLOYMENT', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 24),
       DropdownButton<String>(value: selStudent, isExpanded: true, hint: const Text('Select Student'), items: students.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['full_name'] ?? 'Unknown'))).toList(), onChanged: (v) {
          final enroll = enrollRes.firstWhereOrNull((e) => e['user_id'] == v);
          setS(() { selStudent = v; currentEnrollment = enroll; });
       }),
       const SizedBox(height: 24),
       DropdownButton<String>(value: (targetedRoom != null && targetedRoom['id'].toString() == selRoom) || vacantRooms.any((r) => r['id'].toString() == selRoom) ? selRoom : null, isExpanded: true, hint: const Text('Select Target Room'), items: (targetedRoom != null ? [targetedRoom] : vacantRooms).map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text('ROOM ${r['room_number']} (${r['room_type']})'))).toList(), onChanged: (v) => setS(() => selRoom = v)),
       const SizedBox(height: 32),
       SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () async {
          if (selStudent == null || selRoom == null) return;
          final room = _allRooms.firstWhere((r) => r['id'].toString() == selRoom);
          if (currentEnrollment != null) {
             await _client.from('hostel_enrollments').update({'room_id': selRoom, 'building_name': widget.blockName}).eq('id', currentEnrollment['id']);
          } else {
             await _client.from('hostel_enrollments').insert({'user_id': selStudent, 'room_id': selRoom, 'building_name': widget.blockName, 'total_price': room['base_price'] ?? 0, 'paid_amount': 0, 'status': 'Approved', 'payment_status': 'Approved'});
          }
          Navigator.pop(ctx); _fetchData();
       }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: Text(currentEnrollment != null ? 'TRANSFER RESIDENT' : 'CONFIRM DEPLOYMENT'))),
    ]))));
  }

  void _showRoomDetails(dynamic r, dynamic enroll, bool isDark) async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditRoomScreen(room: HostelRoom.fromJson(r))));
    if (res == true) _fetchData();
  }

  Widget _infoTile(String l, String v, Color c, bool isDark) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)), Text(v, style: GoogleFonts.outfit(color: c, fontSize: 13, fontWeight: FontWeight.bold))]));
  }
}
