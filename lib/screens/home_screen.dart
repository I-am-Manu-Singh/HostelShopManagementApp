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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    _loadProfile();
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
    
    // Default for store_customer or others
    return [
      const ShopBrowseScreen(isMandiMode: false),
      const ShopBrowseScreen(isMandiMode: true),
      const ProfileScreen(),
    ];
  }

  List<IconData> _getIcons(String role) {
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
            // Web Header
            _buildWebHeader(labels, isDark),
            // Page Body
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
            // Web Footer
            _buildWebFooter(isDark),
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

  Widget _buildWebHeader(List<String> labels, bool isDark) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black10)),
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
            children: List.generate(labels.length, (index) {
              final active = _currentIndex == index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: () => setState(() => _currentIndex = index),
                  child: Text(
                    labels[index],
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: active ? Colors.indigoAccent : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }),
          ),
          Row(
            children: [
              Text(
                '${(_userProfile?['full_name'] ?? 'USER').toString().toUpperCase()}',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWebFooter(bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08090A) : const Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2026 Campus Connect Operations Platform.',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Text(
            'SYSTEM LOGISTICS ACTIVE',
            style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          )
        ],
      ),
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
