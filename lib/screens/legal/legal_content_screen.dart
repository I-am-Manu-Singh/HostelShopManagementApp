import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalContentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalContentScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),
            Text('Last updated: March 2026', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Text(content, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.6)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
