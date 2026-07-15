import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'app_info_screen.dart';

class WebLandingScreen extends StatelessWidget {
  final VoidCallback onLaunchApp;
  const WebLandingScreen({super.key, required this.onLaunchApp});

  Future<void> _openGoogleForm() async {
    final Uri url = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSd3D3S0LFovzE4NIk9ExznOh5I0jjUyRQ13Bz6DI1SVN_eusg/viewform?usp=header');
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
      backgroundColor:
isDark
    ? const Color(0xff050608)
    : const Color(0xffFAFBFD),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Responsive Navbar
            _buildNavBar(context, isDark, isDesktop),
            
            // Hero Section
            _buildHero(context, isDark, isDesktop),
            Container(
  padding: const EdgeInsets.symmetric(
    vertical: 40,
    horizontal: 40,
  ),
  child: Wrap(
    alignment: WrapAlignment.center,
    spacing: 18,
    runSpacing: 18,
    children: [
      _statCard("15K+", "Students"),
      _statCard("500+", "Hostels"),
      _statCard("120K+", "Orders"),
      _statCard("99.8%", "Uptime"),
    ],
  ),
),
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
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 120),
decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [
            const Color(0xff050608),
            const Color(0xff111827),
            const Color(0xff1E1B4B),
          ]
        : [
            Colors.white,
            const Color(0xffEEF2FF),
            const Color(0xffF8FAFC),
          ],
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
          'THE ALL-IN-ONE HOSTEL & CAMPUS SUPER APP',
            style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 24),
        Text(
         'Hostel Life.\nReimagined.',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 48, height: 1.1, color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 20),
        Text(
          'Campus Connect brings together Boys Hostels, Girls Hostels, Mess Cards, Campus Stores, Mandi Supermarkets, Room Delivery, Hostel Inventory, Order Tracking, Student Productivity, Digital Payments, and Real-Time Campus Operations into one seamless platform.',
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
              child: Text('BOOK A DEMO', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        )
      ],
    );
  }
Widget _statCard(String value, String label) {
  return Container(
    width: 170,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.indigoAccent.withOpacity(.05),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    ),
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
             'One App. Every Campus Service.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            Text(
              'Students • Wardens • Staff • Stores • Farmers • Delivery Partners',
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
            'EVERYTHING YOU NEED',
            style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Designed for Modern Student Life',
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
              _featureCard('SMART MESS', 'Digital mess cards, QR check-ins, meal attendance, menu updates, recharge history, and cashless dining.', Icons.restaurant_rounded, Colors.orangeAccent, isDark),
              _featureCard('HOSTEL LIFE', 'Room allocation, roommate details, maintenance requests, visitor approvals, notices, attendance, and hostel inventory.', Icons.apartment_rounded, Colors.purpleAccent, isDark),
              _featureCard('CAMPUS MARKETPLACE', 'Campus Shop, Fresh Mandi, groceries, fruits, vegetables, snacks, medicines, stationery, and hostel room delivery.', Icons.agriculture_rounded, Colors.greenAccent, isDark),
              _featureCard(
  'ROOM DELIVERY',
  'Order groceries, meals, stationery, daily essentials, and receive them directly at your hostel room.',
  Icons.delivery_dining_rounded,
  Colors.blueAccent,
  isDark,
),
_featureCard(
  'ORDER TRACKING',
  'Track every order in real time with live delivery updates, digital invoices, and secure payments.',
  Icons.local_shipping_rounded,
  Colors.green,
  isDark,
),
_featureCard(
  'STORE MANAGEMENT',
  'Inventory management, billing, stock analytics, supplier management, delivery partners, and automated order processing.',
  Icons.inventory_2_rounded,
  Colors.deepPurpleAccent,
  isDark,
),
            
            
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
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      isDark
          ? Colors.white.withOpacity(.05)
          : Colors.white,
      Colors.transparent,
    ],
  ),  
  borderRadius: BorderRadius.circular(32),
  border: Border.all(
    color: isDark
        ? Colors.white12
        : Colors.black12,
  ),
  boxShadow: [],
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
           'Transform Your Hostel Into a Smart Campus',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Whether you manage a Boys Hostel, Girls Hostel, College Campus, University Mess, Student Store, Campus Supermarket, or Mandi Marketplace, Campus Connect helps automate operations, improve student experience, and simplify daily management.',
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

Widget _buildFooter(
  BuildContext context,
  bool isDark,
  bool isDesktop,
) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF08090A) : const Color(0xFFF1F5F9),
      border: Border(
        top: BorderSide(
          color: isDark
              ? Colors.white10
              : Colors.black.withOpacity(0.05),
        ),
      ),
    ),
    child: Column(
      children: [
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _footerAbout(isDark),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: _footerPlatform(
                      context,
                      isDark,
                    ),
                  ),
                  Expanded(
                    child: _footerContact(isDark),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _footerAbout(isDark),
                  const SizedBox(height: 30),
                  _footerPlatform(context, isDark),
                  const SizedBox(height: 30),
                  _footerContact(isDark),
                ],
              ),

     
      ],
    ),
  );
}

Widget _footerAbout(bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'CAMPUS CONNECT',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        "Campus Connect is India's next-generation Hostel & Campus Super App designed for students, wardens, administrators, stores, mess facilities, farmers, and delivery partners. From room allocation and digital mess cards to campus shopping, mandi marketplace, inventory management, order tracking, and room delivery, everything works together in one intelligent platform.",
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.black54,
          fontSize: 13,
          height: 1.6,
        ),
      ),

        const SizedBox(height: 12),

        Text(
          '© ${DateTime.now().year} Campus Connect Operations Platform.',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

     
        const SizedBox(height: 8),

        Text(
          'Developed by Manpreet Singh',
          style: TextStyle(
            color: isDark ? Colors.white30 : Colors.black38,
            fontSize: 11,
          ),
        ),
    ],
  );
}

  Widget _footerPlatform(
    BuildContext context,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        _footerLink(context, 'Privacy Policy', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
        }, isDark),
        _footerLink(context, 'Terms & Conditions', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
        }, isDark),
        _footerLink(context, 'Support', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AppInfoScreen()));
        }, isDark),
        // _footerLink(context, 'Help Center', () {
        //   Navigator.push(context, MaterialPageRoute(builder: (_) => const AppInfoScreen()));
        // }, isDark),
      ],
    );
  }

  Widget _footerLink(BuildContext context, String text, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

Widget _footerContact(bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Get In Touch',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'support@campusconnect.com',
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.black54,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '+91 XXXXX XXXXX',
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.black54,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'India',
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.black54,
          fontSize: 12,
        ),
      ),
    ],
  );
}
}
