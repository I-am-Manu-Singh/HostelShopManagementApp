import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_of_service_screen.dart';
import '../screens/legal/refund_policy_screen.dart';
import '../screens/legal/safety_protocols_screen.dart';
import '../services/organization_settings_service.dart';

List<String> getRoleLabels(String role, bool isGuest) {
  if (isGuest) {
    return ['SHOP', 'LOGIN'];
  }
  if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
    return ['SHOP', 'CHATS', 'PROFILE'];
  } else if (role == 'staff') {
    return ['TERMINAL', 'TASKS', 'CHATS', 'PROFILE'];
  } else if (role == 'hostel_student') {
    return ['CAMPUS HUB', 'SHOP', 'CHATS', 'PROFILE'];
  } else if (role == 'mess_student') {
    return ['SHOP', 'MESS CARD', 'CHATS', 'PROFILE'];
  } else if (role == 'delivery_partner') {
    return ['DELIVERY', 'CHATS', 'PROFILE'];
  } else if (role == 'farmer_seller') {
    return ['MANDI', 'CHATS', 'PROFILE'];
  } else if (role == 'store_customer') {
    return ['SHOP', 'CHATS', 'PROFILE'];
  }
  return ['SHOP', 'CHATS', 'PROFILE'];
}

class WebHeader extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final bool isGuest;
  final int currentIndex;
  final List<String> labels;
  final ValueChanged<int> onTabSelected;

  const WebHeader({
    super.key,
    required this.userProfile,
    required this.isGuest,
    required this.currentIndex,
    required this.labels,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildHeaderBrand(context, isDark),
          const SizedBox(width: 40),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(labels.length, (index) {
                final bool active = currentIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: active ? Colors.white.withOpacity(0.2) : Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => onTabSelected(index),
                    child: Text(
                      labels[index],
                      style: GoogleFonts.outfit(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                        color: active ? Colors.white : Colors.white.withOpacity(0.75),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _buildHeaderActions(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderBrand(BuildContext context, bool isDark) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.hub_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'H House',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActions(BuildContext context, bool isDark) {
    final profileName = userProfile?['full_name'] ?? 'User';
    return Row(
      children: [
        if (!isGuest) ...[
          Text(
            profileName.toString().toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
        ],
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final int profileIndex = labels.indexOf(
              isGuest ? 'LOGIN' : 'PROFILE',
            );
            if (profileIndex != -1) {
              onTabSelected(profileIndex);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ),
        ),
        if (!isGuest) ...[
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ],
    );
  }
}

class SharedWebFooter extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;

  const SharedWebFooter({
    super.key,
    required this.isDark,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08090A) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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
                      child: _footerPlatform(context, isDark),
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
          'H House',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "H House is India's next-generation Hostel & Campus Super App designed for students, wardens, administrators, stores, mess facilities, farmers, and delivery partners. From room allocation and digital mess cards to campus shopping, mandi marketplace, inventory management, order tracking, and room delivery, everything works together in one intelligent platform.",
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '© ${DateTime.now().year} H House Operations Platform.',
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

  Widget _footerPlatform(BuildContext context, bool isDark) {
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
        _footerLink(context, 'Refund Policy', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundPolicyScreen()));
        }, isDark),
        _footerLink(context, 'Safety Protocols', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyProtocolsScreen()));
        }, isDark),
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
    final org = OrganizationSettingsService();
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
          org.supportEmail,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          org.companyPhone,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          org.companyAddress,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
