import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';

class WebLandingScreen extends StatelessWidget {
  final VoidCallback onLaunchApp;
  const WebLandingScreen({super.key, required this.onLaunchApp});

  Future<void> _openGoogleForm() async {
    final Uri url = Uri.parse('https://docs.google.com/forms');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Responsive Navbar
            _buildNavBar(context, isDark, isDesktop),
            
            // Hero Section
            _buildHero(context, isDark, isDesktop),
            
            // Features Grid
            _buildFeatures(context, isDark, isDesktop),
            
            // Enquiry Section
            _buildEnquirySection(context, isDark, isDesktop),
            
            // Footer
            _buildFooter(context, isDark, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08090A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: Colors.indigoAccent, size: 28),
              const SizedBox(width: 12),
              Text(
                'CAMPUS CONNECT',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: _openGoogleForm,
                child: Text('ENQUIRY FORM', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigoAccent)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: onLaunchApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('LAUNCH APP', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF08090A), const Color(0xFF16181A)]
            : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop 
            ? Row(
                children: [
                  Expanded(child: _buildHeroLeft(context, isDark)),
                  Expanded(child: FadeInRight(child: _buildHeroRight(isDark))),
                ],
              )
            : Column(
                children: [
                  _buildHeroLeft(context, isDark),
                  const SizedBox(height: 48),
                  _buildHeroRight(isDark),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildHeroLeft(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.indigoAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            'THE ULTIMATE CAMPUS OPERATING SYSTEM',
            style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Smart Operations,\nSeamless Logistics.',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 48, height: 1.1, color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 20),
        Text(
          'Empowering students, hostel managers, mess staff, and mandi suppliers with integrated logistics, real-time dining audits, room booking automation, and instant shop inventories.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            ElevatedButton(
              onPressed: onLaunchApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              child: Text('GET STARTED', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: _openGoogleForm,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.indigoAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              child: Text('SUBMIT ENQUIRY', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildHeroRight(bool isDark) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.indigoAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.devices_rounded, size: 80, color: Colors.indigoAccent),
            const SizedBox(height: 24),
            Text(
              'Interactive Web Console',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            Text(
              'Supports Chrome, Safari, Android & iOS',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'INTEGRATED MODULES',
            style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Engineered for High-Velocity Operation',
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 48),
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.5,
            children: [
              _featureCard('MESS AUDITING', 'Track attendance, manage NFC smart dining cards, and inspect daily menus.', Icons.restaurant_rounded, Colors.orangeAccent, isDark),
              _featureCard('HOUSING HUB', 'Real-time room allotment registry, building blocks inspections, and complaints desk.', Icons.apartment_rounded, Colors.purpleAccent, isDark),
              _featureCard('MANDI LOGISTICS', 'Bulk crop imports, farmer listing exports, weight multiplier sales, and delivery routing.', Icons.agriculture_rounded, Colors.greenAccent, isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _featureCard(String title, String desc, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildEnquirySection(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 48),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.indigoAccent, Colors.pinkAccent]),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Text(
            'Partner with Campus Connect',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Looking to digitize your hostel, campus stores, mess halls or agricultural markets? Get in touch with us.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _openGoogleForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            child: Text('FILL ENQUIRY FORM', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Center(
        child: Text(
          '© 2026 Campus Connect. All rights reserved.',
          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
        ),
      ),
    );
  }
}
