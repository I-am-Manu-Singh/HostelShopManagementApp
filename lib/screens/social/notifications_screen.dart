import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  String _userRole = 'hostel_student';

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      _userRole = profile?['role'] ?? 'hostel_student';

      final res = await _client
          .from('notifications')
          .select()
          .or('user_id.eq.${user.id},target_role.eq.$_userRole')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = (res as List);
          _isLoading = false;
        });
      }
    } catch (e) {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    try {
      await _client.from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);
      _fetchNotifications();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CLEARED ALL NOTIFICATIONS')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    final today = _notifications.where((n) {
       final dt = DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now();
       return DateTime.now().difference(dt).inDays == 0;
    }).toList();
    final earlier = _notifications.where((n) {
       final dt = DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now();
       return DateTime.now().difference(dt).inDays > 0;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('CENTRAL INTELLIGENCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(onPressed: _markAllAsRead, child: Text('CLEAR ALL', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundOrbs(isDark),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : _notifications.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      color: Colors.indigoAccent,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          if (today.isNotEmpty) ...[
                            _buildSectionLabel('DASHBOARD_LIVE', Colors.greenAccent),
                            const SizedBox(height: 16),
                            ...today.map((n) => _buildNotificationTile(n, isDark)).toList(),
                            const SizedBox(height: 32),
                          ],
                          if (earlier.isNotEmpty) ...[
                            _buildSectionLabel('ARCHIVED_INTEL', Colors.indigoAccent),
                            const SizedBox(height: 16),
                            ...earlier.map((n) => _buildNotificationTile(n, isDark)).toList(),
                          ],
                        ],
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Row(children: [Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 2)), const SizedBox(width: 12), Expanded(child: Container(height: 1, color: color.withOpacity(0.1)))]);
  }

  Widget _buildBackgroundOrbs(bool isDark) {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(isDark ? 0.05 : 0.02), shape: BoxShape.circle))));
  }

  Widget _buildNotificationTile(dynamic n, bool isDark) {
    String type = n['type'] ?? 'System';
    Map<String, dynamic> config = _getTypeConfig(type);
    Color color = config['color'];
    IconData icon = config['icon'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(type.toUpperCase(), style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                  Text(_formatTime(n['created_at']), style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Text(n['title'] ?? 'Central Alert', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(n['message'] ?? '', style: TextStyle(color: isDark ? Colors.white38 : Colors.black54, fontSize: 11, height: 1.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeConfig(String type) {
    switch (type.toUpperCase()) {
      case 'OUTPASS': return {'icon': Icons.door_front_door_rounded, 'color': Colors.orangeAccent};
      case 'ATTENDANCE': return {'icon': Icons.fingerprint_rounded, 'color': Colors.greenAccent};
      case 'PROCUREMENT': return {'icon': Icons.shopping_cart_rounded, 'color': Colors.pinkAccent};
      case 'MESS': return {'icon': Icons.restaurant_rounded, 'color': Colors.amberAccent};
      case 'ANNOUNCEMENT': return {'icon': Icons.campaign_rounded, 'color': Colors.lightBlueAccent};
      case 'FINANCIAL': return {'icon': Icons.account_balance_wallet_rounded, 'color': Colors.tealAccent};
      case 'GATE': return {'icon': Icons.security_rounded, 'color': Colors.deepOrangeAccent};
      case 'MAINTENANCE': return {'icon': Icons.build_circle_rounded, 'color': Colors.redAccent};
      default: return {'icon': Icons.notifications_active_rounded, 'color': Colors.indigoAccent};
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'NOW';
    try {
      DateTime dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}M';
      if (diff.inHours < 24) return '${diff.inHours}H';
      return DateFormat('dd MMM').format(dt).toUpperCase();
    } catch (_) {
      return 'INTEL';
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: FadeInUp(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle), child: Icon(Icons.notifications_off_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 80)),
            const SizedBox(height: 32),
            Text('OPERATIONAL CLEARANCE', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text('No pending briefs in your sector.', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
