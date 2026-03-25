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

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
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
                        padding: const EdgeInsets.all(24),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _buildMessageBubble(_messages[i], isDark),
                      ),
              ],
            ),
          ),
          _buildInputTerminal(isDark),
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
    final time = m['created_at'] != null ? DateFormat('HH:mm').format(DateTime.parse(m['created_at'])) : '--:--';
    final textColor = isDark ? Colors.white : Colors.black;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(profile?['full_name'] ?? 'User', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 20),
                ),
                border: Border.all(color: isMe ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Text(m['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : textColor, fontSize: 13, fontWeight: isMe ? FontWeight.w600 : FontWeight.normal)),
            ),
            const SizedBox(height: 6),
            Text(time, style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 7, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTerminal(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(25), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
              child: TextField(
                controller: _msgCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(border: InputBorder.none, hintText: 'Type a message...', hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    final txt = _msgCtrl.text.trim();
    _msgCtrl.clear();
    try {
      await _client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': _client.auth.currentUser!.id,
        'content': txt,
      });
      // Optionally re-fetch if realtime is slow
      _fetchMessages();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SEND_FAILURE: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }
}
