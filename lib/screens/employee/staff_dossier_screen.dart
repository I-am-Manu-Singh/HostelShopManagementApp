import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StaffDossierScreen extends StatefulWidget {
  final dynamic profile;
  const StaffDossierScreen({super.key, required this.profile});

  @override
  State<StaffDossierScreen> createState() => _StaffDossierScreenState();
}

class _StaffDossierScreenState extends State<StaffDossierScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _p;
  Map<String, dynamic>? _enrollment;
  Map<String, dynamic>? _messCard;

  @override
  void initState() {
    super.initState();
    _p = widget.profile;
    _fetchFullProfile();
  }

  Future<void> _fetchFullProfile() async {
    try {
      final res = await _client.from('profiles').select('*, hostel_enrollments(*, hostel_rooms(*)), mess_cards(*)').eq('id', widget.profile['id']).maybeSingle();
      if (mounted) {
        setState(() {
          _p = res;
          _enrollment = (res?['hostel_enrollments'] as List?)?.firstOrNull;
          _messCard = (res?['mess_cards'] as List?)?.firstOrNull;
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
    final textColor = isDark ? Colors.white : Colors.black;
    final role = _p?['role']?.toString().toLowerCase() ?? 'staff';

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundAura(isDark),
          CustomScrollView(
            slivers: [
              _buildAppBar(textColor),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(isDark),
                      const SizedBox(height: 48),

                      _sectionTitle('STRATEGIC_IDENTIFICATION'),
                      const SizedBox(height: 16),
                      _infoCard(Icons.badge_outlined, 'PERSONNEL ROLE', role.toUpperCase(), Colors.indigoAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.phone_android_rounded, 'CONTACT TEL', _p?['phone_no'] ?? 'N/A', Colors.greenAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.email_outlined, 'COMMUNICATION HUB', _p?['email'] ?? 'N/A', Colors.blueAccent, isDark),
                      
                      // 🛡️ ROLE-SPECIFIC: RESIDENCY
                      if (role == 'hostel_student' && _enrollment != null) ...[
                        const SizedBox(height: 48),
                        _sectionTitle('RESIDENCY_LOGISTICS'),
                        const SizedBox(height: 16),
                        _infoCard(Icons.meeting_room_rounded, 'ASSIGNED_UNIT', 'ROOM ${_enrollment!['hostel_rooms']?['room_number'] ?? 'PENDING'}', Colors.indigoAccent, isDark),
                        const SizedBox(height: 12),
                        _infoCard(Icons.domain_rounded, 'BUILDING_AFFILIATION', _enrollment!['building_name'] ?? 'MAIN_CAMPUS', Colors.indigoAccent, isDark),
                      ],

                      // 🛡️ ROLE-SPECIFIC: MESS ACCESS
                      if ((role == 'mess_student' || role == 'hostel_student') && _messCard != null) ...[
                        const SizedBox(height: 48),
                        _sectionTitle('MESS_ACCESS_IDENTITY'),
                        const SizedBox(height: 16),
                        _infoCard(Icons.restaurant_menu_rounded, 'ACCESS_STATUS', _messCard!['status']?.toString().toUpperCase() ?? 'ACTIVE', Colors.orangeAccent, isDark),
                        const SizedBox(height: 12),
                        _infoCard(Icons.calendar_month_rounded, 'EXPIRY_TIMELINE', _messCard!['expiry_date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(_messCard!['expiry_date'])) : 'NO_DATA', Colors.orangeAccent, isDark),
                        const SizedBox(height: 12),
                        _infoCard(Icons.fastfood_rounded, 'MEAL_PROVISION', _messCard!['meal_plan'] ?? 'STANDARD_VEG', Colors.orangeAccent, isDark),
                      ],

                      const SizedBox(height: 48),
                      _sectionTitle('PARENTAL_INFRASTRUCTURE'),
                      const SizedBox(height: 16),
                      _infoCard(Icons.family_restroom_rounded, 'FATHER_NAME', _p?['father_name'] ?? 'PENDING_ENTRY', Colors.orangeAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.phone_callback_rounded, 'FATHER_PHONE', _p?['father_phone'] ?? 'PENDING_ENTRY', Colors.orangeAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.female_rounded, 'MOTHER_NAME', _p?['mother_name'] ?? 'PENDING_ENTRY', Colors.pinkAccent, isDark),

                      const SizedBox(height: 48),
                      _sectionTitle('INSTITUTIONAL_ENCLAVE'),
                      const SizedBox(height: 16),
                      _infoCard(Icons.school_rounded, 'INSTITUTE', _p?['institute'] ?? 'UNKNOWN_CAMPUS', Colors.purpleAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.numbers_rounded, 'ROLL_NUMBER', _p?['institute_roll_no'] ?? 'PENDING_SYNC', Colors.purpleAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.history_rounded, 'SESSION_YEAR', _p?['session_year'] ?? 'N/A', Colors.purpleAccent, isDark),

                      const SizedBox(height: 48),
                      _sectionTitle('GEOSPATIAL_ENCLAVE'),
                      const SizedBox(height: 16),
                      _infoCard(Icons.home_rounded, 'STREET_ADDRESS', _p?['home_address'] ?? 'PENDING_ENTRY', Colors.tealAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.location_city_rounded, 'RESIDENCE_CITY', _p?['city'] ?? 'UNKNOWN', Colors.tealAccent, isDark),
                      const SizedBox(height: 12),
                      _infoCard(Icons.map_rounded, 'RESIDENCE_STATE', _p?['state'] ?? 'UNKNOWN', Colors.tealAccent, isDark),

                      if (!role.contains('student')) ...[
                        const SizedBox(height: 48),
                        _sectionTitle('SALARY DETAILS'),
                        const SizedBox(height: 16),
                        _infoCard(Icons.payments_outlined, 'BASE REMUNERATION', '₹${(_p?['salary'] ?? 0).toInt()}', Colors.amberAccent, isDark),
                        const SizedBox(height: 12),
                        _infoCard(Icons.account_balance_rounded, 'BANKING STATUS', _p?['bank_account_no'] != null ? 'SECURELY_LOGGED' : 'PENDING_DOCUMENTATION', Colors.tealAccent, isDark),
                      ],
                      
                      const SizedBox(height: 48),
                      _sectionTitle('HISTORICAL_METRICS'),
                      const SizedBox(height: 16),
                      _metricRow(isDark),
                      const SizedBox(height: 100),
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

  Widget _buildBackgroundAura(bool isDark) {
    return Positioned(top: -100, left: -100, child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container(width: 400, height: 400, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildAppBar(Color textColor) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      title: Text('STAFF PROFILE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 4)),
      centerTitle: true,
      leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.indigoAccent, width: 2)), child: CircleAvatar(radius: 50, backgroundColor: isDark ? Colors.white10 : Colors.black12, child: Text(_p?['full_name']?[0] ?? 'S', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigoAccent)))),
              Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle), child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(_p?['full_name']?.toString().toUpperCase() ?? 'STAFF_UNIT', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
        Text('UNIT_ID: ${_p?['id'].toString().substring(0, 8).toUpperCase()}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2));
  }

  Widget _infoCard(IconData icon, String label, String val, Color color, bool isDark) {
    return FadeInRight(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(bool isDark) {
    return Row(
      children: [
        _metricBox('XP_SCORE', '${_p?['xp'] ?? 0}', Colors.indigoAccent, isDark),
        const SizedBox(width: 16),
        _metricBox('LOYALTY', '${_p?['loyalty_rank'] ?? 1}', Colors.orangeAccent, isDark),
        const SizedBox(width: 16),
        _metricBox('MISSIONS', '${_p?['tasks_completed'] ?? 0}', Colors.greenAccent, isDark),
      ],
    );
  }

  Widget _metricBox(String label, String val, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(
          children: [
            Text(val, style: GoogleFonts.outfit(color: c, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
