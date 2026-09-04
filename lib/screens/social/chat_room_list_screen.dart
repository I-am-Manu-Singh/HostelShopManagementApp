import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class CampusChatListScreen extends StatefulWidget {
  const CampusChatListScreen({super.key});

  @override
  State<CampusChatListScreen> createState() => _CampusChatListScreenState();
}

class _CampusChatListScreenState extends State<CampusChatListScreen> {
  final _client = Supabase.instance.client;
  List<dynamic> _broadcasts = [];
  bool _isLoadingBroadcasts = true;
  String _userRole = 'user';
  String _currentUserId = '';
  List<Map<String, dynamic>> _userConversations = [];
  Map<String, int> _unreadCounts = {};
  Map<String, String> _lastMessages = {};

  @override
  void initState() {
    super.initState();
    _initUserAndChats();
  }

  Future<void> _initUserAndChats() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
      try {
        final prof = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
        _userRole = prof?['role'] ?? 'user';
      } catch (_) {}
    }
    _fetchBroadcasts();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final isAdmin = _userRole == 'admin' || _userRole == 'hostel_manager' || _userRole == 'owner';
    final List<Map<String, dynamic>> dynamicRooms = [];

    // Group rooms visible to everyone
    dynamicRooms.addAll([
      {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'Welcome to the main chat!'},
      {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu.'},
      {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements.'},
    ]);

    if (isAdmin) {
      // Admin sees user-specific conversations with students
      try {
        final students = await _client
            .from('profiles')
            .select('id, full_name, role')
            .inFilter('role', ['hostel_student', 'mess_student', 'student'])
            .order('full_name');

        for (var s in students) {
          final sId = s['id'].toString();
          final sName = s['full_name'] ?? 'Student';
          dynamicRooms.add({
            'id': 'admin_support_$sId',
            'title': 'Chat: $sName',
            'isGroup': false,
            'subtitle': 'Private inquiry with $sName',
            'targetUserId': sId,
          });
        }
      } catch (e) {
        debugPrint('Error loading student chat threads: $e');
      }
    } else {
      // Normal student sees only their own dedicated Admin Support channel
      dynamicRooms.add({
        'id': 'admin_support_$_currentUserId',
        'title': 'Admin Support (Private)',
        'isGroup': false,
        'subtitle': 'Direct communication with Hostel Administration',
        'targetUserId': _currentUserId,
      });
      dynamicRooms.add({
        'id': 'shop_manager_$_currentUserId',
        'title': 'Shop & Mandi Support',
        'isGroup': false,
        'subtitle': 'Inquire about products & deliveries',
        'targetUserId': _currentUserId,
      });
    }

    // Fetch unread messages & preview for each room
    final unreadMap = <String, int>{};
    final lastMsgMap = <String, String>{};
    for (var r in dynamicRooms) {
      final rId = r['id'].toString();
      try {
        final msgs = await _client
            .from('messages')
            .select('content, sender_id, created_at, is_read')
            .eq('room_id', rId)
            .order('created_at', ascending: false)
            .limit(1);

        if (msgs.isNotEmpty) {
          final m = msgs.first;
          lastMsgMap[rId] = m['content']?.toString() ?? '';
        }

        // Count unread: messages not sent by current user and is_read == false
        final countRes = await _client
            .from('messages')
            .select('id')
            .eq('room_id', rId)
            .neq('sender_id', _currentUserId)
            .eq('is_read', false);
        unreadMap[rId] = (countRes as List).length;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _userConversations = dynamicRooms;
        _unreadCounts = unreadMap;
        _lastMessages = lastMsgMap;
      });
    }
  }

  Future<void> _fetchBroadcasts() async {
    try {
      final res = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _broadcasts = res as List;
          _isLoadingBroadcasts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBroadcasts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    final rooms = [
      {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'Welcome to the main chat!'},
      {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu.'},
      {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements.'},
      {'id': 'admin_support', 'title': 'Admin Support', 'isGroup': false, 'subtitle': 'Private chat with admin.'},
      {'id': 'shop_manager', 'title': 'Shop Manager', 'isGroup': false, 'subtitle': 'Inquire about products.'},
    ];

    final bodyContent = RefreshIndicator(
      onRefresh: _fetchBroadcasts,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined, color: Colors.white, size: 36),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Digital Campus', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Connect with peers & management.', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Horizontal Broadcast Cards Header
            if (_broadcasts.isNotEmpty) ...[
              Text('Live Broadcasts', style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _broadcasts.length,
                  itemBuilder: (context, idx) {
                    final b = _broadcasts[idx];
                    String timeStr = '';
                    try {
                      final dt = DateTime.parse(b['created_at']);
                      timeStr = DateFormat('MMM dd, HH:mm').format(dt);
                    } catch (_) {}

                    return Container(
                      width: 240,
                      margin: const EdgeInsets.only(right: 14, bottom: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  b['title'] ?? 'Global Alert',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(timeStr, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              b['content'] ?? b['body'] ?? '',
                              style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            Text('Conversations', style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _userConversations.length,
                itemBuilder: (context, index) {
                  final room = _userConversations[index];
                  return FadeInUp(
                    delay: Duration(milliseconds: 60 * index),
                    child: _buildChatRoomTile(context, room, isDark),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) return Material(color: bgColor, child: bodyContent);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MESSAGES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: bodyContent,
    );
  }

  Widget _buildChatRoomTile(BuildContext context, Map<String, dynamic> room, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final roomId = room['id']?.toString() ?? '';
    final unread = _unreadCounts[roomId] ?? 0;
    final lastMsg = _lastMessages[roomId];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unread > 0 
              ? Colors.indigoAccent.withOpacity(0.4) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          width: unread > 0 ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigoAccent.withOpacity(0.1),
              child: Icon(
                room['isGroup'] == true ? Icons.groups_rounded : Icons.person_rounded,
                color: Colors.indigoAccent,
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                room['title']?.toString() ?? '',
                style: GoogleFonts.outfit(
                  fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread NEW',
                  style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          (lastMsg != null && lastMsg.isNotEmpty) ? lastMsg : (room['subtitle']?.toString() ?? ''),
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: unread > 0 ? (isDark ? Colors.white70 : Colors.black87) : subColor,
            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampusChatScreen(
                roomId: roomId,
                title: room['title']?.toString() ?? '',
              ),
            ),
          );
          _fetchConversations();
        },
      ),
    );
  }
}
