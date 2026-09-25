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
  String _currentUserName = '';
  List<Map<String, dynamic>> _userConversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  Map<String, int> _unreadCounts = {};
  Map<String, String> _lastMessages = {};
  Map<String, bool> _hasMentionInRoom = {};
  String _chatSearchQuery = '';

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
        final prof = await _client.from('profiles').select('role, full_name').eq('id', user.id).maybeSingle();
        _userRole = prof?['role'] ?? 'user';
        _currentUserName = prof?['full_name'] ?? '';
      } catch (_) {}
    }
    _fetchBroadcasts();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final isAdmin = _userRole == 'admin' || _userRole == 'hostel_manager' || _userRole == 'owner';
    final isStaff = _userRole == 'staff';
    final isHostelStudent = _userRole == 'hostel_student';
    final isMessStudent = _userRole == 'mess_student';
    final isDelivery = _userRole == 'delivery_partner';
    final isFarmer = _userRole == 'farmer_seller';
    final isStoreCustomer = _userRole == 'store_customer';

    final List<Map<String, dynamic>> dynamicRooms = [];

    if (isAdmin) {
      // Admins see all group channels + DMs with every user
      dynamicRooms.addAll([
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General hostel chat'},
        {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu'},
        {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements'},
        {'id': 'staff_channel', 'title': 'Staff Channel', 'isGroup': true, 'subtitle': 'Internal staff communications'},
        {'id': 'shop_support', 'title': 'Shop Support', 'isGroup': true, 'subtitle': 'Shop & order queries'},
      ]);
      try {
        final users = await _client
            .from('profiles')
            .select('id, full_name, role, avatar_url')
            .order('full_name');
        for (var s in users) {
          final sId = s['id'].toString();
          if (sId == _currentUserId) continue;
          final sName = s['full_name'] ?? 'User';
          dynamicRooms.add({
            'id': 'admin_support_$sId',
            'title': sName,
            'isGroup': false,
            'subtitle': '${s['role'] ?? 'user'} — private chat',
            'targetUserId': sId,
            'avatarUrl': s['avatar_url'],
          });
        }
      } catch (e) {
        debugPrint('Error loading user chat threads: $e');
      }
    } else if (isStaff) {
      // Staff see staff channel + admin DM
      dynamicRooms.addAll([
        {'id': 'staff_channel', 'title': 'Staff Channel', 'isGroup': true, 'subtitle': 'Coordinate with teammates'},
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General campus chat'},
        {
          'id': 'admin_support_$_currentUserId',
          'title': 'Admin Support',
          'isGroup': false,
          'subtitle': 'Private line to hostel management',
          'targetUserId': _currentUserId,
        },
      ]);
    } else if (isHostelStudent) {
      // Hostel students see general, mess, council, admin DM, shop DM
      dynamicRooms.addAll([
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General hostel chat'},
        {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu'},
        {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements'},
        {
          'id': 'admin_support_$_currentUserId',
          'title': 'Admin Support (Private)',
          'isGroup': false,
          'subtitle': 'Private communication with administration',
          'targetUserId': _currentUserId,
        },
        {
          'id': 'shop_manager_$_currentUserId',
          'title': 'Shop & Mandi Support',
          'isGroup': false,
          'subtitle': 'Inquire about orders & deliveries',
          'targetUserId': _currentUserId,
        },
      ]);
    } else if (isMessStudent) {
      // Mess students see mess channel, council, admin DM
      dynamicRooms.addAll([
        {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu'},
        {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements'},
        {
          'id': 'admin_support_$_currentUserId',
          'title': 'Admin Support (Private)',
          'isGroup': false,
          'subtitle': 'Private communication with administration',
          'targetUserId': _currentUserId,
        },
      ]);
    } else if (isDelivery) {
      // Delivery partners see delivery channel + admin DM
      dynamicRooms.addAll([
        {'id': 'delivery_channel', 'title': 'Delivery Operations', 'isGroup': true, 'subtitle': 'Coordinate deliveries with the team'},
        {
          'id': 'admin_support_$_currentUserId',
          'title': 'Admin Support',
          'isGroup': false,
          'subtitle': 'Contact management for dispatch issues',
          'targetUserId': _currentUserId,
        },
      ]);
    } else if (isFarmer) {
      // Farmers see mandi channel + admin DM
      dynamicRooms.addAll([
        {'id': 'mandi_channel', 'title': 'Mandi Marketplace', 'isGroup': true, 'subtitle': 'Discuss rates & produce'},
        {
          'id': 'admin_support_$_currentUserId',
          'title': 'Admin Support',
          'isGroup': false,
          'subtitle': 'Contact management for listing issues',
          'targetUserId': _currentUserId,
        },
      ]);
    } else if (isStoreCustomer) {
      // Store customers see shop support + admin DM
      dynamicRooms.addAll([
        {'id': 'shop_support', 'title': 'Shop Support', 'isGroup': true, 'subtitle': 'Ask about products & orders'},
        {
          'id': 'shop_manager_$_currentUserId',
          'title': 'Order Support (Private)',
          'isGroup': false,
          'subtitle': 'Track your orders and inquire about returns',
          'targetUserId': _currentUserId,
        },
      ]);
    } else {
      // Default: general + admin DM
      dynamicRooms.addAll([
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General campus chat'},
        {
          'id': 'admin_support_$_currentUserId',
          'title': 'Admin Support',
          'isGroup': false,
          'subtitle': 'Contact hostel management',
          'targetUserId': _currentUserId,
        },
      ]);
    }

    // Fetch unread counts, last messages, and mention flags for each room
    final unreadMap = <String, int>{};
    final lastMsgMap = <String, String>{};
    final mentionMap = <String, bool>{};
    final cleanMyName = _currentUserName.replaceAll(' ', '_').toLowerCase();

    for (var r in dynamicRooms) {
      final rId = r['id'].toString();
      try {
        final msgs = await _client
            .from('messages')
            .select('content, sender_id, created_at, is_read')
            .eq('room_id', rId)
            .order('created_at', ascending: false)
            .limit(10);

        if (msgs.isNotEmpty) {
          lastMsgMap[rId] = msgs.first['content']?.toString() ?? '';
          bool mentioned = false;
          for (var msg in msgs) {
            final content = (msg['content'] ?? '').toString().toLowerCase();
            if (cleanMyName.isNotEmpty &&
                (content.contains('@$cleanMyName') ||
                    content.contains('@${_currentUserName.toLowerCase()}'))) {
              mentioned = true;
              break;
            }
          }
          mentionMap[rId] = mentioned;
        }

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
        _hasMentionInRoom = mentionMap;
        _applyChatFilter();
      });
    }
  }


  void _applyChatFilter() {
    if (_chatSearchQuery.trim().isEmpty) {
      _filteredConversations = List.from(_userConversations);
    } else {
      final q = _chatSearchQuery.trim().toLowerCase();
      _filteredConversations = _userConversations.where((r) {
        final title = (r['title'] ?? '').toString().toLowerCase();
        final sub = (r['subtitle'] ?? '').toString().toLowerCase();
        final last = (_lastMessages[r['id']] ?? '').toLowerCase();
        return title.contains(q) || sub.contains(q) || last.contains(q);
      }).toList();
    }
  }

  Future<void> _fetchBroadcasts() async {
    try {
      final res = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      
      final list = (res as List).where((b) {
        final target = (b['target_audience'] ?? b['target_role'] ?? 'all').toString().toLowerCase();
        if (target == 'all' || target.isEmpty) return true;
        if (_userRole == 'admin' || _userRole == 'owner' || _userRole == 'hostel_manager') return true;
        return target == _userRole || (_userRole.contains('student') && target.contains('student'));
      }).toList();

      if (mounted) {
        setState(() {
          _broadcasts = list;
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Conversations', style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_filteredConversations.length} Threads', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

          // Search Bar for Chats
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
  ),
  child: TextField(
    onChanged: (val) {
      setState(() {
        _chatSearchQuery = val;
        _applyChatFilter();
      });
    },
    style: TextStyle(color: textColor, fontSize: 13),
    decoration: InputDecoration(
      icon: const Icon(Icons.search, size: 18, color: Colors.indigoAccent),
      hintText: 'Search chats, students, messages...',
      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
      // FIX: Explicitly strip out all possible internal border states
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
    ),
  ),
),

            const SizedBox(height: 16),

            Expanded(
              child: _filteredConversations.isEmpty
                  ? Center(
                      child: Text(
                        _chatSearchQuery.isNotEmpty ? 'No conversations matching "$_chatSearchQuery"' : 'No conversations found',
                        style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredConversations.length,
                      itemBuilder: (context, index) {
                        final room = _filteredConversations[index];
                        return FadeInUp(
                          delay: Duration(milliseconds: 40 * index),
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
            if (_hasMentionInRoom[roomId] == true)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.alternate_email_rounded, size: 10, color: Colors.amber),
                    SizedBox(width: 2),
                    Text(
                      'MENTION',
                      style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
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
