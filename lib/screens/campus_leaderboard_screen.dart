import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CampusLeaderboardScreen extends StatefulWidget {
  const CampusLeaderboardScreen({super.key});

  @override
  State<CampusLeaderboardScreen> createState() => _CampusLeaderboardScreenState();
}

class _CampusLeaderboardScreenState extends State<CampusLeaderboardScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  List<dynamic> _allLeaders = [];
  List<dynamic> _filteredLeaders = [];
  bool _isLoading = true;
  int _myRank = -1;
  dynamic _myProfile;
  late TabController _tabController;

  final List<String> _tabs = ['ALL', 'STUDENT', 'STAFF', 'ADMIN'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchLeaderboard();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _filterList();
  }

  void _filterList() {
    setState(() {
      String selected = _tabs[_tabController.index].toLowerCase();
      if (selected == 'all') {
        _filteredLeaders = _allLeaders;
      } else if (selected == 'student') {
        _filteredLeaders = _allLeaders.where((u) => u['role'] == 'hostel_student' || u['role'] == 'mess_student').toList();
      } else {
        _filteredLeaders = _allLeaders.where((u) => u['role'] == selected).toList();
      }
    });
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      final res = await _client.from('profiles').select().order('xp', ascending: false);
      
      if (mounted) {
        setState(() {
          _allLeaders = res;
          _filteredLeaders = res;
          if (user != null) {
            final myIndex = res.indexWhere((p) => p['id'] == user.id);
            if (myIndex != -1) {
              _myRank = myIndex + 1;
              _myProfile = res[myIndex];
            }
          }
          _isLoading = false;
        });
        _filterList();
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('LEADERBOARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: textColor)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          dividerColor: Colors.transparent,
          indicatorColor: Colors.indigoAccent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10),
          labelColor: textColor,
          unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
          tabs: _tabs.map((t) => Tab(text: t + 'S')).toList(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : RefreshIndicator(
            onRefresh: _fetchLeaderboard,
            color: Colors.indigoAccent,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: CustomScrollView(
              slivers: [
                if (_myRank != -1 && _tabController.index == 0)
                  SliverToBoxAdapter(
                    child: FadeInDown(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.2), Colors.purpleAccent.withOpacity(0.2)]), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.indigoAccent.withOpacity(0.3))),
                        child: Row(children: [
                          _rankIndicator(_myRank, textColor, isDark),
                          const SizedBox(width: 20),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('YOUR RANK', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                            Text(_myProfile?['full_name']?.toUpperCase() ?? 'YOU', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                            if (_myProfile?['total_focus_time'] != null && _myProfile?['total_focus_time'] > 0)
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 14),
                                  const SizedBox(width: 8),
                                  Text('${(_myProfile?['total_focus_time'] / 3600).toStringAsFixed(1)}H FOCUS', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                             Text('${_myProfile?['xp'] ?? 0}', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 24)),
                             Text('TOTAL XP', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                if (_filteredLeaders.length >= 3)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInDown(child: _buildTopThree(_filteredLeaders.take(3).toList(), isDark)),
                          const SizedBox(height: 40),
                          Text('${_tabs[_tabController.index]} STANDINGS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i < 3 && _filteredLeaders.length >= 3) return const SizedBox.shrink();
                      return FadeInUp(
                        delay: Duration(milliseconds: (i % 10) * 50),
                        child: _buildLeaderboardTile(i, _filteredLeaders[i], isDark),
                      );
                    },
                    childCount: _filteredLeaders.length,
                  ),
                ),
                if (_filteredLeaders.isEmpty)
                   SliverFillRemaining(child: Center(child: Text('NO USERS FOUND', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)))),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
    );
  }

  Widget _rankIndicator(int rank, Color textColor, bool isDark) {
    return Container(width: 45, height: 45, decoration: BoxDecoration(color: textColor.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: textColor.withOpacity(0.1))), alignment: Alignment.center, child: Text('#$rank', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 13)));
  }

  Widget _buildTopThree(List<dynamic> top, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (top.length > 1) _topAvatar(top[1], 1, 70, isDark ? Colors.white24 : Colors.black26, '2', isDark),
        if (top.isNotEmpty) _topAvatar(top[0], 0, 90, Colors.amber, '1', isDark),
        if (top.length > 2) _topAvatar(top[2], 2, 70, Colors.brown, '3', isDark),
      ],
    );
  }

  Widget _topAvatar(dynamic user, int index, double size, Color color, String rank, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)), child: CircleAvatar(radius: size/2, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), child: Text(user['full_name']?[0] ?? 'P', style: TextStyle(color: textColor, fontSize: size*0.4, fontWeight: FontWeight.bold)))),
            Positioned(bottom: -5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Text(rank, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)))),
          ],
        ),
        const SizedBox(height: 12),
        Text(user['full_name']?.toString().split(' ')[0] ?? 'Resident', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
        Text('${user['xp'] ?? 0} XP', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLeaderboardTile(int index, dynamic user, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white24 : Colors.black26;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        children: [
          Text('#${index + 1}', style: GoogleFonts.outfit(color: subColor, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(width: 16),
          CircleAvatar(radius: 18, backgroundColor: isDark ? Colors.white10 : Colors.black12, child: Text(user['full_name']?[0] ?? 'P', style: TextStyle(color: textColor, fontSize: 12))),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user['full_name'] ?? 'User', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              Row(children: [
                Text(user['role']?.toString().toUpperCase() ?? 'RESIDENT', style: TextStyle(color: subColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(width: 8),
                if (user['total_focus_time'] != null && user['total_focus_time'] > 0)
                  Text('• ${(user['total_focus_time'] / 3600).toStringAsFixed(1)}H FOCUS', style: const TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
              ]),
            ],
          )),
          _buildStatusIndicator(user['study_status'], isDark),
          const SizedBox(width: 12),
          Text('${user['xp'] ?? 0} XP', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String? status, bool isDark) {
    if (status == null || status == 'available') {
       return Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle));
    }
    
    IconData icon;
    Color color;
    
    switch (status) {
      case 'focusing':
        icon = Icons.psychology_rounded;
        color = Colors.indigoAccent;
        break;
      case 'meditating':
        icon = Icons.self_improvement_rounded;
        color = Colors.tealAccent;
        break;
      case 'training':
        icon = Icons.fitness_center_rounded;
        color = Colors.orangeAccent;
        break;
      case 'resting':
        icon = Icons.coffee_rounded;
        color = Colors.brown;
        break;
      default:
        icon = Icons.circle;
        color = Colors.greenAccent;
    }
    
    return Tooltip(
      message: status.toUpperCase(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}
