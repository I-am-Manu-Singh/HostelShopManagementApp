import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

class achievements_screen extends StatefulWidget {
  const achievements_screen({super.key});

  @override
  State<achievements_screen> createState() => _achievements_screenState();
}

class _achievements_screenState extends State<achievements_screen> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _dbService.fetchUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final xp = _userProfile?['xp'] ?? 0;
    final int level = (xp / 1000).floor() + 1;
    final double progress = (xp % 1000) / 1000;

    final List<Map<String, dynamic>> achievements = [
      {'title': 'Mission Pioneer', 'desc': 'Complete first hostel enrollment', 'xp_req': 500, 'icon': Icons.rocket_launch_rounded},
      {'title': 'Night Crawler', 'desc': 'Complete 10 late night orders', 'xp_req': 1500, 'icon': Icons.nights_stay_rounded},
      {'title': 'Top Resident', 'desc': 'Maintain elite status for a month', 'xp_req': 3000, 'icon': Icons.star_outline},
      {'title': 'Bulk Buyer', 'desc': 'Single order over ₹500', 'xp_req': 1000, 'icon': Icons.shopping_cart_checkout_rounded},
      {'title': 'Social Node', 'desc': 'Refer 5 new residents', 'xp_req': 5000, 'icon': Icons.share_rounded},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('RECOGNITION TERMINAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(child: _buildBanner(level, xp, progress)),
                  const SizedBox(height: 32),
                  Text('ACHIEVEMENT DOSSIERS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  ...achievements.asMap().entries.map((e) {
                    final isUnlocked = xp >= e.value['xp_req'];
                    return FadeInUp(
                      delay: Duration(milliseconds: e.key * 100),
                      child: _buildAchievementTile(e.value, isUnlocked),
                    );
                  }).toList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildBanner(int level, int totalXp, double progress) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.indigoAccent.withOpacity(0.1)), gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, size: 60, color: Colors.amber),
          const SizedBox(height: 16),
          Text('LEVEL $level COMMANDER', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(_userProfile?['full_name']?.toString().toUpperCase() ?? 'UNKOWN_RESIDENT', style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$totalXp XP', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900)),
              Text('${((1 - progress) * 1000).toInt()} XP TO NEXT LEVEL', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, color: Colors.indigoAccent, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(Map<String, dynamic> data, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: unlocked ? Colors.indigoAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: unlocked ? Colors.indigoAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: unlocked ? Colors.indigoAccent.withOpacity(0.1) : Colors.white10, borderRadius: BorderRadius.circular(15)), child: Icon(data['icon'], color: unlocked ? Colors.indigoAccent : Colors.white24, size: 20)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'], style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(data['desc'], style: TextStyle(color: Colors.white24, fontSize: 10)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${data['xp_req']}', style: GoogleFonts.outfit(color: unlocked ? Colors.greenAccent : Colors.white10, fontWeight: FontWeight.w900, fontSize: 13)),
            Text('XP REQ', style: TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}
