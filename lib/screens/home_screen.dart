import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'shop_browse_screen.dart';
import 'profile_screen.dart';
import 'student/student_terminal_screen.dart';
import 'admin/admin_panel_screen.dart';
import 'admin/admin_order_control_screen.dart';
import 'student/mess_student_card_screen.dart';
import 'productivity_suite_hub.dart';
import 'employee/staff_task_hub_screen.dart';
import 'chat_room_list_screen.dart';
import 'admin/admin_finance_hub_screen.dart';
import 'mandi/mandi_seller_screen.dart';
import 'mandi/mandi_delivery_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'app_info_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService().fetchUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  List<Widget> _getPages(String role) {
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [
        AdminPanelScreen(),
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        AdminFinanceHubScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'staff') {
      return [
        ProductivitySuiteHub(),
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        StaffTaskHubScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'hostel_student' || role == 'mess_student') {
      return [
        StudentTerminalScreen(),
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        ProductivitySuiteHub(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'delivery_partner') {
      return [
        const MandiDeliveryScreen(),
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        CampusChatListScreen(),
        const ProfileScreen(),
      ];
    } else if (role == 'farmer_seller') {
      return [
        const MandiSellerScreen(),
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        CampusChatListScreen(),
        const ProfileScreen(),
      ];
    }
    
    // Guest Mode Pages
    if (widget.isGuest) {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        const LoginScreen(),
      ];
    }
    
    // Default for store_customer or others
    return [
      const ShopBrowseScreen(isMandiMode: false),
      const ShopBrowseScreen(isMandiMode: true),
      const ProfileScreen(),
    ];
  }

  List<IconData> _getIcons(String role) {
    if (widget.isGuest) {
      return [Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.login_rounded];
    }
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [Icons.grid_view_rounded, Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.receipt_long_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'staff') {
      return [Icons.psychology_outlined, Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.pending_actions_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'hostel_student' || role == 'mess_student') {
      return [Icons.grid_view_rounded, Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.psychology_outlined, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'delivery_partner') {
      return [Icons.local_shipping_rounded, Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'farmer_seller') {
      return [Icons.agriculture_rounded, Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    }
    return [Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.person_outline_rounded];
  }

  List<String> _getLabels(String role) {
    if (widget.isGuest) {
      return ['CAMPUS SHOP', 'MANDI MARKET', 'LOGIN'];
    }
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return ['DASHBOARD', 'CAMPUS SHOP', 'MANDI MARKET', 'FINANCES', 'CHATS', 'PROFILE'];
    } else if (role == 'staff') {
      return ['WORKPLACE', 'CAMPUS SHOP', 'MANDI MARKET', 'TASKS', 'CHATS', 'PROFILE'];
    } else if (role == 'hostel_student' || role == 'mess_student') {
      return ['TERMINAL', 'CAMPUS SHOP', 'MANDI MARKET', 'SUITE', 'CHATS', 'PROFILE'];
    } else if (role == 'delivery_partner') {
      return ['LOGISTICS', 'CAMPUS SHOP', 'MANDI MARKET', 'CHATS', 'PROFILE'];
    } else if (role == 'farmer_seller') {
      return ['MARKET', 'CAMPUS SHOP', 'MANDI MARKET', 'CHATS', 'PROFILE'];
    }
    return ['CAMPUS SHOP', 'MANDI MARKET', 'PROFILE'];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
      );
    }

    final role = _userProfile?['role'] ?? 'store_customer';
    final pages = _getPages(role);
    final icons = _getIcons(role);
    final labels = _getLabels(role);

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            _buildWebHeader(context),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
            if (!(widget.isGuest && _currentIndex == pages.length - 1))
              _buildWebFooter(context, isDark, MediaQuery.of(context).size.width > 800),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomBar(icons, isDark),
    );
  }

Widget _buildWebHeader(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final String role = (_userProfile?['role'] ?? '').toString();
  final List<String> labels = _getLabels(role);

  return Container(
    height: 48, // Optimize height to match app bar size
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF08090A) : Colors.white, // Match appBarTheme background
      border: Border(
        bottom: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
    ),
    child: Row(
      children: [
        _buildHeaderBrand(isDark),
        const SizedBox(width: 40),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(labels.length, (index) {
              final bool active = _currentIndex == index;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextButton(
                  onPressed: () {
                    setState(() => _currentIndex = index);
                  },
                  child: Text(
                    labels[index],
                    style: GoogleFonts.outfit(
                      fontSize: 13,
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
        _buildHeaderActions(isDark, labels),
      ],
    ),
  );
}

Widget _buildHeaderBrand(bool isDark) {
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
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 1,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    ],
  );
}

Widget _buildHeaderActions(
  bool isDark,
  List<String> labels,
) {
  final profileName = _userProfile?['full_name'] ?? 'User';
  return Row(
    children: [
      if (!widget.isGuest) ...[
        Text(
          profileName.toString().toUpperCase(),
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 11,
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
            widget.isGuest ? 'LOGIN' : 'PROFILE',
          );

          if (profileIndex != -1) {
            setState(() => _currentIndex = profileIndex);
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
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.indigoAccent.withOpacity(.1),
            backgroundImage: (!widget.isGuest && _userProfile?['avatar_url'] != null)
                ? NetworkImage(
                    _userProfile!['avatar_url'],
                  )
                : null,
            child: (widget.isGuest || _userProfile?['avatar_url'] == null)
                ? Text(
                    widget.isGuest
                        ? 'G'
                        : (_userProfile?['full_name'] ?? 'U')
                            .toString()[0]
                            .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.indigoAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
        ),
      ),
      if (!widget.isGuest) ...[
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


Widget _buildWebFooter(
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
          Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()));
        }, isDark),
        _footerLink(context, 'Terms & Conditions', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TermsOfServiceScreen()));
        }, isDark),
        _footerLink(context, 'Support', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AppInfoScreen()));
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
  Widget _buildBottomBar(List<IconData> icons, bool isDark) {
    return Container(
      height: 70, 
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          icons.length,
          (i) => _navItem(icons[i], _currentIndex == i, isDark, () => setState(() => _currentIndex = i)),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, bool isActive, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive 
                ? Colors.indigoAccent 
                : (isDark ? Colors.white24 : Colors.black26),
              size: 24,
            ),
            if (isActive) 
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4, height: 4,
                decoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }
}
