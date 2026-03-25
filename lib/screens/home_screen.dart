import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'shop_browse_screen.dart';
import 'profile_screen.dart';
import 'student_terminal_screen.dart';
import 'admin_panel_screen.dart';
import 'admin_order_control_screen.dart';
import 'mess_student_card_screen.dart';
import 'productivity_suite_hub.dart';
import 'staff_task_hub_screen.dart';
import 'chat_room_list_screen.dart';
import 'admin_finance_hub_screen.dart';

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
        ShopBrowseScreen(),
        AdminFinanceHubScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'staff') {
      return [
        ProductivitySuiteHub(),
        ShopBrowseScreen(),
        StaffTaskHubScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'hostel_student' || role == 'mess_student') {
      return [
        StudentTerminalScreen(),
        ShopBrowseScreen(),
        ProductivitySuiteHub(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    }
    
    // Default for store_customer or others
    return [
      const ShopBrowseScreen(),
      const ProfileScreen(),
    ];
  }

  List<IconData> _getIcons(String role) {
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [Icons.grid_view_rounded, Icons.shopping_bag_outlined, Icons.receipt_long_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'staff') {
      return [Icons.psychology_outlined, Icons.shopping_bag_outlined, Icons.pending_actions_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'hostel_student' || role == 'mess_student') {
      return [Icons.grid_view_rounded, Icons.shopping_bag_outlined,Icons.psychology_outlined,  Icons.forum_outlined, Icons.person_outline_rounded];
    }
    return [Icons.shopping_bag_outlined, Icons.person_outline_rounded];
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

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomBar(icons, isDark),
    );
  }

  Widget _buildBottomBar(List<IconData> icons, bool isDark) {
    return Container(
      height: 70, 
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
