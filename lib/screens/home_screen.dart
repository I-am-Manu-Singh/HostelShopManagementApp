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
import '../widgets/shared_web_components.dart';
import 'employee/employee_terminal_screen.dart';

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
    if (widget.isGuest) {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        const LoginScreen(),
      ];
    }
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        AdminFinanceHubScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'staff') {
      return [
        const EmployeeTerminalScreen(),
        StaffTaskHubScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'hostel_student') {
      return [
        StudentTerminalScreen(),
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        ProductivitySuiteHub(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'mess_student') {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        const ShopBrowseScreen(isMandiMode: true),
        MessStudentCardScreen(),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'delivery_partner') {
      return [
        const MandiDeliveryScreen(),
        CampusChatListScreen(),
        const ProfileScreen(),
      ];
    } else if (role == 'farmer_seller') {
      return [
        const MandiSellerScreen(),
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
    if (widget.isGuest) {
      return [Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.login_rounded];
    }
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.receipt_long_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'staff') {
      return [Icons.badge_outlined, Icons.psychology_outlined, Icons.pending_actions_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'hostel_student') {
      return [Icons.grid_view_rounded, Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.psychology_outlined, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'mess_student') {
      return [Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.credit_card_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'delivery_partner') {
      return [Icons.local_shipping_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'farmer_seller') {
      return [Icons.agriculture_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    }
    return [Icons.shopping_bag_outlined, Icons.storefront_rounded, Icons.person_outline_rounded];
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
    final labels = getRoleLabels(role, widget.isGuest);

    if (kIsWeb) {
      final isDesktop = MediaQuery.of(context).size.width > 800;
      return Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            WebHeader(
              userProfile: _userProfile,
              isGuest: widget.isGuest,
              currentIndex: _currentIndex,
              labels: labels,
              onTabSelected: (index) => setState(() => _currentIndex = index),
            ),
            // Expanded allows LayoutBuilder down the widget tree to query window size correctly
            Expanded(
              child: pages[_currentIndex],
            ),
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
