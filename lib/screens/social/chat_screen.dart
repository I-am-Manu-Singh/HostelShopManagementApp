import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CampusChatScreen extends StatefulWidget {
  final String roomId;
  final String title;
  const CampusChatScreen({super.key, required this.roomId, required this.title});

  @override
  State<CampusChatScreen> createState() => _CampusChatScreenState();
}

class _CampusChatScreenState extends State<CampusChatScreen> {
  final _client = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;

  // Mentions support
  List<Map<String, dynamic>> _channelMembers = [];
  List<Map<String, dynamic>> _filteredMentions = [];
  bool _showMentionSuggestions = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _fetchChannelMembers();
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
          .limit(50);
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
      // Only suggest if query doesn't contain space
      if (!query.contains(' ')) {
        final matches = _channelMembers.where((m) {
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

  Future<void> _fetchMessages() async {
    try {
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
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LINK_FAILURE: $e'), backgroundColor: Colors.redAccent));
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
            const Text('SECURE CONNECTION', style: TextStyle(color: Colors.greenAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
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

                          // Since list is reversed:
                          // index 0 is newest, index _messages.length - 1 is oldest.
                          // A date separator belongs above the oldest message of that calendar day.
                          // Chronologically, the message before `i` is `i + 1`.
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
          _buildInputTerminal(isDark),
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

  /// Parses text to render @mentions with highlighted badge styling
  Widget _buildRichMessageText(String content, bool isMe, bool isDark, Color defaultColor) {
    final mentionRegex = RegExp(r'(@[a-zA-Z0-9_\-]+)');
    final matches = mentionRegex.allMatches(content);

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

      final mentionText = match.group(0)!;
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
            mentionText.replaceAll('_', ' '),
            style: TextStyle(
              color: isMe ? Colors.white : Colors.indigoAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ));

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
                  border: InputBorder.none,
                  hintText: 'Type a message or @mention someone...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
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
