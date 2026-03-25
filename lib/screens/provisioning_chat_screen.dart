import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class ProvisioningChatScreen extends StatefulWidget {
  const ProvisioningChatScreen({super.key});

  @override
  State<ProvisioningChatScreen> createState() => _ProvisioningChatScreenState();
}

class _ProvisioningChatScreenState extends State<ProvisioningChatScreen> {
  final _client = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  
  List<dynamic> _messages = [];
  List<dynamic> _staffList = [];
  bool _showMentions = false;
  List<dynamic> _filteredMentions = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _fetchStaff();
    _subscribeToMessages();
  }

  Future<void> _fetchMessages() async {
    final res = await _client.from('group_messages').select('*, profiles(*)').order('created_at', ascending: false);
    if (mounted) setState(() => _messages = res);
  }

  Future<void> _fetchStaff() async {
    final res = await _client.from('profiles').select().inFilter('role', ['staff', 'admin']);
    if (mounted) setState(() => _staffList = res);
  }

  void _subscribeToMessages() {
    _client.channel('public:group_messages').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'group_messages', callback: (payload) => _fetchMessages()).subscribe();
  }

  void _handleMention(String val) {
    if (val.contains('@')) {
       String query = val.split('@').last.toLowerCase();
       setState(() {
         _showMentions = true;
         _filteredMentions = _staffList.where((s) => s['full_name'].toString().toLowerCase().contains(query)).toList();
       });
    } else {
       setState(() => _showMentions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('LOGISTICS COLLECTIVE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildBackgroundOrbs(),
                ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(24),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
                ),
                if (_showMentions && _filteredMentions.isNotEmpty)
                  Positioned(bottom: 0, left: 24, right: 24, child: _buildMentionOverlay()),
              ],
            ),
          ),
          _buildInputTerminal(),
        ],
      ),
    );
  }

  Widget _buildMentionOverlay() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigoAccent)),
      child: Column(mainAxisSize: MainAxisSize.min, children: _filteredMentions.map((s) => ListTile(dense: true, leading: CircleAvatar(radius: 12, child: Text(s['full_name'][0])), title: Text(s['full_name'], style: const TextStyle(color: Colors.white, fontSize: 12)), onTap: () => _applyMention(s['full_name']))).toList()),
    );
  }

  void _applyMention(String name) {
    String txt = _msgCtrl.text;
    _msgCtrl.text = txt.substring(0, txt.lastIndexOf('@')) + '@$name ';
    setState(() => _showMentions = false);
  }

  Widget _buildMessageBubble(dynamic m) {
    bool isMe = m['sender_id'] == _client.auth.currentUser!.id;
    bool isGrocery = m['is_grocery_list'] ?? false;
    final profile = m['profiles'];

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
               if (!isMe) CircleAvatar(radius: 10, child: Text(profile?['full_name']?[0] ?? 'U', style: const TextStyle(fontSize: 8))),
               const SizedBox(width: 8),
               Text(profile?['full_name'] ?? 'TERMINAL_USER', style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: BoxDecoration(
                color: isGrocery ? Colors.amberAccent.withOpacity(0.1) : (isMe ? Colors.indigoAccent.withOpacity(0.1) : Colors.white.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isGrocery ? Colors.amberAccent.withOpacity(0.3) : (isMe ? Colors.indigoAccent.withOpacity(0.3) : Colors.white10)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isGrocery) const Row(children: [Icon(Icons.shopping_basket_outlined, color: Colors.amberAccent, size: 14), SizedBox(width: 8), Text('GROCERY_PROVISION', style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900))]),
                if (isGrocery) const SizedBox(height: 8),
                Text(m['message_text'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (m['attachments'] != null && (m['attachments'] as List).isNotEmpty) ...[
                   const SizedBox(height: 12),
                   ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(m['attachments'][0], height: 150, width: double.infinity, fit: BoxFit.cover)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTerminal() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.indigoAccent), onPressed: () {}),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white10)),
              child: TextField(
                controller: _msgCtrl,
                onChanged: _handleMention,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(border: InputBorder.none, hintText: 'INITIATE COLLECTIVE UPDATE...', hintStyle: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
     if (_msgCtrl.text.isEmpty) return;
     bool isGrocery = _msgCtrl.text.toLowerCase().contains('buy') || _msgCtrl.text.toLowerCase().contains('need');
     try {
       await _client.from('group_messages').insert({
         'sender_id': _client.auth.currentUser!.id,
         'message_text': _msgCtrl.text,
         'is_grocery_list': isGrocery,
       });
       _msgCtrl.clear();
       setState(() => _showMentions = false);
     } catch (_) {}
  }

  Widget _buildBackgroundOrbs() => Positioned(top: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
}
