import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';
import 'settings_screen.dart';
import 'app_info_screen.dart';
import 'edit_profile_screen.dart';
import 'staff_task_hub_screen.dart';
import 'payroll_terminal_screen.dart';
import 'payment_ledger_screen.dart';
import 'my_attendance_screen.dart';
import 'mess_student_card_screen.dart';
import 'campus_leaderboard_screen.dart';
import 'shop_order_status_screen.dart';
import 'face_enrollment_screen.dart';
import 'wishlist_screen.dart';
import 'fiscal_reloading_screen.dart';
import 'admin_panel_screen.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_personnel_hub_screen.dart';
import 'universal_campus_ledger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('*, hostel_enrollments(*, hostel_rooms(*)), mess_cards(*)')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _user = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Profile Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)));

    final name = _user?['full_name'] ?? 'User';
    final role = _user?['role'] ?? 'store_customer';
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'N/A';

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundOrbs(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(textColor),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildProfileInfo(name, email, role, isDark),
                      const SizedBox(height: 32),
                      _buildRoleSpecificIdentityCard(role, isDark),
                      const SizedBox(height: 32),
                      _buildQuickMetrics(isDark),
                      const SizedBox(height: 32),
                      
                      if (role == 'hostel_student' || role == 'mess_student') ...[
                        _buildSectionHeader('Information Matrix', isDark),
                        const SizedBox(height: 16),
                        _buildDynamicIdentityMatrix(role, isDark),
                        const SizedBox(height: 32),
                      ],
                      
                      _buildSectionHeader('Operational Controls', isDark),
                      const SizedBox(height: 16),
                      ..._buildRoleSpecificTiles(role, isDark),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('System Protocols', isDark),
                      const SizedBox(height: 16),
                      _buildActionItem(Icons.edit_note_rounded, 'Edit Profile', 'Update personal & identity data', Colors.blueAccent, isDark, onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                        _fetchProfile();
                      }),
                      _buildActionItem(Icons.settings_rounded, 'Settings', 'App preferences & notifications', Colors.blueGrey, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                      _buildActionItem(Icons.logout_rounded, 'De-Authorize', 'Signed out from session', Colors.redAccent, isDark, onTap: () => Supabase.instance.client.auth.signOut()),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Positioned(top: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.08), shape: BoxShape.circle))));
  }

  Widget _buildAppBar(Color textColor) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0, pinned: true, centerTitle: true,
      title: Text('CENTRAL CORE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2.5)),
    );
  }

  Widget _buildProfileInfo(String name, String email, String role, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final avatar = _user?['latest_photo_url'] ?? _user?['avatar_url'];
    return FadeInDown(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.indigoAccent, width: 2)),
            child: CircleAvatar(
              radius: 54, 
              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), 
              backgroundImage: avatar != null && avatar.toString().startsWith('http') ? NetworkImage(avatar.toString()) : null,
              child: avatar == null || !avatar.toString().startsWith('http') ? Text(name[0], style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)) : null
            ),
          ),
          const SizedBox(height: 20),
          Text(name.toUpperCase(), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1)),
          Text(email.toLowerCase(), style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(12)), child: Text(role.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
              if (_user?['is_verified'] == true) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.2))), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 12), SizedBox(width: 6), Text('VERIFIED', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSpecificIdentityCard(String role, bool isDark) {
    if (role == 'hostel_student') {
      final enrollment = _user?['hostel_enrollments'];
      final room = (enrollment is List && enrollment.isNotEmpty) ? enrollment[0]['hostel_rooms'] : null;
      return _identityCard(
        'RESIDENTIAL CLEARANCE',
        room != null ? 'ROOM ${room['room_number']}' : 'PENDING ALLOCATION',
        room != null ? '${room['building_name']} • FLOOR ${room['floor']}' : 'Awaiting admin approval',
        Icons.bed_rounded,
        Colors.indigoAccent,
        isDark,
      );
    } else if (role == 'mess_student') {
      final card = _user?['mess_cards'];
      final expiry = (card is List && card.isNotEmpty) ? card[0]['expiry_date'] : null;
      return _identityCard(
        'MESS SERVICE ACCESS',
        'ACTIVE CARD',
        expiry != null ? 'EXPIRY: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(expiry))}' : 'No active card found',
        Icons.restaurant_rounded,
        Colors.orangeAccent,
        isDark,
      );
    } else if (role == 'staff') {
      final doj = _user?['date_of_joining'];
      return _identityCard(
        'OPERATIONAL IDENTIFIER',
        'CAMPUS STAFF',
        doj != null ? 'SINCE: ${DateFormat('MMM yyyy').format(DateTime.parse(doj))}' : 'Operational personnel',
        Icons.badge_outlined,
        Colors.greenAccent,
        isDark,
      );
    } else if (role == 'owner') {
      return _identityCard(
        'AUTHORITY IDENTIFIER',
        role.toUpperCase() == 'OWNER' ? 'SYSTEM_OWNER' : 'CAMPUS_ADMIN',
        'Command Clearance Level 10',
        Icons.shield_rounded,
        Colors.indigoAccent,
        isDark,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _identityCard(String label, String title, String subtitle, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDark ? [] : [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: color, size: 32)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(subtitle, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
          ])),
        ],
      ),
    );
  }

  Widget _buildQuickMetrics(bool isDark) {
     final role = _user?['role']?.toString().toLowerCase() ?? '';
     final isStudent = role.contains('student');
     final xp = _user?['xp'] ?? 0;
     final fund = _user?['balance'] ?? 0;
     
     return Row(children: [
        if (isStudent) ...[
          _metricBox('XP LEVEL', '$xp', Icons.auto_awesome_rounded, Colors.pinkAccent, isDark),
          const SizedBox(width: 12),
        ],
        _metricBox('WALLET FUND', '₹$fund', Icons.account_balance_wallet_rounded, Colors.greenAccent, isDark),
        if (!isStudent) ...[
          const SizedBox(width: 12),
          _metricBox('AUTH_TOKEN', 'SECURE', Icons.token_rounded, Colors.indigoAccent, isDark),
        ],
     ]);
  }

  Widget _metricBox(String l, String v, IconData i, Color c, bool isDark) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c, size: 18), const SizedBox(height: 12), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w900)), Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))])));

  Widget _buildDynamicIdentityMatrix(String role, bool isDark) {
    bool isStudent = role.contains('student');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          _matrixRow('CONTACT', _user?['phone_no'] ?? 'N/A', Icons.phone_android_rounded, isDark),
          const Divider(height: 32),
          if (isStudent) ...[
             _matrixRow('INSTITUTE', _user?['institute'] ?? 'N/A', Icons.school_rounded, isDark),
             const Divider(height: 32),
             _matrixRow('ROLL NO', _user?['institute_roll_no'] ?? 'N/A', Icons.numbers_rounded, isDark),
             const Divider(height: 32),
          ],
          _matrixRow('RESIDENCE', _user?['city'] ?? 'N/A', Icons.location_city_rounded, isDark),
        ],
      ),
    );
  }

  Widget _matrixRow(String l, String v, IconData i, bool isDark) => Row(children: [Icon(i, color: Colors.indigoAccent, size: 16), const SizedBox(width: 16), Expanded(child: Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))), Text(v.toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold))]);

  List<Widget> _buildRoleSpecificTiles(String role, bool isDark) {
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner' || role == 'hostel_owner') {
       return [
          _buildActionItem(Icons.dashboard_customize_rounded, 'Command Dashboard', 'Admin control & oversight', Colors.indigoAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))),
          _buildActionItem(Icons.account_balance_rounded, 'Fiscal Center', 'Revenue & financial auditing', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen()))),
          _buildActionItem(Icons.menu_book_rounded, 'Universal Ledger', 'Global transaction tracking', Colors.amberAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalCampusLedger()))),
       ];
    }
    
    List<Widget> tiles = [
      _buildActionItem(Icons.leaderboard_rounded, 'Campus Ranks', 'View global leaderboard', Colors.purpleAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CampusLeaderboardScreen()))),
      _buildActionItem(Icons.payments_rounded, 'Fiscal Ledger', 'Wallet, top-up & history', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentLedgerScreen()))),
      _buildActionItem(Icons.history_edu_rounded, 'Order History', 'Past transactions', Colors.pinkAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopOrderStatusScreen()))),
    ];

    if (role == 'hostel_student' || role == 'mess_student') {
      tiles.insert(0, _buildActionItem(Icons.credit_card_rounded, 'Digital Mess Card', 'NFC Sync Identity', Colors.orange, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MessStudentCardScreen()))));
      tiles.insert(1, _buildActionItem(Icons.face_retouching_natural_rounded, 'Face Enrollment', 'Biometric authorization', Colors.blueAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FaceEnrollmentScreen()))));
    }

    if (role == 'staff') {
      tiles.insert(0, _buildActionItem(Icons.assignment_turned_in_outlined, 'Mission Hub', 'Staff task management', Colors.orangeAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffTaskHubScreen()))));
      tiles.insert(1, _buildActionItem(Icons.payments_outlined, 'Payroll Portal', 'Disbursement logs', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollTerminalScreen()))));
    }

    return tiles;
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(children: [Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)), const Spacer(), Container(height: 1, width: 40, color: Colors.indigoAccent.withOpacity(0.1))]);
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle, Color color, bool isDark, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w600)),
              ])),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

