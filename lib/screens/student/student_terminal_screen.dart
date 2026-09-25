import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../user/my_bookings_screen.dart';
import 'attendance_calendar_screen.dart';
import 'attendance_screen.dart';
import '../user/complaint_screen.dart';
import '../student/room_detail_screen.dart';
import '../../models/hostel.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_browse_screen.dart';
import '../campus/campus_stories_screen.dart';
import '../campus/campus_asset_rental_screen.dart';
import '../campus/campus_leaderboard_screen.dart';
import 'mess_menu_screen.dart';
import 'outpass_screen.dart';
import '../finance/fiscal_reloading_screen.dart';
import 'guest_invitation_screen.dart';
import 'mess_student_card_screen.dart';
import '../social/notifications_screen.dart';
import '../common/add_procurement_screen.dart';
import '../shop/shop_order_status_screen.dart';
import 'student_payment_screen.dart';
import '../finance/fiscal_calendar_screen.dart';
import 'student_task_hub_screen.dart';
import '../productivity/productivity_suite_hub.dart';
import '../security/unified_attendance_screen.dart';
import '../finance/payment_ledger_screen.dart';
import '../profile/profile_qr_screen.dart';
import '../campus/hostel_browse_screen.dart'; // 🧬 Structural Browse Import
import '../finance/student_rent_mess_history_screen.dart';


class StudentTerminalScreen extends StatefulWidget {
  const StudentTerminalScreen({super.key});

  @override
  State<StudentTerminalScreen> createState() => _StudentTerminalScreenState();
}

class _StudentTerminalScreenState extends State<StudentTerminalScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  double _walletBalance = 0;
  Map<String, dynamic>? _activeRoom;
  bool _hasCheckedInToday = false;
  bool _isRentPending = false;
  int _attendedDays = 0;
  int _skippedDays = 0;
  int _activeComplaints = 0;
  List<dynamic> _pendingApprovals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      final complaints = await _client.from('complaints').select('id').eq('user_id', user.id).neq('status', 'Resolved');
      final enrollment = await _client.from('hostel_enrollments').select('*, hostel_rooms(*)').eq('user_id', user.id).eq('payment_status', 'Approved').maybeSingle();
      
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final attHistory = await _client.from('attendance').select('date').eq('user_id', user.id).gte('date', monthStart);
      
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final attToday = await _client.from('attendance').select().eq('user_id', user.id).eq('date', dateStr).maybeSingle();
      
      int attended = (attHistory as List).length;
      int daysPassed = now.day;
      int skipped = daysPassed - attended;
      if (skipped < 0) skipped = 0;
      
      final currentMonthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final rentPaid = await _client.from('fiscal_collections').select().eq('user_id', user.id).eq('collection_type', 'Rent').gte('created_at', currentMonthStart).maybeSingle();
      final recentApprovals = await _client.from('payment_approvals').select().eq('user_id', user.id).order('created_at', ascending: false).limit(5);

      // Compute dynamic XP & focus time if profile has 0 or null
      int xp = int.tryParse(profile?['xp']?.toString() ?? '0') ?? 0;
      int focusSeconds = int.tryParse(profile?['total_focus_time']?.toString() ?? '0') ?? 0;
      
      try {
        final focusLogs = await _client.from('student_focus_logs').select('duration_minutes, xp_earned').eq('user_id', user.id);
        int logMinutes = 0;
        int logXp = 0;
        for (var fl in (focusLogs as List)) {
          logMinutes += (fl['duration_minutes'] as num? ?? 0).toInt();
          logXp += (fl['xp_earned'] as num? ?? 0).toInt();
        }
        if (focusSeconds == 0 && logMinutes > 0) {
          focusSeconds = logMinutes * 60;
        }
        if (xp == 0 && logXp > 0) {
          xp = logXp;
        }
      } catch (_) {}

      // Fallback check on student_tasks completed
      if (xp == 0) {
        try {
          final compTasks = await _client.from('student_tasks').select('id').eq('user_id', user.id).eq('is_completed', true);
          xp = (compTasks as List).length * 50;
        } catch (_) {}
      }

      final updatedProfile = profile != null ? Map<String, dynamic>.from(profile) : <String, dynamic>{};
      updatedProfile['xp'] = xp;
      updatedProfile['total_focus_time'] = focusSeconds;

      if (mounted) {
        setState(() {
          _profile = updatedProfile;
          _activeComplaints = (complaints as List).length;
          _activeRoom = enrollment?['hostel_rooms'];
          _walletBalance = (double.tryParse(profile?['balance']?.toString() ?? '0') ?? 0.0);
          _hasCheckedInToday = attToday != null;
          _attendedDays = attended;
          _skippedDays = skipped;
          _isRentPending = rentPaid == null && (_profile?['role'] == 'hostel_student' || _profile?['role'] == 'owner');
          _pendingApprovals = recentApprovals as List;
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
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('RESIDENT TERMINAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.indigoAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()))),
          IconButton(icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigoAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileQrScreen()))),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(isDark),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    // Desktop/Wide View: 2-column layout split
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: RefreshIndicator(
                            onRefresh: _loadData,
                            backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
                            color: Colors.indigoAccent,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  FadeInDown(child: _buildIdentityHeader(isDark)),
                                  const SizedBox(height: 32),
                                  if (_profile?['role'] == 'hostel_student' || _profile?['role'] == 'mess_student' || _profile?['role'] == 'owner') ...[
                                     _buildAttendanceHero(cardColor, borderColor, isDark),
                                     const SizedBox(height: 16),
                                     if (_pendingApprovals.isNotEmpty) _buildVerificationStatus(isDark),
                                     const SizedBox(height: 32),
                                  ],
                                  _buildMissionPerformanceCard(isDark),
                                  const SizedBox(height: 32),
                                  _buildCommandLiquidity(cardColor, borderColor, isDark),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Colors.black12),
                        Expanded(
                          flex: 5,
                          child: RefreshIndicator(
                            onRefresh: _loadData,
                            backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
                            color: Colors.indigoAccent,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAnnouncementsSection(isDark),
                                  const SizedBox(height: 32),
                                  _buildSectionHeader('MISSION_CRITICAL'),
                                  const SizedBox(height: 16),
                                  _buildOperationalGrid(cardColor, borderColor, isDark),
                                  if (_profile?['role'] == 'admin' || _profile?['role'] == 'hostel_manager' || _profile?['role'] == 'hostel_student' || _profile?['role'] == 'owner') ...[
                                    const SizedBox(height: 32),
                                    _buildSectionHeader('UNIT_ASSIGNMENT'),
                                    const SizedBox(height: 16),
                                    _buildRoomUnitCard(cardColor, borderColor, isDark),
                                    if (_profile?['role'] == 'admin' || _profile?['role'] == 'hostel_manager' || _profile?['role'] == 'owner') ...[
                                      const SizedBox(height: 32),
                                      _buildSectionHeader('TACTICAL_METRICS'),
                                      const SizedBox(height: 16),
                                      _buildMetricsRow(isDark),
                                    ],
                                  ],
                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile View: Single column scrolling list
                  return RefreshIndicator(
                    onRefresh: _loadData,
                    backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
                    color: Colors.indigoAccent,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        FadeInDown(child: _buildIdentityHeader(isDark)),
                        const SizedBox(height: 32),
                        if (_profile?['role'] == 'hostel_student' || _profile?['role'] == 'mess_student' || _profile?['role'] == 'owner') ...[
                           _buildAttendanceHero(cardColor, borderColor, isDark),
                           const SizedBox(height: 16),
                           if (_pendingApprovals.isNotEmpty) _buildVerificationStatus(isDark),
                           const SizedBox(height: 32),
                        ],
                        _buildMissionPerformanceCard(isDark),
                        const SizedBox(height: 32),
                        _buildCommandLiquidity(cardColor, borderColor, isDark),
                        const SizedBox(height: 32),
                        _buildAnnouncementsSection(isDark),
                        const SizedBox(height: 32),
                        _buildSectionHeader('MISSION_CRITICAL'),
                        const SizedBox(height: 16),
                        _buildOperationalGrid(cardColor, borderColor, isDark),
                        if (_profile?['role'] == 'admin' || _profile?['role'] == 'hostel_manager' || _profile?['role'] == 'hostel_student' || _profile?['role'] == 'owner') ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('UNIT_ASSIGNMENT'),
                          const SizedBox(height: 16),
                          _buildRoomUnitCard(cardColor, borderColor, isDark),
                          if (_profile?['role'] == 'admin' || _profile?['role'] == 'hostel_manager' || _profile?['role'] == 'owner') ...[
                            const SizedBox(height: 32),
                            _buildSectionHeader('TACTICAL_METRICS'),
                            const SizedBox(height: 16),
                            _buildMetricsRow(isDark),
                          ],
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
              _buildSOSButton(),
            ],
          ),
    );
  }

  Widget _buildMissionPerformanceCard(bool isDark) {
    return FadeInRight(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductivitySuiteHub())),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigoAccent.withOpacity(0.2), isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PERFORMANCE INTELLIGENCE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  _statBox('XP RATING', '${_profile?['xp'] ?? 0}', Colors.indigoAccent, isDark),
                  const SizedBox(width: 12),
                  _statBox('FOCUS TIME', '${((_profile?['total_focus_time'] ?? 0) / 3600).toStringAsFixed(1)}H', Colors.orangeAccent, isDark),
                  const SizedBox(width: 12),
                  _statBox('LEVEL', '${((_profile?['xp'] ?? 0) / 1000).floor() + 1}', Colors.greenAccent, isDark),
                ],
              ),
              const SizedBox(height: 24),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)), child: Row(children: [const Icon(Icons.rocket_launch_rounded, color: Colors.indigoAccent, size: 14), const SizedBox(width: 12), Text('ENGAGE MISSION HUB TO SYNC OBJECTIVES', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1))])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String val, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: c.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(val, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _header(String l) => Text(l, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  Widget _infoBox(String l, String v, bool isDark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.indigoAccent.withOpacity(0.05) : Colors.indigoAccent.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.indigoAccent.withOpacity(0.1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: Colors.indigoAccent.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 20))]));
  Widget _inputBox(String l, TextEditingController ctrl, bool isDark, {IconData? icon}) => Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: TextField(controller: ctrl, keyboardType: TextInputType.number, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15), decoration: InputDecoration(border: InputBorder.none, labelText: l, labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold), prefixIcon: icon != null ? Icon(icon, color: Colors.indigoAccent, size: 16) : null)));
  Widget _buildBackgroundOrbs() => Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  Widget _buildAttendanceHero(Color cardColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _hasCheckedInToday ? Colors.greenAccent.withOpacity(0.1) : Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.fingerprint_rounded, color: _hasCheckedInToday ? Colors.greenAccent : Colors.indigoAccent, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hasCheckedInToday ? 'PRESENCE LOGGED' : 'PRESENCE PENDING', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(_hasCheckedInToday ? 'Status: AUTHENTICATED' : 'Initiate biometric verification', style: TextStyle(color: isDark ? Colors.white24 : Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _attStat('ATTENDED', '$_attendedDays', Colors.greenAccent, isDark),
              _attStat('SKIPPED', '$_skippedDays', Colors.redAccent, isDark),
              _attStat('STREAK', '$_attendedDays', Colors.orangeAccent, isDark),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnifiedAttendanceScreen(role: _profile?['role'] ?? 'hostel_student'))).then((_) => _loadData()), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent.withOpacity(0.1), side: BorderSide(color: Colors.indigoAccent.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('MANAGE COMPLIANCE', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)))),
        ],
      ),
    );
  }

  Widget _attStat(String label, String val, Color c, bool isDark) {
    return Column(children: [
      Text(val, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      Text(label, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    ]);
  }

  Widget _buildVerificationStatus(bool isDark) {
    if (_pendingApprovals.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAYMENT AUDIT STATUS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text('${_pendingApprovals.length} RECENT', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ..._pendingApprovals.map((appr) {
          final status = (appr['status'] ?? 'Pending').toString();
          final bool isApproved = status.toLowerCase() == 'approved';
          final bool isRejected = status.toLowerCase() == 'rejected';
          final bool isPending = status.toLowerCase() == 'pending';

          final color = isApproved ? Colors.greenAccent : (isRejected ? Colors.redAccent : Colors.amberAccent);
          final iconData = isApproved ? Icons.check_circle_rounded : (isRejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded);
          final pType = appr['payment_type'] ?? 'Payment';
          final amount = appr['amount'] ?? 0;
          final notes = appr['admin_notes']?.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconData, color: color, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pType: ₹$amount'.toUpperCase(),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Admin note: $notes',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ),
                ] else if (isPending) ...[
                  const SizedBox(height: 6),
                  Text(
                    'HQ is auditing your proof. Service protocols will update upon confirmation.',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSOSButton() {
    return Positioned(
      bottom: 24, right: 24,
      child: GestureDetector(
        onLongPress: _triggerSOS,
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)]),
          child: const Center(child: Icon(Icons.emergency_rounded, color: Colors.white, size: 28)),
        ),
      ),
    );
  }

  Widget _buildRefractionOrbs(bool isDark) {
    return Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(isDark ? 0.05 : 0.03), shape: BoxShape.circle))));
  }

  void _triggerSOS() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('EMERGENCY ALERT', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          content: Text('SEND EMERGENCY ALERT?\n\nStaff and warden will be notified with your current location details.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.normal)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
            ElevatedButton(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency alert sent to warden.'), backgroundColor: Colors.redAccent)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Send Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ANNOUNCEMENTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client.from('global_announcements').select().order('created_at', ascending: false).limit(10),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyIntel(isDark);
              
              // 🛡️ Selective audience filtering
              final role = _profile?['role'] ?? '';
              final List filtered = (snapshot.data! as List).where((b) {
                 final target = b['target_audience'] ?? 'ALL';
                 if (target == 'ALL') return true;
                 if (target == 'HOSTEL' && role == 'hostel_student') return true;
                 if (target == 'MESS' && role == 'mess_student') return true;
                 if (target == 'STAFF' && (role == 'staff' || role == 'admin' || role == 'owner')) return true;
                 return false;
              }).toList();

              if (filtered.isEmpty) return _emptyIntel(isDark);
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                itemBuilder: (context, i) => _broadcastCard(filtered[i], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyIntel(bool isDark) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cell_tower_rounded, color: isDark ? Colors.white12 : Colors.black12), const SizedBox(height: 12), Text('NO ACTIVE BROADCASTS', style: TextStyle(color: isDark ? Colors.white10 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5))]),
    );
  }

  Widget _broadcastCard(dynamic b, bool isDark) {
    bool isUrgent = b['is_urgent'] ?? false;
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isUrgent ? Colors.redAccent.withOpacity(0.05) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)), borderRadius: BorderRadius.circular(24), border: Border.all(color: isUrgent ? Colors.redAccent.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(isUrgent ? Icons.warning_amber_rounded : Icons.info_outline, color: isUrgent ? Colors.redAccent : Colors.indigoAccent, size: 14), const SizedBox(width: 8), Text(isUrgent ? 'URGENT INTEL' : 'OPERATIONAL', style: TextStyle(color: isUrgent ? Colors.redAccent : Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))]),
          const SizedBox(height: 12),
          Text(b['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(b['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(children: [Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)), const Spacer(), Container(height: 1, width: 40, color: Colors.indigoAccent.withOpacity(0.1))]);
  }

  Widget _buildIdentityHeader(bool isDark) {
    String studentName = 'Student';
    if (_profile?['full_name'] != null && _profile!['full_name'].toString().trim().isNotEmpty) {
      studentName = _profile!['full_name'].toString().trim();
    } else if (_profile?['email'] != null && _profile!['email'].toString().trim().isNotEmpty) {
      studentName = _profile!['email'].toString().split('@').first;
    } else if (_client.auth.currentUser?.email != null) {
      studentName = _client.auth.currentUser!.email!.split('@').first;
    } else if (_profile?['phone_no'] != null && _profile!['phone_no'].toString().trim().isNotEmpty) {
      studentName = _profile!['phone_no'].toString().trim();
    }

    final initial = studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S';

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
          child: CircleAvatar(radius: 28, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), child: Text(initial, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(studentName, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text('ROLE: ${_profile?['role'] == 'hostel_student' ? 'HOSTEL RESIDENT' : (_profile?['role'] == 'mess_student' ? 'MESS SCHOLAR' : (_profile?['role']?.toString().toUpperCase() ?? 'ACTIVE RESIDENT'))}', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              if (_isRentPending) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentRentMessHistoryScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('RENT PENDING', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 7),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
        ]),
      ],
    );
  }

  Widget _buildCommandLiquidity(Color cardColor, Color borderColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF6366F1).withOpacity(0.15), const Color(0xFF8B5CF6).withOpacity(0.05)]
            : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.indigoAccent.withOpacity(isDark ? 0.05 : 0.02), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WALLET BALANCE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                  const SizedBox(height: 4),
                  Text('Available store credit balance', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
              _statusBadge('WALLET'),
            ],
          ),
          const SizedBox(height: 32),
          Text('₹${_walletBalance.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2)),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  'TRANSACTION HISTORY', 
                  Icons.history_rounded, 
                  isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentLedgerScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color bg, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrimary = bg == Colors.indigoAccent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 55,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isPrimary ? Colors.white10 : (isDark ? Colors.white10 : Colors.black12)),
          boxShadow: isPrimary ? [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87), size: 16),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.outfit(color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalGrid(Color cardColor, Color borderColor, bool isDark) {
    final role = _profile?['role'] ?? 'hostel_student';
    final isOwnerOrAdmin = role == 'admin' || role == 'owner' || role == 'hostel_manager';
    List<Map<String, dynamic>> ops = [
      {'icon': Icons.report_gmailerrorred_rounded, 'label': 'Complaints', 'color': Colors.redAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintScreen()))},
      {'icon': Icons.business_rounded, 'label': 'Hostel Units', 'color': Colors.blueAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelBrowseScreen()))},
      {'icon': Icons.auto_awesome_mosaic_rounded, 'label': 'Stories', 'color': Colors.amberAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusStoriesScreen()))},
      {'icon': Icons.add_shopping_cart_rounded, 'label': 'New Procure', 'color': Colors.tealAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProcurementScreen()))},
    ];

    if (role == 'hostel_student' || isOwnerOrAdmin) {
      ops.insert(0, {'icon': Icons.bed_outlined, 'label': 'Pay Rent', 'color': Colors.greenAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentRentMessHistoryScreen(initialType: 'Rent')))});
      ops.addAll([
        {'icon': Icons.shield_outlined, 'label': 'Gate Attend', 'color': Colors.deepOrangeAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(type: 'gate')))},
        {'icon': Icons.nightlight_round_outlined, 'label': 'Night Attend', 'color': Colors.indigoAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(type: 'night')))},
        {'icon': Icons.sensor_door_outlined, 'label': 'Outpass', 'color': Colors.redAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => OutpassScreen()))},
        {'icon': Icons.badge_outlined, 'label': 'Guest Invite', 'color': Colors.blueAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuestInvitationScreen()))},
      ]);
    }

    if (role == 'mess_student' || isOwnerOrAdmin) {
      ops.insert(0, {'icon': Icons.credit_score_outlined, 'label': 'Renew Mess', 'color': Colors.orangeAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentRentMessHistoryScreen(initialType: 'MessCard')))});
      ops.addAll([
        {'icon': Icons.calendar_today_rounded, 'label': 'Mess Attend', 'color': Colors.greenAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(type: 'mess')))},
        {'icon': Icons.credit_card_rounded, 'label': 'Mess Card', 'color': Colors.orangeAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => MessStudentCardScreen()))},
        {'icon': Icons.restaurant_menu_rounded, 'label': 'Menu', 'color': Colors.indigoAccent, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => MessMenuScreen()))},
      ]);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 6 : (MediaQuery.of(context).size.width > 600 ? 4 : 3),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: ops.length,
      itemBuilder: (context, i) => _hubItem(ops[i], cardColor, borderColor, isDark),
    );
  }

  Widget _buildRoomUnitCard(Color cardColor, Color borderColor, bool isDark) {
    if (_activeRoom == null) return _emptyState('NO ACTIVE ROOM ASSIGNED', isDark);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: HostelRoom.fromJson(_activeRoom!)))),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.bed_rounded, color: Colors.blueAccent)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ROOM ${_activeRoom!['room_number']}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_activeRoom!['wing'] ?? 'Main Block'} • ${_activeRoom!['room_type']}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.white12),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _metricBox('COMPLAINTS', '$_activeComplaints', Colors.redAccent, isDark),
        _metricBox('LEVEL', '${((double.tryParse(_profile?['xp']?.toString() ?? '0') ?? 0) / 1000).floor() + 1}', Colors.greenAccent, isDark),
        _metricBox('CREDIT', '${_walletBalance.toInt()}', Colors.indigoAccent, isDark),
      ],
    );
  }

  Widget _hubItem(Map<String, dynamic> op, Color cardColor, Color borderColor, bool isDark) {
    return GestureDetector(
      onTap: op['onTap'] as VoidCallback,
      child: Container(
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(op['icon'] as IconData, color: op['color'] as Color, size: 24),
          const SizedBox(height: 8),
          Text(op['label'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _metricBox(String label, String val, Color c, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04))),
        child: Column(children: [
          Text(val, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ]),
      ),
    );
  }


  Widget _statusBadge(String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(label, style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold)));
  }

  Widget _emptyState(String msg, bool isDark) {
    return Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), style: BorderStyle.solid)), child: Center(child: Text(msg, style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontWeight: FontWeight.bold, fontSize: 12))));
  }

  Widget _buildSystemTicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: const Row(children: [Icon(Icons.check_circle_outline_rounded, color: Colors.indigoAccent, size: 14), SizedBox(width: 12), Expanded(child: Text('LOG: Resident profile active. Smart card system enabled.', style: TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)))]),
    );
  }
}
