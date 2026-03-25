import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HabitTrackerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final VoidCallback onToggle;
  final Color themeColor;
  final List<bool> lastWeekStatus; // For visual streak

  const HabitTrackerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.onToggle,
    this.themeColor = Colors.indigoAccent,
    required this.lastWeekStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withOpacity(isCompleted ? 0.3 : 0.05)),
        boxShadow: isCompleted ? [BoxShadow(color: themeColor.withOpacity(0.05), blurRadius: 20)] : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted ? themeColor : themeColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                    color: isCompleted ? Colors.white : themeColor.withOpacity(0.4),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('STREAK', style: TextStyle(color: themeColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text('7 DAYS', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final done = i < lastWeekStatus.length ? lastWeekStatus[i] : false;
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: done ? themeColor.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: done ? themeColor.withOpacity(0.3) : Colors.transparent),
                ),
                child: Center(
                  child: Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                    style: TextStyle(
                      color: done ? themeColor : (isDark ? Colors.white10 : Colors.black12),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
