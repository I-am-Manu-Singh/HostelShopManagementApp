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

  bool _isLoadingConversations = true;

  Future<void> _fetchConversations() async {
    final isAdmin = _userRole == 'admin' || _userRole == 'hostel_manager' || _userRole == 'owner';
    final isStaff = _userRole == 'staff';
    final isHostelStudent = _userRole == 'hostel_student';
    final isMessStudent = _userRole == 'mess_student';
    final isDelivery = _userRole == 'delivery_partner';
    final isFarmer = _userRole == 'farmer_seller';
    final isStoreCustomer = _userRole == 'store_customer';

    final List<Map<String, dynamic>> defaultChannels = [];

    // Core community group channels
    if (isAdmin) {
      defaultChannels.addAll([
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General hostel chat'},
        {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu'},
        {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements'},
        {'id': 'staff_channel', 'title': 'Staff Channel', 'isGroup': true, 'subtitle': 'Internal staff communications'},
        {'id': 'shop_support', 'title': 'Shop Support', 'isGroup': true, 'subtitle': 'Shop & order queries'},
      ]);
    } else if (isStaff) {
      defaultChannels.addAll([
        {'id': 'staff_channel', 'title': 'Staff Channel', 'isGroup': true, 'subtitle': 'Coordinate with teammates'},
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General campus chat'},
        {'id': 'admin_support_$_currentUserId', 'title': 'Admin Support', 'isGroup': false, 'subtitle': 'Private line to hostel management', 'targetUserId': _currentUserId},
      ]);
    } else if (isHostelStudent) {
      defaultChannels.addAll([
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General hostel chat'},
        {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu'},
        {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements'},
        {'id': 'admin_support_$_currentUserId', 'title': 'Admin Support (Private)', 'isGroup': false, 'subtitle': 'Private communication with administration', 'targetUserId': _currentUserId},
        {'id': 'shop_support_$_currentUserId', 'title': 'Shop & Mandi Support', 'isGroup': false, 'subtitle': 'Inquire about orders & deliveries', 'targetUserId': _currentUserId},
      ]);
    } else if (isMessStudent) {
      defaultChannels.addAll([
        {'id': 'mess_community', 'title': 'Mess Feedback', 'isGroup': true, 'subtitle': 'Discuss meals and menu'},
        {'id': 'student_council', 'title': 'Student Council', 'isGroup': true, 'subtitle': 'Official announcements'},
        {'id': 'admin_support_$_currentUserId', 'title': 'Admin Support (Private)', 'isGroup': false, 'subtitle': 'Private communication with administration', 'targetUserId': _currentUserId},
      ]);
    } else if (isDelivery) {
      defaultChannels.addAll([
        {'id': 'delivery_channel', 'title': 'Delivery Operations', 'isGroup': true, 'subtitle': 'Coordinate deliveries with the team'},
        {'id': 'admin_support_$_currentUserId', 'title': 'Admin Support', 'isGroup': false, 'subtitle': 'Contact management for dispatch issues', 'targetUserId': _currentUserId},
      ]);
    } else if (isFarmer) {
      defaultChannels.addAll([
        {'id': 'mandi_channel', 'title': 'Mandi Marketplace', 'isGroup': true, 'subtitle': 'Discuss rates & produce'},
        {'id': 'admin_support_$_currentUserId', 'title': 'Admin Support', 'isGroup': false, 'subtitle': 'Contact management for listing issues', 'targetUserId': _currentUserId},
      ]);
    } else if (isStoreCustomer) {
      defaultChannels.addAll([
        {'id': 'shop_support', 'title': 'Shop Support', 'isGroup': true, 'subtitle': 'Ask about products & orders'},
        {'id': 'shop_support_$_currentUserId', 'title': 'Order Support (Private)', 'isGroup': false, 'subtitle': 'Track your orders and inquire about returns', 'targetUserId': _currentUserId},
      ]);
    } else {
      defaultChannels.addAll([
        {'id': 'hostel_gen', 'title': 'Hostel Community', 'isGroup': true, 'subtitle': 'General campus chat'},
        {'id': 'admin_support_$_currentUserId', 'title': 'Admin Support', 'isGroup': false, 'subtitle': 'Contact hostel management', 'targetUserId': _currentUserId},
      ]);
    }

    try {
      // ⚡ FAST BATCH QUERY: Fetch recent messages to find all rooms with actual message history
      final recentMsgsRes = await _client
          .from('messages')
          .select('room_id, content, sender_id, created_at, is_read')
          .order('created_at', ascending: false)
          .limit(1000);

      final unreadMap = <String, int>{};
      final lastMsgMap = <String, String>{};
      final lastMsgDateMap = <String, DateTime>{};
      final mentionMap = <String, bool>{};
      final activeRoomIds = <String>{};
      final cleanMyName = _currentUserName.replaceAll(' ', '_').toLowerCase();

      final allMsgs = List<Map<String, dynamic>>.from(recentMsgsRes);
      for (final m in allMsgs) {
        final rId = m['room_id']?.toString() ?? '';
        if (rId.isEmpty) continue;
        activeRoomIds.add(rId);

        // Store latest message
        if (!lastMsgMap.containsKey(rId)) {
          lastMsgMap[rId] = m['content']?.toString() ?? '';
          if (m['created_at'] != null) {
            try {
              lastMsgDateMap[rId] = DateTime.parse(m['created_at']).toLocal();
            } catch (_) {}
          }
        }

        // Check mentions
        if (!(mentionMap[rId] ?? false)) {
          final content = (m['content'] ?? '').toString().toLowerCase();
          if (cleanMyName.isNotEmpty &&
              (content.contains('@$cleanMyName') ||
               content.contains('@${_currentUserName.toLowerCase()}'))) {
            mentionMap[rId] = true;
          }
        }

        // Count unreads for me
        final senderId = m['sender_id']?.toString() ?? '';
        final isRead = m['is_read'] as bool? ?? false;
        if (senderId != _currentUserId && !isRead) {
          unreadMap[rId] = (unreadMap[rId] ?? 0) + 1;
        }
      }

      // Collect rooms to display
      final List<Map<String, dynamic>> resolvedRooms = [];

      // 1. Add default group channels (and user's own direct support channels)
      for (final def in defaultChannels) {
        final defId = def['id'].toString();
        // For groups, always show. For user support DM, show always for student/customer.
        if (def['isGroup'] == true || !isAdmin) {
          resolvedRooms.add(Map<String, dynamic>.from(def));
        }
      }

      // 2. Discover all direct messaging rooms that have active messages
      // This includes: admin_support_XXX, shop_support_XXX, shop_manager_XXX (legacy support)
      final dmUserIdsToFetch = <String>{};
      final roomToUserId = <String, String>{};
      final roomToType = <String, String>{};

      for (final rId in activeRoomIds) {
        if (resolvedRooms.any((r) => r['id'] == rId)) continue;

        String? targetId;
        String type = 'user';
        if (rId.startsWith('admin_support_')) {
          targetId = rId.substring('admin_support_'.length);
          type = 'Admin Support';
        } else if (rId.startsWith('shop_support_')) {
          targetId = rId.substring('shop_support_'.length);
          type = 'Shop Customer';
        } else if (rId.startsWith('shop_manager_')) {
          targetId = rId.substring('shop_manager_'.length);
          type = 'Shop Customer';
        }

        if (targetId != null && targetId.isNotEmpty) {
          // If non-admin, only show if targetId == _currentUserId
          if (isAdmin || targetId == _currentUserId) {
            dmUserIdsToFetch.add(targetId);
            roomToUserId[rId] = targetId;
            roomToType[rId] = type;
          }
        }
      }

      // Batch fetch profiles for all active DM rooms in a single query
      if (dmUserIdsToFetch.isNotEmpty) {
        try {
          final profilesRes = await _client
              .from('profiles')
              .select('id, full_name, role, avatar_url, room_number')
              .filter('id', 'in', dmUserIdsToFetch.toList());

          final profileMap = <String, Map<String, dynamic>>{};
          for (final p in profilesRes) {
            profileMap[p['id'].toString()] = Map<String, dynamic>.from(p);
          }

          for (final entry in roomToUserId.entries) {
            final rId = entry.key;
            final uId = entry.value;
            final p = profileMap[uId];
            final name = p?['full_name'] ?? 'User';
            final role = p?['role'] ?? 'resident';
            final roomNum = p?['room_number'] != null ? ' (Room ${p!['room_number']})' : '';
            final typeLabel = roomToType[rId] ?? 'Private Chat';

            resolvedRooms.add({
              'id': rId,
              'title': isAdmin ? '$name$roomNum' : typeLabel,
              'isGroup': false,
              'subtitle': isAdmin ? '$role — $typeLabel' : 'Direct message thread',
              'targetUserId': uId,
              'targetUserRole': role,
              'avatarUrl': p?['avatar_url'],
            });
          }
        } catch (e) {
          debugPrint('Error batch-resolving DM profiles: $e');
        }
      }

      // Sort rooms: Unread first, then by last message timestamp
      resolvedRooms.sort((a, b) {
        final aId = a['id'].toString();
        final bId = b['id'].toString();
        final aUnread = unreadMap[aId] ?? 0;
        final bUnread = unreadMap[bId] ?? 0;
        if (aUnread != bUnread) return bUnread.compareTo(aUnread);

        final aDate = lastMsgDateMap[aId] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = lastMsgDateMap[bId] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _userConversations = resolvedRooms;
          _unreadCounts = unreadMap;
          _lastMessages = lastMsgMap;
          _hasMentionInRoom = mentionMap;
          _isLoadingConversations = false;
          _applyChatFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _userConversations = defaultChannels;
          _isLoadingConversations = false;
          _applyChatFilter();
        });
      }
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
                Row(
                  children: [
                    Text('Conversations', style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filteredConversations.length}',
                        style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _openNewChatSheet(context, isDark),
                  icon: const Icon(Icons.add_comment_rounded, size: 16, color: Colors.indigoAccent),
                  label: Text('START CHAT', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
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
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingConversations
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                  : _filteredConversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined, size: 40, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 8),
                              Text(
                                _chatSearchQuery.isNotEmpty ? 'No conversations matching "$_chatSearchQuery"' : 'No active conversations yet',
                                style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _openNewChatSheet(context, isDark),
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                label: const Text('Start New Conversation'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredConversations.length,
                          itemBuilder: (context, index) {
                            final room = _filteredConversations[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: 30 * index),
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
                targetUserId: room['targetUserId']?.toString(),
                targetUserRole: room['targetUserRole']?.toString(),
              ),
            ),
          );
          _fetchConversations();
        },
      ),
    );
  }

  void _openNewChatSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewConversationBottomSheet(
        currentUserId: _currentUserId,
        userRole: _userRole,
        isDark: isDark,
        onConversationSelected: (roomId, title, targetUserId, targetRole) async {
          Navigator.pop(ctx);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampusChatScreen(
                roomId: roomId,
                title: title,
                targetUserId: targetUserId,
                targetUserRole: targetRole,
              ),
            ),
          );
          _fetchConversations();
        },
      ),
    );
  }
}

class _NewConversationBottomSheet extends StatefulWidget {
  final String currentUserId;
  final String userRole;
  final bool isDark;
  final Function(String roomId, String title, String targetUserId, String targetRole) onConversationSelected;

  const _NewConversationBottomSheet({
    required this.currentUserId,
    required this.userRole,
    required this.isDark,
    required this.onConversationSelected,
  });

  @override
  State<_NewConversationBottomSheet> createState() => _NewConversationBottomSheetState();
}

class _NewConversationBottomSheetState extends State<_NewConversationBottomSheet> {
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedRoleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, role, room_number, phone_no, avatar_url')
          .neq('id', widget.currentUserId)
          .order('full_name')
          .limit(150);

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(res);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading directory: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final name = (u['full_name'] ?? '').toString().toLowerCase();
        final role = (u['role'] ?? '').toString().toLowerCase();
        final room = (u['room_number'] ?? '').toString().toLowerCase();
        final phone = (u['phone_no'] ?? '').toString().toLowerCase();

        final matchesQuery = query.isEmpty ||
            name.contains(query) ||
            role.contains(query) ||
            room.contains(query) ||
            phone.contains(query);

        if (!matchesQuery) return false;

        if (_selectedRoleFilter == 'STUDENTS') {
          return role.contains('student');
        } else if (_selectedRoleFilter == 'STAFF') {
          return role == 'staff' || role == 'admin' || role == 'hostel_manager';
        } else if (_selectedRoleFilter == 'CUSTOMERS') {
          return role == 'store_customer';
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF161A22) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'START CONVERSATION',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilters(),
              style: TextStyle(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                icon: const Icon(Icons.search, size: 18, color: Colors.indigoAccent),
                hintText: 'Search by name, role, room number, or phone...',
                hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Role Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'STUDENTS', 'STAFF', 'CUSTOMERS'].map((cat) {
                final isSel = _selectedRoleFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : textColor)),
                    selected: isSel,
                    selectedColor: Colors.indigoAccent,
                    backgroundColor: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedRoleFilter = cat;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          'No directory contacts found',
                          style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, idx) {
                          final u = _filteredUsers[idx];
                          final uId = u['id'].toString();
                          final name = u['full_name'] ?? 'User';
                          final role = u['role'] ?? 'resident';
                          final room = u['room_number'] != null ? 'Room ${u['room_number']}' : '';
                          final avatar = u['avatar_url'];

                          final isCustomer = role == 'store_customer';
                          final roomId = isCustomer
                              ? 'shop_support_$uId'
                              : 'admin_support_$uId';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigoAccent.withOpacity(0.15),
                              backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                  ? NetworkImage(avatar)
                                  : null,
                              child: (avatar == null || avatar.toString().isEmpty)
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            ),
                            subtitle: Text(
                              [role.toUpperCase(), room].where((s) => s.isNotEmpty).join(' • '),
                              style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.indigoAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.indigoAccent),
                            ),
                            onTap: () {
                              widget.onConversationSelected(
                                roomId,
                                name,
                                uId,
                                role,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
