import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_of_service_screen.dart';
import '../screens/legal/refund_policy_screen.dart';
import '../screens/legal/safety_protocols_screen.dart';

List<String> getRoleLabels(String role, bool isGuest) {
  if (isGuest) {
    return ['CAMPUS SHOP', 'MANDI MARKET', 'FAST FOOD', 'LOGIN'];
  }
  if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
    return ['CAMPUS SHOP', 'MANDI MARKET', 'FAST FOOD', 'FINANCES', 'CHATS', 'PROFILE'];
  } else if (role == 'staff') {
    return ['EMPLOYEE TERMINAL', 'WORKPLACE', 'FAST FOOD', 'TASKS', 'CHATS', 'PROFILE'];
  } else if (role == 'hostel_student') {
    return ['TERMINAL', 'CAMPUS SHOP', 'MANDI MARKET', 'FAST FOOD', 'SUITE', 'CHATS', 'PROFILE'];
  } else if (role == 'mess_student') {
    return ['CAMPUS SHOP', 'MANDI MARKET', 'FAST FOOD', 'MESS CARD', 'CHATS', 'PROFILE'];
  } else if (role == 'delivery_partner') {
    return ['LOGISTICS', 'FAST FOOD', 'CHATS', 'PROFILE'];
  } else if (role == 'farmer_seller') {
    return ['MARKET', 'FAST FOOD', 'CHATS', 'PROFILE'];
  }
  return ['CAMPUS SHOP', 'MANDI MARKET', 'FAST FOOD', 'PROFILE'];
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08090A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextButton(
                    onPressed: () => onTabSelected(index),
                    child: Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: active
                                ? Colors.indigoAccent
                                : (isDark ? Colors.white70 : Colors.black87),
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
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.hub_rounded,
              color: Colors.indigoAccent,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'CAMPUS CONNECT',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: isDark ? Colors.white : Colors.black,
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(width: 12),
        ],
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.notifications_none_rounded,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(width: 12),
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
                color: Colors.indigoAccent,
                width: 1.5,
              ),
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
