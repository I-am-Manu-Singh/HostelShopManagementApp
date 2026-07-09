import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'legal/refund_policy_screen.dart';
import 'legal/safety_protocols_screen.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  final String companyName = "Hostel Shop Management";
  final String phoneNumber = "+91 800 123 4567";
  final String supportEmail = "support@hostelshop.com";
  final String website = "https://hostelshopmanagement.com";
  final String version = "1.0.0-Stable";

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('APP INFO', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            FadeInDown(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.pinkAccent.withOpacity(0.1)),
                    boxShadow: isDark ? [BoxShadow(color: Colors.pinkAccent.withOpacity(0.05), blurRadius: 40)] : [],
                  ),
                  child: const Icon(Icons.hub_rounded, size: 80, color: Colors.pinkAccent),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              child: Column(
                children: [
                   Text(companyName, style: GoogleFonts.outfit(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text('Version $version', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _smallActionBtn(
                  icon: Icons.share_rounded,
                  label: 'Share App',
                  isDark: isDark,
                  onTap: () => Share.share('Download Hostel Shop Management App at $website'),
                ),
                const SizedBox(width: 12),
                _smallActionBtn(
                  icon: Icons.star_rounded,
                  label: 'Rate App',
                  isDark: isDark,
                  onTap: () => _launchUrl(website),
                ),
              ],
            ),

            const SizedBox(height: 48),
            _buildSectionTitle('CONTACT US', Colors.indigoAccent, isDark),
            const SizedBox(height: 16),
            _infoTile(Icons.phone_enabled_rounded, 'Call Support', phoneNumber, () => _launchUrl('tel:$phoneNumber'), Colors.indigoAccent, isDark),
            _infoTile(Icons.alternate_email_rounded, 'Email Support', supportEmail, () => _launchUrl('mailto:$supportEmail'), Colors.indigoAccent, isDark),
            _infoTile(Icons.language_rounded, 'Visit Website', website, () => _launchUrl(website), Colors.indigoAccent, isDark),
            
            const SizedBox(height: 40),
            _buildSectionTitle('LEGAL', Colors.pinkAccent, isDark),
            const SizedBox(height: 16),
            _infoTile(Icons.security_rounded, 'Privacy Policy', 'Data protection rules', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
            }, Colors.pinkAccent, isDark),
            _infoTile(Icons.gavel_rounded, 'Terms of Service', 'Usage agreements', () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
            }, Colors.pinkAccent, isDark),
            _infoTile(Icons.monetization_on_rounded, 'Refund Policy', 'Payment & returns', () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundPolicyScreen()));
            }, Colors.pinkAccent, isDark),
            _infoTile(Icons.health_and_safety_rounded, 'Safety Protocols', 'Hostel guidelines', () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyProtocolsScreen()));
            }, Colors.pinkAccent, isDark),
            
            const SizedBox(height: 60),
            Text('© 2026 Campus Hub Operations', style: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color, bool isDark) {
    return FadeInLeft(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(width: 4, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value, VoidCallback onTap, Color color, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(title, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
          subtitle: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
          trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 20),
        ),
      ),
    );
  }

  Widget _smallActionBtn({required IconData icon, required String label, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }
}
