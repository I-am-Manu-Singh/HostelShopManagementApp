import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EisenhowerMatrix extends StatelessWidget {
  final List<dynamic> tasks;
  const EisenhowerMatrix({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter tasks into quadrants
    final q1 = tasks.where((t) => t['priority'] == 'high' && (t['is_urgent'] ?? true)).toList();
    final q2 = tasks.where((t) => t['priority'] == 'high' && !(t['is_urgent'] ?? true)).toList();
    final q3 = tasks.where((t) => t['priority'] != 'high' && (t['is_urgent'] ?? true)).toList();
    final q4 = tasks.where((t) => t['priority'] != 'high' && !(t['is_urgent'] ?? true)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EISENHOWER MATRIX', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        Container(
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildQuadrant('DO FIRST', 'Urgent & Important', q1, Colors.redAccent, isDark, true, true),
                    _buildQuadrant('SCHEDULE', 'Important, Not Urgent', q2, Colors.orangeAccent, isDark, true, false),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    _buildQuadrant('DELEGATE', 'Urgent, Not Important', q3, Colors.blueAccent, isDark, false, true),
                    _buildQuadrant('ELIMINATE', 'Not Urgent or Important', q4, Colors.grey, isDark, false, false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrant(String title, String subtitle, List<dynamic> items, Color color, bool isDark, bool isTop, bool isLeft) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: isLeft ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none,
            bottom: isTop ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(subtitle, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty 
                ? Center(child: Icon(Icons.blur_on_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 24))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(items[i]['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 9, decoration: items[i]['is_completed'] == true ? TextDecoration.lineThrough : null))),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
