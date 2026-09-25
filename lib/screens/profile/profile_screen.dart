import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';
import '../shop/shop_order_status_screen.dart';
import '../mandi/mandi_seller_screen.dart';
import '../mandi/mandi_delivery_screen.dart';
import '../profile/app_info_screen.dart';
import '../user/edit_profile_screen.dart';
import '../employee/staff_task_hub_screen.dart';
import '../employee/payroll_terminal_screen.dart';
import '../finance/payment_ledger_screen.dart';
import '../user/settings_screen.dart';
import '../user/my_attendance_screen.dart';
import '../student/mess_student_card_screen.dart';
import '../campus/campus_leaderboard_screen.dart';
import '../auth/face_enrollment_screen.dart';
import '../user/wishlist_screen.dart';
import '../finance/fiscal_reloading_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../admin/admin_finance_hub_screen.dart';
import '../admin/admin_biometric_sync_screen.dart';
import '../user/customer_ranks_screen.dart';
import '../finance/universal_campus_ledger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  final _db = DatabaseService();

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

    if (_isLoading) {
      if (kIsWeb) return Material(color: bgColor, child: const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)));
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)));
    }

    final name = _user?['full_name'] ?? 'User';
    final role = _user?['role'] ?? 'store_customer';
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'N/A';

    final bodyWidget = Stack(
      children: [
        _buildBackgroundOrbs(),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth > 800;

            if (isWide) {
              // 2-Column Wide Split Layout
              return Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  title: Text('PROFILE CONTROL CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: textColor, letterSpacing: 2.5, fontSize: 16)),
                ),
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Profile Info & Metrics)
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            _buildProfileInfo(name, email, role, isDark),
                            const SizedBox(height: 32),
                            _buildQuickMetrics(isDark),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.white10),
                    // Right Column (Identity & Controls)
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (role == 'hostel_student' || role == 'mess_student') ...[
                              _buildSectionHeader('Student Information', isDark),
                              const SizedBox(height: 16),
                              _buildDynamicIdentityMatrix(role, isDark),
                              const SizedBox(height: 32),
                            ],
                            _buildSectionHeader('Account Controls', isDark),
                            const SizedBox(height: 16),
                            ..._buildRoleSpecificTiles(role, isDark),
                            const SizedBox(height: 32),
                            _buildSectionHeader('System Settings', isDark),
                            const SizedBox(height: 16),
                            _buildActionItem(Icons.info_outline_rounded, 'App Info & Legal', 'Version details and legal documents', Colors.teal, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppInfoScreen()))),
                            _buildActionItem(Icons.settings_rounded, 'Settings', 'App preferences & notifications', Colors.blueGrey, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                            _buildActionItem(Icons.logout_rounded, 'Log Out', 'Signed out from session', Colors.redAccent, isDark, onTap: () => Supabase.instance.client.auth.signOut()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Standard Mobile Layout
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(textColor, isDark),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildProfileInfo(name, email, role, isDark),
                        const SizedBox(height: 32),
                        _buildQuickMetrics(isDark),
                        const SizedBox(height: 32),
                        if (role == 'hostel_student' || role == 'mess_student') ...[
                          _buildSectionHeader('Student Information', isDark),
                          const SizedBox(height: 16),
                          _buildDynamicIdentityMatrix(role, isDark),
                          const SizedBox(height: 32),
                        ],
                        _buildSectionHeader('Account Controls', isDark),
                        const SizedBox(height: 16),
                        ..._buildRoleSpecificTiles(role, isDark),
                        const SizedBox(height: 32),
                        _buildSectionHeader('System Settings', isDark),
                        const SizedBox(height: 16),
                        _buildActionItem(Icons.info_outline_rounded, 'App Info & Legal', 'Version details and legal documents', Colors.teal, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppInfoScreen()))),
                        _buildActionItem(Icons.settings_rounded, 'Settings', 'App preferences & notifications', Colors.blueGrey, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                        _buildActionItem(Icons.logout_rounded, 'Log Out', 'Signed out from session', Colors.redAccent, isDark, onTap: () => Supabase.instance.client.auth.signOut()),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );

    if (kIsWeb) return Material(color: bgColor, child: bodyWidget);
    return Scaffold(backgroundColor: bgColor, body: bodyWidget);
  }

  Widget _buildBackgroundOrbs() {
    return Positioned(top: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.08), shape: BoxShape.circle))));
  }

 Widget _buildAppBar(Color textColor, bool isDark) {
  return SliverAppBar(
    // Set this to your app's default solid background surface color
    backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
    // Prevents an accidental M3 tint shift on scroll
    surfaceTintColor: Colors.transparent, 
    elevation: 0, 
    pinned: true, 
    centerTitle: true,
    title: Text(
      'PROFILE', 
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w900, 
        color: textColor, 
        letterSpacing: 2.5, 
        fontSize: 14
      ),
    ),
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
              child: avatar == null || !avatar.toString().startsWith('http') ? Text(name[0], style: GoogleFonts.outfit(fontSize: 32, color: textColor, fontWeight: FontWeight.bold)) : null
            ),
          ),
          const SizedBox(height: 20),
          Text(name.toUpperCase(), style: GoogleFonts.outfit(color: textColor, letterSpacing: 1, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(email.toLowerCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(12)), child: Text(role.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11))),
              if (_user?['is_verified'] == true) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.2))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 12), const SizedBox(width: 6), Text('VERIFIED', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 11))])),
              ],
            ],
          ),
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

  Widget _metricBox(String l, String v, IconData i, Color c, bool isDark) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c, size: 18), const SizedBox(height: 12), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 16)), Text(l, style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 10))])));

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
          if (_user?['delivery_address'] != null || _user?['delivery_location'] != null) ...[
             const Divider(height: 32),
             _matrixRow('MANDI ADD.', _user?['delivery_address'] ?? 'N/A', Icons.home_rounded, isDark),
             const Divider(height: 32),
             _matrixRow('MANDI LOC.', _user?['delivery_location'] ?? 'N/A', Icons.pin_drop_rounded, isDark),
          ],
        ],
      ),
    );
  }

  Widget _matrixRow(String l, String v, IconData i, bool isDark) => Row(children: [Icon(i, color: Colors.indigoAccent, size: 16), const SizedBox(width: 16), Expanded(child: Text(l, style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 11))), Text(v.toString().toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13))]);

  List<Widget> _buildRoleSpecificTiles(String role, bool isDark) {
     if (role == 'admin' || role == 'hostel_manager' || role == 'owner' || role == 'hostel_owner') {
        final bool isOwner = role == 'owner' || role == 'hostel_owner';
        return [
           _buildActionItem(Icons.dashboard_customize_rounded, 'Admin Dashboard', 'Management and operations control', Colors.indigoAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))),
           if (isOwner) ...[
             _buildActionItem(Icons.account_balance_rounded, 'Finance Hub', 'Revenue & accounting records', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen()))),
             _buildActionItem(Icons.menu_book_rounded, 'Transaction Ledger', 'Global transaction tracking details', Colors.amberAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalCampusLedger()))),
             _buildActionItem(Icons.fingerprint_rounded, 'Profile Security (Biometric Sync)', 'Sync biometric locks, Face ID, and reset credentials', Colors.deepOrangeAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBiometricSyncScreen()))),
           ],
        ];
     }
    
    List<Widget> tiles = [];
    if (role == 'hostel_student' || role == 'mess_student') {
      tiles.add(_buildActionItem(Icons.leaderboard_rounded, 'Campus Ranks', 'View campus standing & ranks', Colors.purpleAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusLeaderboardScreen()))));
    } else {
      tiles.add(_buildActionItem(Icons.leaderboard_rounded, 'Customer Ranks', 'View customer standing & orders', Colors.purpleAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerRanksScreen()))));
    }

    tiles.addAll([
      _buildActionItem(Icons.payments_rounded, 'Finance Ledger', 'Wallet, top-up & history', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentLedgerScreen()))),
      _buildActionItem(Icons.history_edu_rounded, 'Order History', 'Past transactions', Colors.pinkAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopOrderStatusScreen()))),
    ]);

    if (role == 'hostel_student' || role == 'mess_student') {
      tiles.insert(0, _buildActionItem(Icons.credit_card_rounded, 'Digital Mess Card', 'NFC Sync Identity', Colors.orange, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MessStudentCardScreen()))));
      tiles.insert(1, _buildActionItem(Icons.face_retouching_natural_rounded, 'Face Enrollment', 'Biometric authorization', Colors.blueAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FaceEnrollmentScreen()))));
    }

    if (role == 'staff') {
      tiles.insert(0, _buildActionItem(Icons.assignment_turned_in_outlined, 'Mission Hub', 'Staff task management', Colors.orangeAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffTaskHubScreen()))));
      tiles.insert(1, _buildActionItem(Icons.payments_outlined, 'Payroll Portal', 'Disbursement logs', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollTerminalScreen()))));
    }

    if (role == 'farmer_seller') {
      tiles.insert(0, _buildActionItem(Icons.agriculture_rounded, 'Farmer Panel', 'Manage products & rates', Colors.green, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiSellerScreen()))));
    }

    if (role == 'delivery_partner') {
      tiles.insert(0, _buildActionItem(Icons.delivery_dining_rounded, 'Delivery Agent Panel', 'View & complete dispatches', Colors.amberAccent, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiDeliveryScreen()))));
    }

    return tiles;
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(children: [Text(title.toUpperCase(), style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)), const Spacer(), Container(height: 1, width: 40, color: Colors.indigoAccent.withOpacity(0.1))]);
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
                Text(title, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w600, fontSize: 11)),
              ])),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
