import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CampusInquiryScreen extends StatefulWidget {
  const CampusInquiryScreen({super.key});

  @override
  State<CampusInquiryScreen> createState() => _CampusInquiryScreenState();
}

class _CampusInquiryScreenState extends State<CampusInquiryScreen> {
  final _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'sender': 'AI', 'text': 'Greetings! I am the Campus Assistant. How may I assist your operations today?', 'time': 'Just now'}
  ];
  bool _isTyping = false;

  void _sendMessage(String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'sender': 'USER', 'text': text, 'time': 'Just now'});
      _msgController.clear();
      _isTyping = true;
    });

    // Simulated AI response
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({'sender': 'AI', 'text': _getMockResponse(text), 'time': 'Just now'});
        });
      }
    });
  }

  String _getMockResponse(String query) {
    query = query.toLowerCase();
    if (query.contains('rent')) return 'You can view your current rent status in the Finance section of your profile.';
    if (query.contains('mess')) return 'Mess attendance is currently 84% active. Your last log was at 8:15 AM today.';
    if (query.contains('shop')) return 'The Campus Express is open 24/7. New protein stocks arrived 2 hours ago.';
    return 'I have forwarded your request to the Campus Manager. They will respond within 24 hours.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('CAMPUS INTELLIGENCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.history_rounded, color: Colors.white24), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          if (_isTyping) Padding(padding: const EdgeInsets.only(left: 24, bottom: 8), child: FadeIn(child: Text('Campus AI is analyzing...', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)))),
          _buildQuickActions(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isAI = msg['sender'] == 'AI';
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isAI) _avatarMini(Icons.auto_awesome, Colors.indigoAccent),
            const SizedBox(width: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAI ? Colors.white.withOpacity(0.04) : Colors.indigoAccent,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isAI ? 0 : 20),
                    bottomRight: Radius.circular(isAI ? 20 : 0),
                  ),
                  border: isAI ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
                ),
                child: Text(msg['text'], style: GoogleFonts.outfit(color: isAI ? Colors.white.withOpacity(0.9) : Colors.white, fontSize: 14, height: 1.5)),
              ),
            ),
            const SizedBox(width: 12),
            if (!isAI) _avatarMini(Icons.person_outline, Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _avatarMini(IconData icon, Color bg) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: bg, size: 16));
  }

  Widget _buildQuickActions() {
    final list = ['Rent Status', 'Mess Menu', 'Shop Inventory', 'Support'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: list.map((l) => GestureDetector(
          onTap: () => _sendMessage(l),
          child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
        )).toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: TextField(
                  controller: _msgController,
                  onSubmitted: _sendMessage,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Ask anything...', hintStyle: const TextStyle(color: Colors.white24, fontSize: 14), prefixIcon: const Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 18), filled: true, fillColor: Colors.white.withOpacity(0.03), border: InputBorder.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _iconBtn(Icons.send_rounded, () => _sendMessage(_msgController.text)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.35), blurRadius: 15)]), child: Icon(icon, color: Colors.white, size: 20)));
  }
}
