import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/shared_web_components.dart';

class WebLandingScreen extends StatelessWidget {
  final VoidCallback onLaunchApp;
  const WebLandingScreen({super.key, required this.onLaunchApp});

  Future<void> _openGoogleForm() async {
    final Uri url = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSd3D3S0LFovzE4NIk9ExznOh5I0jjUyRQ13Bz6DI1SVN_eusg/viewform?usp=header');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _showEnquiryDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final campusCtrl = TextEditingController();
    final reqCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Row(
            children: [
              const Icon(Icons.forum_rounded, color: Colors.indigoAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                'REQUEST A FREE DEMO',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fill in your details below and our campus management specialists will reach out to you within 24 hours.',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 20),
                _buildField('Full Name', nameCtrl, Icons.person_outline_rounded, isDark),
                const SizedBox(height: 12),
                _buildField('Work Email', emailCtrl, Icons.email_outlined, isDark, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildField('Campus / Organization Name', campusCtrl, Icons.school_outlined, isDark),
                const SizedBox(height: 12),
                _buildField('Specific Requirements (Optional)', reqCtrl, Icons.note_alt_outlined, isDark, maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openGoogleForm();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.indigoAccent),
              label: Text('USE GOOGLE FORM', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CLOSE', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || campusCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please fill all required fields.'),
                    backgroundColor: Colors.redAccent,
                  ));
                  return;
                }

                // Insert into DB as Enquiry type Complaint so admins see it inside the app
                try {
                  final client = Supabase.instance.client;
                  final user = client.auth.currentUser;
                  final String uid = user?.id ?? '00000000-0000-0000-0000-00000000000a';

                  await client.from('complaints').insert({
                    'user_id': uid,
                    'type': 'Enquiry',
                    'content': 'Name: ${nameCtrl.text}\nEmail: ${emailCtrl.text}\nCampus: ${campusCtrl.text}\nRequirements: ${reqCtrl.text}',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                } catch (e) {
                  debugPrint('Error inserting contact enquiry: $e');
                }

                if (!context.mounted) return;
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (successCtx) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 48),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'DEMO REGISTERED!',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: Colors.greenAccent),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Thank you for reaching out. We have sent a confirmation email to ${emailCtrl.text}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(successCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigoAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('GREAT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: Text('SUBMIT REQUEST', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff050608) : const Color(0xffFAFBFD),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavBar(context, isDark, isDesktop),
            _buildHero(context, isDark, isDesktop),
            _buildStatistics(context, isDark),
            _buildAppSuiteShowcase(context, isDark, isDesktop),
            _buildDetailedModules(context, isDark, isDesktop),
            _buildEnquirySection(context, isDark, isDesktop),
            SharedWebFooter(isDark: isDark, isDesktop: isDesktop),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _showEnquiryDialog(context),
                child: Text('REQUEST DEMO', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: onLaunchApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('LAUNCH APP', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    Expanded(child: FadeInRight(child: _buildHeroRight(context, isDark))),
                  ],
                )
              : Column(
                  children: [
                    _buildHeroLeft(context, isDark),
                    const SizedBox(height: 48),
                    _buildHeroRight(context, isDark),
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
            'THE ULTIMATE CAMPUS SUPER APP',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.indigoAccent, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Hostel & Campus\nSupercharged.',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 48, height: 1.1, color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 20),
        Text(
          'Automate Boys & Girls Hostels, Cashless Mess Dinings, Smart Canteens, Fresh Mandi Markets, Room Deliveries, Logistics Dispatching, and Universal Ledger Accounting. Enable seamless operations for Students, Managers, Owners, Farmers, and Delivery Agents in a single unified dashboard.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white54 : Colors.black54, height: 1.5),
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
              child: Text('LAUNCH PORTAL', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: () => _showEnquiryDialog(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.indigoAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              child: Text('REQUEST DEMO', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildHeroRight(BuildContext context, bool isDark) {
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
            const Icon(Icons.phonelink_rounded, size: 80, color: Colors.indigoAccent),
            const SizedBox(height: 24),
            Text(
              'Interactive Web & Mobile App',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.white : Colors.black),
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

  Widget _buildStatistics(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 18,
        children: [
          _statCard(context, "30K+", "Daily Active Users", Icons.people_outline_rounded),
          _statCard(context, "120+", "Hostel Blocks Unified", Icons.home_work_outlined),
          _statCard(context, "₹5.2M+", "Cashless Transaction Vol.", Icons.account_balance_wallet_outlined),
          _statCard(context, "99.98%", "Database Connection Uptime", Icons.cloud_done_outlined),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String value, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.indigoAccent, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAppSuiteShowcase(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'THE COMPLETE SUITE',
            style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Dynamic Services For All Stakeholders',
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 48),
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.4,
            children: [
              _featureCard(
                  'Smart Mess & Cashless Dining',
                  'Digital Mess Cards (NFC/Biometrics sync), live dining calendars, schedules, automatic billing ledgers, and in-app wallet balance recharges.',
                  Icons.restaurant_rounded,
                  Colors.orangeAccent,
                  isDark),
              _featureCard(
                  'Boys & Girls Hostel Life',
                  'Room checkout flows, checklist management, roommate synchronization, digital outpasses, security logs, and repairs inspections tracker.',
                  Icons.apartment_rounded,
                  Colors.purpleAccent,
                  isDark),
              _featureCard(
                  'Unified E-Commerce',
                  'Browse Campus Canteens and Mandi Produce. Add custom delivery parameters (night fee, delivery tips), apply coupon codes, and get live status.',
                  Icons.shopping_bag_rounded,
                  Colors.greenAccent,
                  isDark),
              _featureCard(
                  'Logistics & Fleet Console',
                  'Delivery agents view dispatches, track destination coordinates, upload delivery receipts, and complete deliveries with dynamic payout logs.',
                  Icons.delivery_dining_rounded,
                  Colors.blueAccent,
                  isDark),
              _featureCard(
                  'Farmer Rates Marketplace',
                  'Mandi sellers and local farmers list their fresh items, manage wholesale prices, coordinate pickups, and audit their transaction records.',
                  Icons.agriculture_rounded,
                  Colors.green,
                  isDark),
              _featureCard(
                  'Universal Ledger Accounting',
                  'Integrated lending books (Khata), student ledger transaction listings, invoice generating engine, and dual-layer authorization controls.',
                  Icons.menu_book_rounded,
                  Colors.deepPurpleAccent,
                  isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _featureCard(String title, String desc, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1113) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildDetailedModules(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      color: isDark ? const Color(0xFF090A0C) : const Color(0xFFF3F4F6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'APP ARCHITECTURE',
                style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              Text(
                'Powering Every Corner of the Campus',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 56),
              _buildDetailedRow(
                context,
                isDark,
                isDesktop,
                'STUDENT TERMINAL & HOSTELS',
                'Seamless Room Bookings & Checklist Operations',
                'Students can inspect real-time hostel room vacancies, review details like room layouts, amenities, base pricing, and complete checkout bookings with mock payment options.\n\nPre-allotment checklists and outpasses sync directly with warden dashboards for real-time security approvals, minimizing physical gate logs.',
                Icons.grid_view_rounded,
                false,
              ),
              const SizedBox(height: 64),
              _buildDetailedRow(
                context,
                isDark,
                isDesktop,
                'FINANCIAL CONTROL & KHATA',
                'Dual-Layer Authorized Lending Ledger',
                'Integrated Transaction Ledger tracks every student, shop purchase, and utility bill. Wardens and administrators write lending items with custom descriptions and verify credits.\n\nStrict owner and manager privileges partition access so that payroll, ledger reports, and personnel profiles are locked behind owner credentials.',
                Icons.account_balance_wallet_rounded,
                true,
              ),
              const SizedBox(height: 64),
              _buildDetailedRow(
                context,
                isDark,
                isDesktop,
                'FLEET CONTROL & UTILITIES',
                'Integrated Logistics and Meter Readings Matrix',
                'Delivery agents manage and accept dispatches with live address mapping and one-tap receipt downloads.\n\nManagers use the power reading matrix to manage starting meter points for hostel blocks, perform utility checks, and automate monthly electricity bills based on tariff rates.',
                Icons.bolt_rounded,
                false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedRow(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    String tag,
    String heading,
    String description,
    IconData icon,
    bool reverse,
  ) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.indigoAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              tag,
              style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          heading,
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, height: 1.5),
        ),
      ],
    );

    final graphics = Container(
      height: 250,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Center(
        child: Icon(icon, size: 64, color: Colors.indigoAccent.withOpacity(0.2)),
      ),
    );

    if (!isDesktop) {
      return Column(
        children: [
          graphics,
          const SizedBox(height: 24),
          content,
        ],
      );
    }

    return Row(
      children: [
        if (reverse) ...[
          Expanded(child: graphics),
          const SizedBox(width: 64),
          Expanded(child: content),
        ] else ...[
          Expanded(child: content),
          const SizedBox(width: 64),
          Expanded(child: graphics),
        ]
      ],
    );
  }

  Widget _buildEnquirySection(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.indigoAccent, Colors.pinkAccent]),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Modernize Your Campus?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Book a 15-minute product walk-through and learn how we can help you streamline operations, digitize canteen payments, and automate visitor gate outpasses.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showEnquiryDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            child: Text('REQUEST A DEMO', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
