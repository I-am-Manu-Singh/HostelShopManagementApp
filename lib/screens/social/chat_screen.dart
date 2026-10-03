import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CampusChatScreen extends StatefulWidget {
  final String roomId;
  final String title;
  final String? targetUserId;
  final String? targetUserRole;
  const CampusChatScreen({
    super.key,
    required this.roomId,
    required this.title,
    this.targetUserId,
    this.targetUserRole,
  });

  @override
  State<CampusChatScreen> createState() => _CampusChatScreenState();
}

class _CampusChatScreenState extends State<CampusChatScreen> {
  final _client = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;

  // Contextual Intel Data
  Map<String, dynamic>? _targetProfile;
  List<Map<String, dynamic>> _userComplaints = [];
  List<Map<String, dynamic>> _userRecentOrders = [];
  List<Map<String, dynamic>> _userAttendances = [];
  bool _isLoadingIntel = false;
  bool _showContextDrawer = false;

  // Mentions support
  List<Map<String, dynamic>> _channelMembers = [];
  List<Map<String, dynamic>> _filteredMentions = [];
  bool _showMentionSuggestions = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _fetchChannelMembers();
    _fetchContextualIntel();
    _subscribeToMessages();
    _msgCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchChannelMembers() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, role')
          .order('full_name')
          .limit(200);
      if (mounted) {
        setState(() {
          _channelMembers = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Error fetching channel members for mentions: $e');
    }
  }

  void _onTextChanged() {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    if (selection.baseOffset < 0) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
      return;
    }

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1 && (lastAt == 0 || textBeforeCursor[lastAt - 1] == ' ' || textBeforeCursor[lastAt - 1] == '\n')) {
      final query = textBeforeCursor.substring(lastAt + 1).toLowerCase();
      // If query is empty, show all available channel members!
      if (!query.contains(' ')) {
        final matches = query.isEmpty 
            ? List<Map<String, dynamic>>.from(_channelMembers)
            : _channelMembers.where((m) {
                final name = (m['full_name'] ?? '').toString().toLowerCase();
                return name.contains(query);
              }).toList();

        setState(() {
          _filteredMentions = matches;
          _showMentionSuggestions = matches.isNotEmpty;
        });
        return;
      }
    }

    if (_showMentionSuggestions) {
      setState(() => _showMentionSuggestions = false);
    }
  }

  void _insertMention(String fullName) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final textBeforeCursor = text.substring(0, cursor);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      final textAfterCursor = text.substring(cursor);
      final cleanName = fullName.replaceAll(' ', '_');
      final newText = '${text.substring(0, lastAt)}@$cleanName $textAfterCursor';
      _msgCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lastAt + cleanName.length + 2),
      );
    }

    setState(() {
      _showMentionSuggestions = false;
    });
  }

  Future<void> _fetchContextualIntel() async {
    // Determine effective target user ID (from parameter or from room string like admin_support_XXX or shop_support_XXX)
    String? uId = widget.targetUserId;
    if (uId == null || uId.isEmpty) {
      if (widget.roomId.startsWith('admin_support_')) {
        uId = widget.roomId.substring('admin_support_'.length);
      } else if (widget.roomId.startsWith('shop_support_')) {
        uId = widget.roomId.substring('shop_support_'.length);
      } else if (widget.roomId.startsWith('shop_manager_')) {
        uId = widget.roomId.substring('shop_manager_'.length);
      }
    }

    final currentUser = _client.auth.currentUser;
    // If user is a student or customer viewing their own thread with admin, show their own intel!
    final effectiveTargetId = (uId != null && uId != currentUser?.id) ? uId : currentUser?.id;
    if (effectiveTargetId == null) return;

    setState(() => _isLoadingIntel = true);

    try {
      // 1. Fetch Profile
      final pRes = await _client
          .from('profiles')
          .select('id, full_name, role, room_number, phone_no, hostel_block')
          .eq('id', effectiveTargetId)
          .maybeSingle();

      // 2. Fetch Complaints
      final cRes = await _client
          .from('complaints')
          .select('id, title, category, status, created_at')
          .eq('student_id', effectiveTargetId)
          .order('created_at', ascending: false)
          .limit(5);

      // 3. Fetch Orders
      final oRes = await _client
          .from('shop_orders')
          .select('id, total_amount, status, created_at')
          .eq('student_id', effectiveTargetId)
          .order('created_at', ascending: false)
          .limit(5);

      // 4. Fetch Attendance
      final aRes = await _client
          .from('attendance')
          .select('id, type, timestamp, is_verified')
          .eq('student_id', effectiveTargetId)
          .order('timestamp', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _targetProfile = pRes;
          _userComplaints = List<Map<String, dynamic>>.from(cRes);
          _userRecentOrders = List<Map<String, dynamic>>.from(oRes);
          _userAttendances = List<Map<String, dynamic>>.from(aRes);
          _isLoadingIntel = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching contextual intel: $e');
      if (mounted) setState(() => _isLoadingIntel = false);
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final user = _client.auth.currentUser;
      final res = await _client
          .from('messages')
          .select('*, profiles!messages_sender_id_fkey(full_name, avatar_url)')
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _messages = res;
          _isLoading = false;
        });
      }

      // Mark unread messages in this room as read for current user
      if (user != null) {
        await _client
            .from('messages')
            .update({'is_read': true})
            .eq('room_id', widget.roomId)
            .neq('sender_id', user.id)
            .eq('is_read', false);
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    _client
        .channel('public:messages:${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (payload) => _fetchMessages(),
        )
        .subscribe();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(msgDate).inDays < 7) {
      return DateFormat('EEEE, MMM d').format(date);
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  bool _isDifferentDay(DateTime d1, DateTime d2) {
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final hasIntel = _targetProfile != null || _userComplaints.isNotEmpty || _userRecentOrders.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 1.5)),
            Row(
              children: [
                const Text('SECURE CONNECTION', style: TextStyle(color: Colors.greenAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                if (_targetProfile?['room_number'] != null)
                  Text(' • ROOM ${_targetProfile!['room_number']}', style: const TextStyle(color: Colors.amberAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (hasIntel)
            IconButton(
              icon: Icon(
                _showContextDrawer ? Icons.info_rounded : Icons.info_outline_rounded,
                color: _showContextDrawer ? Colors.indigoAccent : (isDark ? Colors.white70 : Colors.black54),
                size: 22,
              ),
              tooltip: 'User Activity & Tagging',
              onPressed: () => setState(() => _showContextDrawer = !_showContextDrawer),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_showContextDrawer) _buildContextualIntelDrawer(isDark),
          Expanded(
            child: Stack(
              children: [
                _buildRefractionOrbs(),
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                    : _messages.isEmpty 
                      ? Center(child: Text('NO SYSTEM LOGS IN THIS CHANNEL', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)))
                      : ListView.builder(
                        controller: _scrollCtrl,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final currentMsg = _messages[i];
                          final currentDate = currentMsg['created_at'] != null 
                              ? DateTime.parse(currentMsg['created_at']).toLocal() 
                              : DateTime.now();

                          bool showDateSeparator = false;
                          if (i == _messages.length - 1) {
                            showDateSeparator = true;
                          } else {
                            final olderMsg = _messages[i + 1];
                            if (olderMsg['created_at'] != null) {
                              final olderDate = DateTime.parse(olderMsg['created_at']).toLocal();
                              showDateSeparator = _isDifferentDay(currentDate, olderDate);
                            }
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDateSeparator) _buildDateDivider(currentDate, isDark),
                              _buildMessageBubble(currentMsg, isDark),
                            ],
                          );
                        },
                      ),
              ],
            ),
          ),
          if (_showMentionSuggestions) _buildMentionOverlay(isDark),
          _buildQuickTagBar(isDark),
          _buildInputTerminal(isDark),
        ],
      ),
    );
  }

  /// Interactive tagging chips (Complaint, Order, Room, Attendance)
  Widget _buildQuickTagBar(bool isDark) {
    final chips = <Widget>[];

    // Room tag
    if (_targetProfile?['room_number'] != null) {
      chips.add(_tagChip(
        icon: Icons.bed_rounded,
        label: 'Room ${_targetProfile!['room_number']}',
        color: Colors.purpleAccent,
        onTap: () => _appendTag('[ROOM:${_targetProfile!['room_number']}]'),
      ));
    }

    // Latest Complaints
    for (final c in _userComplaints.take(2)) {
      final cId = c['id'].toString().substring(0, 8);
      final cTitle = c['title']?.toString() ?? 'Issue';
      chips.add(_tagChip(
        icon: Icons.report_problem_rounded,
        label: 'Complaint #$cId ($cTitle)',
        color: Colors.redAccent,
        onTap: () => _appendTag('[COMPLAINT:#$cId - $cTitle]'),
      ));
    }

    // Latest Orders
    for (final o in _userRecentOrders.take(2)) {
      final oId = o['id'].toString().substring(0, 8);
      final amt = o['total_amount'] ?? 0;
      chips.add(_tagChip(
        icon: Icons.shopping_bag_rounded,
        label: 'Order #$oId (₹$amt)',
        color: Colors.greenAccent,
        onTap: () => _appendTag('[ORDER:#$oId - ₹$amt]'),
      ));
    }

    // Latest Attendance
    if (_userAttendances.isNotEmpty) {
      final a = _userAttendances.first;
      final type = a['type']?.toString().toUpperCase() ?? 'HOSTEL';
      chips.add(_tagChip(
        icon: Icons.calendar_month_rounded,
        label: '$type Attendance',
        color: Colors.blueAccent,
        onTap: () => _appendTag('[ATTENDANCE:$type Today]'),
      ));
    }

    if (chips.isEmpty) return const SizedBox();

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  Widget _tagChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 2),
              Icon(Icons.add, size: 10, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _appendTag(String tag) {
    final text = _msgCtrl.text;
    final prefix = text.isEmpty || text.endsWith(' ') ? '' : ' ';
    _msgCtrl.text = '$text$prefix$tag ';
    _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
  }

  /// Contextual Intel Details Panel Drawer
  Widget _buildContextualIntelDrawer(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F33) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded, size: 16, color: Colors.indigoAccent),
                  const SizedBox(width: 6),
                  Text(
                    'RESIDENT & ACCOUNT INTELLIGENCE',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.indigoAccent),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => setState(() => _showContextDrawer = false),
              ),
            ],
          ),
          if (_isLoadingIntel)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_targetProfile != null) ...[
            Text(
              '${_targetProfile!['full_name'] ?? 'User'} • ${(_targetProfile!['role'] ?? 'resident').toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              'Room: ${_targetProfile!['room_number'] ?? 'N/A'} | Block: ${_targetProfile!['hostel_block'] ?? 'N/A'} | Phone: ${_targetProfile!['phone_no'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const Divider(height: 14),
          ],
          if (_userComplaints.isNotEmpty) ...[
            Text('Recent Maintenance / Complaints:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ..._userComplaints.take(2).map((c) => Text('• ${c['title']} [${c['status']}]', style: const TextStyle(fontSize: 10))),
          ],
          if (_userRecentOrders.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Recent Shop Orders:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            ..._userRecentOrders.take(2).map((o) => Text('• Order #${o['id'].toString().substring(0, 8)}: ₹${o['total_amount']} [${o['status']}]', style: const TextStyle(fontSize: 10))),
          ],
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              ),
              child: Text(
                _formatDateHeader(date),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.03), shape: BoxShape.circle))));
  }

  Widget _buildMessageBubble(dynamic m, bool isDark) {
    if (m['sender_id'] == null) return const SizedBox();
    final bool isMe = m['sender_id'] == _client.auth.currentUser!.id;
    final profile = m['profiles'];
    final time = m['created_at'] != null ? DateFormat('HH:mm').format(DateTime.parse(m['created_at']).toLocal()) : '--:--';
    final textColor = isDark ? Colors.white : Colors.black;
    final content = m['content']?.toString() ?? '';

    return FadeInUp(
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  profile?['full_name'] ?? 'Community Member',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: isMe 
                    ? Colors.indigoAccent 
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isMe ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                ),
              ),
              child: _buildRichMessageText(content, isMe, isDark, textColor),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: isMe ? 0 : 4, right: isMe ? 4 : 0),
              child: Text(time, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Parses text to render @mentions and contextual tags ([COMPLAINT:#123], [ORDER:#123], [ATTENDANCE:Date])
  Widget _buildRichMessageText(String content, bool isMe, bool isDark, Color defaultColor) {
    final tokenRegex = RegExp(r'(@[a-zA-Z0-9_\-]+|\[(COMPLAINT|ORDER|ATTENDANCE|ROOM):[^\]]+\])');
    final matches = tokenRegex.allMatches(content);

    if (matches.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          color: isMe ? Colors.white : defaultColor,
          fontSize: 13,
          fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
          height: 1.3,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: TextStyle(
            color: isMe ? Colors.white : defaultColor,
            fontSize: 13,
            fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
            height: 1.3,
          ),
        ));
      }

      final token = match.group(0)!;
      if (token.startsWith('@')) {
        // Highlight mention
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isMe 
                  ? Colors.white.withOpacity(0.25)
                  : Colors.indigoAccent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isMe ? Colors.white38 : Colors.indigoAccent.withOpacity(0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              token.replaceAll('_', ' '),
              style: TextStyle(
                color: isMe ? Colors.white : Colors.indigoAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ));
      } else {
        // Context Tag: [COMPLAINT:id], [ORDER:id], [ATTENDANCE:type]
        final cleanTag = token.replaceAll('[', '').replaceAll(']', '');
        final parts = cleanTag.split(':');
        final tagType = parts[0];
        final tagVal = parts.length > 1 ? parts.sublist(1).join(':') : '';

        Color tagBg = Colors.amber.withOpacity(0.2);
        Color tagFg = Colors.amber;
        IconData tagIcon = Icons.tag_rounded;

        if (tagType == 'COMPLAINT') {
          tagBg = Colors.redAccent.withOpacity(0.2);
          tagFg = Colors.redAccent;
          tagIcon = Icons.report_problem_rounded;
        } else if (tagType == 'ORDER') {
          tagBg = Colors.greenAccent.withOpacity(0.2);
          tagFg = Colors.greenAccent;
          tagIcon = Icons.shopping_bag_rounded;
        } else if (tagType == 'ATTENDANCE') {
          tagBg = Colors.blueAccent.withOpacity(0.2);
          tagFg = Colors.blueAccent;
          tagIcon = Icons.calendar_month_rounded;
        } else if (tagType == 'ROOM') {
          tagBg = Colors.purpleAccent.withOpacity(0.2);
          tagFg = Colors.purpleAccent;
          tagIcon = Icons.bed_rounded;
        }

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.22) : tagBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMe ? Colors.white38 : tagFg.withOpacity(0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tagIcon, size: 12, color: isMe ? Colors.white : tagFg),
                const SizedBox(width: 4),
                Text(
                  '$tagType: $tagVal',
                  style: TextStyle(
                    color: isMe ? Colors.white : tagFg,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: TextStyle(
          color: isMe ? Colors.white : defaultColor,
          fontSize: 13,
          fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
          height: 1.3,
        ),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// Suggestion bar shown when user types '@'
  Widget _buildMentionOverlay(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.alternate_email_rounded, size: 13, color: Colors.indigoAccent),
                const SizedBox(width: 6),
                Text(
                  'MENTION MEMBER',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigoAccent,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _filteredMentions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
              itemBuilder: (context, idx) {
                final member = _filteredMentions[idx];
                final name = member['full_name'] ?? 'User';
                final avatar = member['avatar_url'];

                return InkWell(
                  onTap: () => _insertMention(name),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.indigoAccent.withOpacity(0.2),
                          backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                              ? NetworkImage(avatar)
                              : null,
                          child: (avatar == null || avatar.toString().isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '@${name.replaceAll(' ', '_')}',
                          style: TextStyle(
                            color: isDark ? Colors.white30 : Colors.black26,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputTerminal(bool isDark) {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
    child: Row(
      children: [
        // Quick @ button
        IconButton(
          icon: Icon(
            Icons.alternate_email_rounded,
            color: isDark ? Colors.white60 : Colors.black54,
            size: 20,
          ),
          tooltip: 'Mention user',
          onPressed: () {
            final text = _msgCtrl.text;
            final selection = _msgCtrl.selection;
            final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
            final prefix = (cursor > 0 && text[cursor - 1] != ' ') ? ' @' : '@';
            final newText = text.replaceRange(cursor, cursor, prefix);
            _msgCtrl.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: cursor + prefix.length),
            );
          },
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: TextField(
              controller: _msgCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message or @mention someone...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                // FIX: Strips out all possible fallback borders when field is active or focused
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.indigoAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    ),
  );
}


  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    final txt = _msgCtrl.text.trim();
    _msgCtrl.clear();
    setState(() => _showMentionSuggestions = false);
    try {
      await _client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': _client.auth.currentUser!.id,
        'content': txt,
      });
      _fetchMessages();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SEND_FAILURE: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }
}
