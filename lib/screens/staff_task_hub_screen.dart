import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'attendance_screen.dart';

class StaffTaskHubScreen extends StatefulWidget {
  const StaffTaskHubScreen({super.key});

  @override
  State<StaffTaskHubScreen> createState() => _StaffTaskHubScreenState();
}

class _StaffTaskHubScreenState extends State<StaffTaskHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String _myRole = 'staff';
  String? _myId;
  
  // Filters
  String? _filterEmployeeId;
  DateTime? _filterDate;
  List<dynamic> _staffList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAuthAndData();
  }

  Future<void> _loadAuthAndData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _myId = user.id;
    
    final prof = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (mounted) {
      setState(() {
        _myRole = prof?['role']?.toString().toLowerCase() ?? 'staff';
      });
      if (_myRole == 'admin' || _myRole == 'hostel_manager') {
        _fetchStaff();
      }
      await _fetchTasks();
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final res = await _client.from('profiles').select().inFilter('role', ['staff', 'hostel_manager', 'admin', 'warden']);
      if (mounted) setState(() => _staffList = res);
    } catch (_) {}
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
       var query = _client.from('employee_tasks').select('*, assignee:profiles!user_id(full_name, avatar_url)');
       
       if (_myRole == 'staff') {
         query = query.eq('user_id', _myId!);
       } else {
         if (_filterEmployeeId != null) {
           query = query.eq('user_id', _filterEmployeeId!);
         }
       }
       
       if (_filterDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(_filterDate!);
          // Assuming created_at is the logic for "date of task" or if there's a specific task_date column.
          // Since we don't have task_date, we filter by created_at day.
          query = query.gte('created_at', '${dateStr}T00:00:00').lte('created_at', '${dateStr}T23:59:59');
       }
       
       final res = await query.order('created_at', ascending: false);
       if (mounted) {
         setState(() {
           _tasks = res;
           _isLoading = false;
         });
       }
    } catch (e) {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus, {String? proofUrl}) async {
    try {
      final updates = {'status': newStatus, 'updated_at': DateTime.now().toIso8601String()};
      if (proofUrl != null) updates['proof_image_url'] = proofUrl;
      
      await _client.from('employee_tasks').update(updates).eq('id', taskId);
      _fetchTasks();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundAura(isDark),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildAppBar(textColor),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (_myRole == 'admin' || _myRole == 'hostel_manager') _buildFilterSection(isDark),
                    _buildAnalyticsHeader(isDark),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                    indicatorColor: Colors.indigoAccent,
                    indicatorWeight: 4,
                    labelColor: Colors.indigoAccent,
                    unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
                    tabs: const [Tab(text: 'PENDING'), Tab(text: 'ACTIVE'), Tab(text: 'REVIEW'), Tab(text: 'DONE')],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList('Pending', isDark),
                _buildTaskList('In-Progress', isDark),
                _buildTaskList('Review', isDark),
                _buildTaskList('Completed', isDark),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _myRole == 'admin' || _myRole == 'hostel_manager' ? FloatingActionButton.extended(
        onPressed: _showCreateTaskModal,
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: Text('ASSIGN MISSION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
      ) : null,
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _filterEmployeeId,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      hint: Text('FILTER_BY_STAFF', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                      items: [
                        DropdownMenuItem(value: null, child: Text('ALL_EMPLOYEES', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold))),
                        ..._staffList.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['full_name']?.toString().toUpperCase() ?? 'STAFF', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)))),
                      ],
                      onChanged: (v) { setState(() => _filterEmployeeId = v); _fetchTasks(); },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                   final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2026));
                   if (d != null) { setState(() => _filterDate = d); _fetchTasks(); }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _filterDate != null ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(15)),
                  child: Icon(Icons.calendar_today_rounded, color: _filterDate != null ? Colors.white : Colors.indigoAccent, size: 20),
                ),
              ),
              if (_filterDate != null) IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 20), onPressed: () { setState(() => _filterDate = null); _fetchTasks(); }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundAura(bool isDark) {
    return Positioned(top: -100, left: -100, child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container(width: 400, height: 400, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildAppBar(Color textColor) {
    return SliverAppBar(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      title: Text('STAFF_TASK_CORE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 5)),
      leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.indigoAccent, size: 24), onPressed: _fetchTasks),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAnalyticsHeader(bool isDark) {
    final pending = _tasks.where((t) => t['status'] == 'Pending').length;
    final active = _tasks.where((t) => t['status'] == 'In-Progress').length;
    final done = _tasks.where((t) => t['status'] == 'Completed').length;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(children: [
        _statBox('PENDING', '$pending', Colors.orangeAccent, isDark),
        const SizedBox(width: 12),
        _statBox('ACTIVE', '$active', Colors.blueAccent, isDark),
        const SizedBox(width: 12),
        _statBox('SOLVED', '$done', Colors.greenAccent, isDark),
      ]),
    );
  }

  Widget _statBox(String label, String val, Color color, bool isDark) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), child: Column(children: [Text(val, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: color)), Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black.withOpacity(0.24), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))])));
  }

  Widget _buildTaskList(String status, bool isDark) {
    final filtered = _tasks.where((t) => t['status'] == status).toList();
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    if (filtered.isEmpty) return _emptyState(status, isDark);
    return ListView.builder(padding: const EdgeInsets.all(24), itemCount: filtered.length, itemBuilder: (context, i) => _buildTaskCard(filtered[i], isDark));
  }

  Widget _buildTaskCard(dynamic t, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final priority = t['priority'] ?? 'Medium';
    final pColor = priority == 'Urgent' ? Colors.redAccent : (priority == 'High' ? Colors.orangeAccent : Colors.blueAccent);
    final type = t['type'] ?? 'GENERAL';

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: pColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(priority.toUpperCase(), style: TextStyle(color: pColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))),
              Text(type.toUpperCase(), style: TextStyle(color: isDark ? Colors.white24 : Colors.black.withOpacity(0.24), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ]),
            const SizedBox(height: 20),
            Text(t['title'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(t['description'] ?? '', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              _miniAvatar(t['assignee']?['full_name'] ?? 'U', t['assignee']?['avatar_url']),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['assignee']?['full_name'] ?? 'UNASSIGNED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
                Text('PERSONNEL_ID: ${t['user_id'].toString().substring(0,8).toUpperCase()}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black.withOpacity(0.24), fontSize: 7, fontWeight: FontWeight.bold)),
              ]),
              const Spacer(),
              _buildActionWidget(t, isDark),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _miniAvatar(String name, String? url) {
    return CircleAvatar(radius: 14, backgroundColor: Colors.indigoAccent.withOpacity(0.2), backgroundImage: url != null ? NetworkImage(url) : null, child: url == null ? Text(name.isNotEmpty ? name[0] : 'S', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)) : null);
  }

  Widget _buildActionWidget(dynamic t, bool isDark) {
    final status = t['status'];
    if (status == 'Completed') return const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 24);
    if (_myRole == 'staff') {
       if (status == 'Pending') return _actionBtn('ACCEPT', Colors.indigoAccent, () => _updateTaskStatus(t['id'], 'In-Progress'));
       if (status == 'In-Progress') return _actionBtn('SUBMIT_PROOF', Colors.blueAccent, () => _showProofUploadModal(t, isDark));
       if (status == 'Review') return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Text('UNDER_REVIEW', style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.w900)));
    } else {
       if (status == 'Review') return Row(children: [
          _miniIconBtn(Icons.close_rounded, Colors.redAccent, () => _updateTaskStatus(t['id'], 'In-Progress')),
          const SizedBox(width: 8),
          _miniIconBtn(Icons.check_rounded, Colors.greenAccent, () => _updateTaskStatus(t['id'], 'Completed')),
       ]);
       return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900)));
    }
    return const SizedBox();
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)));
  }

  Widget _miniIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)));
  }

  Widget _emptyState(String status, bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_turned_in_outlined, size: 48, color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 16), Text('NO_${status.toUpperCase()}_UNITS', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2))]));
  }

  void _showProofUploadModal(dynamic t, bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (c) => Container(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('UPLOAD_TASK_PROOF', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)), const SizedBox(height: 8), Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 32), _proofOption('CAMERA_CAPTURE', Icons.camera_alt_rounded, isDark), _proofOption('GALLERY_UPLOAD', Icons.photo_library_rounded, isDark), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () { Navigator.pop(c); _updateTaskStatus(t['id'], 'Review'); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text('SUBMIT_FOR_REVIEW', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900))))])));
  }

  Widget _proofOption(String label, IconData icon, bool isDark) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: Colors.indigoAccent, size: 20), const SizedBox(width: 16), Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]));
  }

  void _showCreateTaskModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'Medium';
    String type = 'DELIVERY';
    String? selectedAssignee;
    bool subLoading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(ctx).viewInsets.bottom + 32),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ASSIGN_NEW_MISSION', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 24),
                  _modalField(titleCtrl, 'MISSION_TITLE', isDark),
                  const SizedBox(height: 16),
                  _modalField(descCtrl, 'OPERATIONAL_DESCRIPTION', isDark, lines: 3),
                  const SizedBox(height: 24),
                  _priorityPicker(priority, (v) => setModalState(() => priority = v), isDark),
                  const SizedBox(height: 24),
                  _assigneePicker(_staffList, selectedAssignee, (v) => setModalState(() => selectedAssignee = v), isDark),
                  const SizedBox(height: 40),
                  SizedBox(width: double.infinity, height: 65, child: ElevatedButton(onPressed: (selectedAssignee == null || subLoading) ? null : () async {
                    setModalState(() => subLoading = true);
                    try {
                      if (_myId == null) throw 'Personnel_Protocol_Error: Master ID not detected';
                      
                      await _client.from('employee_tasks').insert({
                        'title': titleCtrl.text, 
                        'description': descCtrl.text, 
                        'priority': priority, 
                        'type': type, 
                        'user_id': selectedAssignee, 
                        'assigner_id': _myId
                      });
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchTasks();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MISSION_INITIALIZED'), backgroundColor: Colors.indigoAccent));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPLO_FAILURE: $e'), backgroundColor: Colors.redAccent));
                    } finally {
                      if (mounted) setModalState(() => subLoading = false);
                    }
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: subLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : Text('INITIALIZE_TASK', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)))),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String hint, bool isDark, {int lines = 1}) {
    return TextField(controller: ctrl, maxLines: lines, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 14, fontWeight: FontWeight.bold), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), contentPadding: const EdgeInsets.all(20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)))));
  }

  Widget _priorityPicker(String selected, Function(String) onSelect, bool isDark) {
    final ps = ['Low', 'Medium', 'High', 'Urgent'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PRIORITY_LEVEL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 12), Row(children: ps.map((p) => Expanded(child: GestureDetector(onTap: () => onSelect(p), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: selected == p ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(p.toUpperCase(), style: TextStyle(color: selected == p ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 8, fontWeight: FontWeight.w900))))))).toList())]);
  }

  Widget _assigneePicker(List<dynamic> staff, String? selected, Function(String) onSelect, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ASSIGN_PERSONNEL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 12), SizedBox(height: 60, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: staff.length, itemBuilder: (context, i) { final s = staff[i]; final isSel = selected == s['id']; return GestureDetector(onTap: () => onSelect(s['id']), child: Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: isSel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(16)), child: Row(children: [_miniAvatar(s['full_name'] ?? 'S', s['avatar_url']), const SizedBox(width: 8), Text(s['full_name']?.toString().toUpperCase() ?? 'STAFF', style: TextStyle(color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontSize: 11, fontWeight: FontWeight.bold))]))); }))]);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Theme.of(context).scaffoldBackgroundColor, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
