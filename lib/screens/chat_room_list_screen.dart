import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'chat_screen.dart';

class CampusChatListScreen extends StatelessWidget {
  const CampusChatListScreen({super.key});

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

    final bodyContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 32),
          Text('Conversations', style: GoogleFonts.outfit(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  child: _buildChatRoomTile(context, room, isDark),
                );
              },
            ),
          ),
        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.indigoAccent.withOpacity(0.1),
          radius: 25,
          child: Icon(
  room['isGroup'] ? Icons.groups_rounded : Icons.person_rounded,
  color: Colors.indigoAccent,
),),
        title: Text(room['title'], style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(room['subtitle'], style: GoogleFonts.outfit(color: subColor, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampusChatScreen(
                roomId: room['id'] as String,
                title: room['title'] as String,
              ),
            ),
          );
        },
      ),
    );
  }
}
