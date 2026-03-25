import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LiveSecurityDashboard extends StatefulWidget {
  const LiveSecurityDashboard({super.key});

  @override
  State<LiveSecurityDashboard> createState() => _LiveSecurityDashboardState();
}

class _LiveSecurityDashboardState extends State<LiveSecurityDashboard> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _securityLogs = [];
  List<dynamic> _messLogs = [];
  int _activeHostelCount = 0;
  int _activeMessCount = 0;

  @override
  void initState() {
    super.initState();
    _setupRealtimeStreams();
    _fetchInitialData();
  }

  void _setupRealtimeStreams() {
    _client.channel('security_updates').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'outpasses', callback: (payload) {
      _fetchInitialData();
    }).subscribe();

    _client.channel('mess_updates').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'attendance', callback: (payload) {
        _fetchInitialData();
    }).subscribe();
  }

  Future<void> _fetchInitialData() async {
    try {
      final security = await _client.from('outpasses').select('*, profiles(full_name, room_number)').order('created_at', ascending: false).limit(20);
      final mess = await _client.from('attendance').select('*, profiles(full_name, room_number)').eq('type', 'Mess').order('created_at', ascending: false).limit(20);
      
      final hostelActive = await _client.from('outpasses').select('id').isFilter('time_in', null).limit(100);
      
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dailyMess = await _client.from('attendance').select('id').eq('type', 'Mess').gte('created_at', todayStr);

      if (mounted) {
        setState(() {
          _securityLogs = security;
          _messLogs = mess;
          _activeHostelCount = hostelActive.length;
          _activeMessCount = dailyMess.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          _buildBackgroundAura(),
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildQuickStats(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('LIVE SECURITY PERIMETER', Icons.shield_outlined, Colors.indigoAccent),
                      const SizedBox(height: 16),
                      _buildSecurityTimeline(),
                      const SizedBox(height: 40),
                      _buildSectionHeader('MESS ACCESS TERMINAL', Icons.fastfood_outlined, Colors.orangeAccent),
                      const SizedBox(height: 16),
                      _buildMessTimeline(),
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

  Widget _buildBackgroundAura() {
    return Positioned(top: -100, right: -100, child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 400, height: 400, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      title: Text('SECURE_CORE_HQ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 4)),
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _statBox('OFF-CAMPUS', '$_activeHostelCount', Colors.redAccent, Icons.hail_rounded),
        const SizedBox(width: 16),
        _statBox('MEALS LOGGED', '$_activeMessCount', Colors.greenAccent, Icons.restaurant_rounded),
      ],
    );
  }

  Widget _statBox(String label, String val, Color c, IconData icon) {
    return Expanded(
      child: FadeInDown(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: c, size: 16)),
              const SizedBox(height: 20),
              Text(val, style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const Spacer(),
        Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ],
    );
  }

  Widget _buildSecurityTimeline() {
    if (_securityLogs.isEmpty) return _emptyState();
    return Column(
      children: _securityLogs.map((log) => _buildSecurityCard(log)).toList(),
    );
  }

  Widget _buildMessTimeline() {
    if (_messLogs.isEmpty) return _emptyState();
    return Column(
      children: _messLogs.map((log) => _buildMessCard(log)).toList(),
    );
  }

  Widget _emptyState() => Padding(padding: const EdgeInsets.all(40), child: Text('WAITING FOR ENROLLMENT RELAY...', style: GoogleFonts.outfit(color: Colors.white10, fontSize: 10, letterSpacing: 1.5)));

  Widget _buildSecurityCard(dynamic log) {
    final bool isEntry = log['time_in'] != null;
    final String time = DateFormat('HH:mm').format(DateTime.parse(isEntry ? log['time_in'] : log['time_out']));
    final profile = log['profiles'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isEntry ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isEntry ? Icons.login_rounded : Icons.logout_rounded, color: isEntry ? Colors.greenAccent : Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile?['full_name']?.toString().toUpperCase() ?? 'IDENTIFIED_UNIT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(isEntry ? 'SECURE_ENTRY_CONFIRMED' : 'SECURE_EXIT_LOGGED', style: TextStyle(color: isEntry ? Colors.greenAccent : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(time, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            Text('UNIT ${profile?['room_number'] ?? 'UNA'}', style: const TextStyle(color: Colors.white24, fontSize: 9)),
          ]),
        ],
      ),
    );
  }

  Widget _buildMessCard(dynamic log) {
    final String time = DateFormat('HH:mm').format(DateTime.parse(log['created_at']));
    final profile = log['profiles'];
    final meal = log['meal_type'] ?? 'MEAL';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.fastfood_rounded, color: Colors.orangeAccent, size: 20)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile?['full_name']?.toString().toUpperCase() ?? 'IDENTIFIED_UNIT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('MEAL_AUTH: $meal', style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ])),
          Text(time, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}
