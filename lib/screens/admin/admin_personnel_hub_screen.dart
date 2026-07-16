import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../student/attendance_calendar_screen.dart';
import '../employee/payroll_terminal_screen.dart';
import '../employee/staff_dossier_screen.dart';
import '../user/my_attendance_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminPersonnelHubScreen extends StatefulWidget {
  const AdminPersonnelHubScreen({super.key});

  @override
  State<AdminPersonnelHubScreen> createState() => _AdminPersonnelHubScreenState();
}

class _AdminPersonnelHubScreenState extends State<AdminPersonnelHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = DatabaseService();
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPersonnel = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPersonnel();
  }

  Future<void> _exportProfilesToCSV() async {
    try {
      final List<String> csvHeaders = [
        'id', 'full_name', 'email', 'phone_no', 'role', 'xp', 'balance',
        'is_verified', 'institute', 'institute_roll_no', 'city', 'delivery_address'
      ];
      
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));
      
      for (var p in _allPersonnel) {
        final List<String> row = [
          p['id']?.toString() ?? '',
          '"${(p['full_name'] ?? '').toString().replaceAll('"', '""')}"',
          p['email']?.toString() ?? '',
          p['phone_no']?.toString() ?? '',
          p['role']?.toString() ?? '',
          (p['xp'] ?? 0).toString(),
          (p['balance'] ?? 0.0).toString(),
          (p['is_verified'] ?? false).toString(),
          '"${(p['institute'] ?? '').toString().replaceAll('"', '""')}"',
          p['institute_roll_no']?.toString() ?? '',
          '"${(p['city'] ?? '').toString().replaceAll('"', '""')}"',
          '"${(p['delivery_address'] ?? '').toString().replaceAll('"', '""')}"',
        ];
        buffer.writeln(row.join(','));
      }
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/central_registry_export.csv');
      await file.writeAsString(buffer.toString());
      
      await Share.shareXFiles([XFile(file.path)], text: 'Central Biodata Registry Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _importProfilesFromCSV() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result == null || result.files.single.path == null) return;
      
      final file = File(result.files.single.path!);
      final List<String> lines = await file.readAsLines();
      if (lines.length < 2) throw 'File is empty or missing headers';
      
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      
      int successCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final List<String> cells = [];
        bool inQuotes = false;
        StringBuffer currentCell = StringBuffer();
        
        for (int c = 0; c < line.length; c++) {
          final char = line[c];
          if (char == '"') {
            inQuotes = !inQuotes;
          } else if (char == ',' && !inQuotes) {
            cells.add(currentCell.toString().trim());
            currentCell.clear();
          } else {
            currentCell.write(char);
          }
        }
        cells.add(currentCell.toString().trim());
        
        final Map<String, dynamic> payload = {};
        String? profileId;
        
        for (int cellIdx = 0; cellIdx < cells.length; cellIdx++) {
          if (cellIdx >= headers.length) break;
          final header = headers[cellIdx];
          final val = cells[cellIdx].replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"');
          
          if (header == 'id') {
            if (val.isNotEmpty && val.length > 5) profileId = val;
          } else if (header == 'full_name') {
            payload['full_name'] = val;
          } else if (header == 'email') {
            payload['email'] = val;
          } else if (header == 'phone_no') {
            payload['phone_no'] = val;
          } else if (header == 'role') {
            payload['role'] = val;
          } else if (header == 'xp') {
            payload['xp'] = int.tryParse(val) ?? 0;
          } else if (header == 'balance') {
            payload['balance'] = double.tryParse(val) ?? 0.0;
          } else if (header == 'is_verified') {
            payload['is_verified'] = val.toLowerCase() == 'true';
          } else if (header == 'institute') {
            payload['institute'] = val;
          } else if (header == 'institute_roll_no') {
            payload['institute_roll_no'] = val;
          } else if (header == 'city') {
            payload['city'] = val;
          } else if (header == 'delivery_address') {
            payload['delivery_address'] = val;
          }
        }
        
        if (profileId != null) {
          await _client.from('profiles').update(payload).eq('id', profileId);
          successCount++;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully updated $successCount profile records'), backgroundColor: Colors.indigoAccent));
        _fetchPersonnel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _fetchPersonnel() async {
    setState(() => _isLoading = true);
    final list = await _db.fetchAllProfiles();
    if (mounted) {
      setState(() {
        _allPersonnel = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark?const Color(0xFF0F172A):Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final showSidebar = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('CENTRAL REGISTRY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_rounded, color: Colors.indigoAccent),
            tooltip: 'Import CSV',
            onPressed: _importProfilesFromCSV,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: Colors.indigoAccent),
            tooltip: 'Export CSV',
            onPressed: _exportProfilesToCSV,
          ),
        ],
        bottom: showSidebar 
          ? null 
          : TabBar(
              controller: _tabController,
              indicatorColor: Colors.indigoAccent,
              indicatorWeight: 4, labelColor: Colors.indigoAccent, unselectedLabelColor: isDark?Colors.white24:Colors.black26,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
              tabs: const [Tab(text: 'STAFF'), Tab(text: 'HOSTEL'), Tab(text: 'MESS')],
            ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : LayoutBuilder(
            builder: (context, constraints) {
              if (showSidebar) {
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: [
                            _buildPersonnelSidebarTile(0, 'STAFF REGISTER', Icons.badge_rounded),
                            _buildPersonnelSidebarTile(1, 'HOSTEL STUDENTS', Icons.hotel_rounded),
                            _buildPersonnelSidebarTile(2, 'MESS STUDENTS', Icons.local_dining_rounded),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildDirectoryView('STAFF', ['warden', 'manager', 'cook', 'staff', 'guard', 'admin', 'owner'], isDark),
                          _buildDirectoryView('HOSTEL', ['hostel_student'], isDark),
                          _buildDirectoryView('MESS', ['mess_student'], isDark),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildDirectoryView('STAFF', ['warden', 'manager', 'cook', 'staff', 'guard', 'admin', 'owner'], isDark),
                  _buildDirectoryView('HOSTEL', ['hostel_student'], isDark),
                  _buildDirectoryView('MESS', ['mess_student'], isDark),
                ],
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffModal(isDark),
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
        label: Text('ADD STAFF', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildPersonnelSidebarTile(int index, String label, IconData icon) {
    final active = _tabController.index == index;
    return ListTile(
      selected: active,
      selectedTileColor: Colors.indigoAccent.withOpacity(0.08),
      leading: Icon(icon, color: active ? Colors.indigoAccent : Colors.grey),
      title: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: active ? Colors.indigoAccent : Colors.grey)),
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
    );
  }

  Widget _buildDirectoryView(String type, List<String> roles, bool isDark) {
    final filtered = _allPersonnel.where((p) {
      final r = p['role']?.toString().toLowerCase() ?? '';
      final matchesRole = roles.contains(r);
      final matchesSearch = (p['full_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    return Column(
      children: [
        _buildHeaderStats(filtered, isDark),
        _buildSearchAndFilters(isDark),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _buildPersonnelTile(filtered[i], isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStats(List<dynamic> filtered, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.1), Colors.purpleAccent.withOpacity(0.1)]), borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statMini('TOTAL', '${filtered.length}', isDark),
          _statMini('ACTIVE', '${(filtered.length * 0.9).toInt()}', isDark),
          _statMini('XP AVG', '${filtered.isEmpty ? 0 : (filtered.fold(0, (sum, p) => sum + (p['xp'] as int? ?? 0)) / filtered.length).toInt()}', isDark),
        ],
      ),
    );
  }

  Widget _statMini(String label, String val, bool isDark) {
    return Column(children: [Text(val, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 22)), Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1))]);
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'SEARCH_PERSONNEL...', hintStyle: TextStyle(color: isDark?Colors.white10:Colors.black12, fontWeight: FontWeight.bold),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigoAccent, size: 20),
          filled: true, fillColor: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildPersonnelTile(dynamic p, bool isDark) {
    final name = p['full_name'] ?? 'TERMINAL_USER_${p['id'].toString().substring(0,4)}';
    final role = p['role']?.toString().toUpperCase() ?? 'NONE';
    final textColor = isDark ? Colors.white : Colors.black;
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: ListTile(
          onTap: () => _showOptions(p, isDark),
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(radius: 20, backgroundColor: Colors.indigoAccent.withOpacity(0.1), backgroundImage: p['avatar_url']!=null ? NetworkImage(p['avatar_url']): null, child: p['avatar_url']==null?Text(name[0], style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)):null),
          title: Text(name.toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
          subtitle: Row(children: [
             Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(role.replaceAll('_', ' '), style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900))),
             const SizedBox(width: 12),
             _miniMetric('XP', '${p['xp'] ?? 0}', isDark),
          ]),
          trailing: const Icon(Icons.more_vert_rounded, color: Colors.indigoAccent, size: 20),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String val, bool isDark) {
    return Row(children: [Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Text(val, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 8, fontWeight: FontWeight.bold))]);
  }

  void _showOptions(dynamic p, bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: isDark?const Color(0xFF1E293B):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _optionItem(Icons.badge_outlined, 'PERSONNEL DOSSIER', Colors.blueAccent, p, isDark),
            if (!p['role'].toString().toLowerCase().contains('student')) ...[
              _optionItem(Icons.payments_rounded, 'PAYROLL TERMINAL', Colors.greenAccent, p, isDark),
              _optionItem(Icons.account_balance_wallet_rounded, 'PAY SALARY', Colors.teal, p, isDark),
            ],
            _optionItem(Icons.history_rounded, 'ATTENDANCE LOG', Colors.orangeAccent, p, isDark),
            if (p['role'] == 'admin') _optionItem(Icons.edit_rounded, 'MANAGE ROLE', Colors.indigoAccent, p, isDark),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL_OPERATION', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }

  Widget _optionItem(IconData icon, String label, Color c, dynamic p, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: c, size: 20),
        title: Text(label, style: GoogleFonts.outfit(color: isDark?Colors.white70:Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.pop(context);
          final String role = p['role']?.toString().toLowerCase() ?? '';
          bool isStudent = role.contains('student');

          if (label == 'ATTENDANCE LOG') {
             Navigator.push(context, MaterialPageRoute(builder: (_) => MyAttendanceScreen(userId: p['id'])));
          } else if (label == 'MANAGE ROLE') {
             _showRolePicker(p, isDark);
          } else if (label == 'PAYROLL TERMINAL' && !isStudent) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => PayrollTerminalScreen(profileOverride: p)));
          } else if (label == 'PERSONNEL DOSSIER') {
             Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDossierScreen(profile: p)));
          } else if (label == 'PAY SALARY' && !isStudent) {
             _showPayoutDialog(p, isDark);
          }
        },
      ),
    );
  }

  void _showRolePicker(dynamic p, bool isDark) {
    final roles = ['hostel_student', 'mess_student', 'warden', 'manager', 'cook', 'staff', 'guard', 'admin', 'owner'];
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('CHANGE ROLE', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: roles.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(roles[i].toUpperCase(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
              onTap: () async {
                await _db.updateProfileRole(p['id'], roles[i]);
                if (mounted) {
                   Navigator.pop(c);
                   _fetchPersonnel();
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated to ${roles[i]}'), backgroundColor: Colors.indigoAccent));
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showPayoutDialog(dynamic p, bool isDark) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('PAY SALARY', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(hintText: 'Enter amount...', hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL', style: TextStyle(color: Colors.redAccent))),
          TextButton(
            onPressed: () async {
              double? val = double.tryParse(ctrl.text);
              if (val != null) {
                await _client.from('payroll_records').insert({
                  'employee_id': p['id'],
                  'amount': val,
                  'status': 'Paid',
                  'processed_at': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                   Navigator.pop(c);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary disbursed successfully'), backgroundColor: Colors.greenAccent));
                }
              }
            },
            child: const Text('DISBURSE', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddStaffModal(bool isDark) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'staff';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: BoxDecoration(color: isDark?const Color(0xFF1E293B):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REGISTER_NEW_PERSONNEL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 24),
              _modalInput(nameCtrl, 'FULL_NAME', isDark, Icons.person_outline),
              const SizedBox(height: 16),
              _modalInput(emailCtrl, 'EMAIL_ADDRESS', isDark, Icons.email_outlined),
              const SizedBox(height: 16),
              _modalInput(phoneCtrl, 'PHONE_NUMBER', isDark, Icons.phone_outlined),
              const SizedBox(height: 24),
              _roleSelector(role, (v) => setModalState(() => role = v), isDark),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, height: 65, child: ElevatedButton(onPressed: () async {
                 // 🧠 Note: Ideally we use auth.signUp, but for testing we can insert into profiles directly if allowed by RLS
                 try {
                   final user = _client.auth.currentUser;
                   await _client.from('profiles').insert({
                     'full_name': nameCtrl.text,
                     'phone_no': phoneCtrl.text,
                     'role': role,
                     'xp': 100,
                   });
                   Navigator.pop(ctx);
                   _fetchPersonnel();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personnel Registered Successfully'), backgroundColor: Colors.greenAccent));
                 } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Failed: $e'), backgroundColor: Colors.redAccent));
                 }
              }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: Text('INITIALIZE_RECORD', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2))))
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, bool isDark, IconData icon) {
    return TextField(controller: ctrl, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 18), hintStyle: TextStyle(color: isDark?Colors.white10:Colors.black12), filled: true, fillColor: isDark?Colors.white.withOpacity(0.02):Colors.black.withOpacity(0.02), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(20)));
  }

  Widget _roleSelector(String current, Function(String) onSelect, bool isDark) {
    final roles = ['hostel_student', 'mess_student', 'warden', 'manager', 'cook', 'staff', 'guard', 'admin', 'owner'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OPERATIONAL_ROLE', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: roles.map((r) => GestureDetector(onTap: () => onSelect(r), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: current == r ? Colors.indigoAccent : (isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(12)), child: Text(r.toUpperCase(), style: TextStyle(color: current == r ? Colors.white : (isDark?Colors.white24:Colors.black26), fontSize: 8, fontWeight: FontWeight.bold))))).toList()),
    ]);
  }
}
