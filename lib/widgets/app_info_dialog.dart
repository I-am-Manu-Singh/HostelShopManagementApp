import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppInfoDialog extends StatelessWidget {
  final String appName;
  final String appVersion;
  final String appTagline;
  final String appDescription;
  final List<String> highlights;

  const AppInfoDialog({
    super.key,
    this.appName = 'Hostel & Campus Mart',
    this.appVersion = '1.0.0 (Production Release)',
    this.appTagline = 'Smart Living & Campus Commerce Command',
    this.appDescription =
        'An enterprise-grade campus ecosystem engineered to streamline hostel resident living, automated room logistics, mess subscriptions, and high-speed store POS billing.',
    this.highlights = const [
      'High-Speed Barcode & POS Billing Engine',
      'Real-Time Resident Chat & Incident Tagging',
      'Adaptive Tablet & Landscape Navigation Rail',
      '100% Offline-Resilient Architecture',
      'End-to-End Enterprise Data Encryption',
    ],
  });

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = const Color(0xFFEAB308);
    final bgSurface = isDark ? const Color(0xFF131826) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Creative Bliss Labs Hero Branding Container (Matching NitnemGuktaSteek)
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF1A2238) : const Color(0xFFF1F5F9),
              border: Border.all(color: goldColor.withOpacity(0.55), width: 2),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/creative_bliss_labs_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.verified_rounded, size: 44, color: goldColor),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // App Title
          Text(
            appName,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),

          // Version badge
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: goldColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: goldColor.withOpacity(0.4)),
            ),
            child: Text(
              'v$appVersion • 100% Ad-Free',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: goldColor,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Creative Bliss Labs Subtitle
          Text(
            'Developed with Seva by Creative Bliss Labs',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 14),

          Divider(color: goldColor.withOpacity(0.2), height: 1),
          const SizedBox(height: 14),

          // Description
          Text(
            appDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Highlights
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: highlights.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: goldColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Action / Contact
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.thumb_up_rounded, size: 16),
                  label: const Text('App Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
