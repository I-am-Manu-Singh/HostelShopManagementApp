import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../auth/login_screen.dart';
import '../shop/shop_browse_screen.dart';
import '../profile/profile_screen.dart';
import '../student/student_terminal_screen.dart';
import '../student/mess_student_card_screen.dart';
import '../employee/staff_task_hub_screen.dart';
import '../social/chat_room_list_screen.dart';
import '../mandi/mandi_seller_screen.dart';
import '../mandi/mandi_delivery_screen.dart';
import '../../widgets/shared_web_components.dart';
import '../employee/employee_terminal_screen.dart';
import '../user/edit_profile_screen.dart';
import '../../services/preferences_service.dart';

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
      _initAndLoadProfile();
    }
  }

  Future<void> _initAndLoadProfile() async {
    // ⚡ Fast-path: instantly hydrate from local cache to prevent loading flicker / blank screen on resume
    final cached = await PreferencesService().getCachedProfile();
    if (cached != null && mounted) {
      setState(() {
        _userProfile = cached;
        _isLoading = false;
      });
    }
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService().fetchUserProfile();
    if (mounted && profile != null) {
      // First-time onboarding: if phone_no is empty, route to profile completion
      final phone = profile['phone_no']?.toString() ?? '';
      final onboardingDone = profile['onboarding_done'] as bool? ?? false;
      if (!onboardingDone && phone.isEmpty && !widget.isGuest) {
        final role = profile['role']?.toString() ?? 'store_customer';
        // Don't show onboarding for admin/owner — they are set up differently
        if (role != 'admin' && role != 'owner' && role != 'hostel_manager') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    isOnboarding: true,
                    forceRole: role,
                  ),
                ),
              );
            }
          });
          return;
        }
      }
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
        // const ShopBrowseScreen(isMandiMode: true),
        const LoginScreen(),
      ];
    }
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        // const ShopBrowseScreen(isMandiMode: true),
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
        // const ShopBrowseScreen(isMandiMode: true),
        CampusChatListScreen(),
        ProfileScreen(),
      ];
    } else if (role == 'mess_student') {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        // const ShopBrowseScreen(isMandiMode: true),
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
    } else if (role == 'store_customer') {
      return [
        const ShopBrowseScreen(isMandiMode: false),
        CampusChatListScreen(),
        const ProfileScreen(),
      ];
    }
    // Default for store_customer or others
    return [
      const ShopBrowseScreen(isMandiMode: false),
      CampusChatListScreen(),
      const ProfileScreen(),
    ];
  }

  List<IconData> _getIcons(String role) {
    if (widget.isGuest) {
      return [Icons.shopping_bag_outlined, Icons.login_rounded];
    }
    if (role == 'admin' || role == 'hostel_manager' || role == 'owner') {
      return [Icons.shopping_bag_outlined, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'staff') {
      return [Icons.badge_outlined, Icons.pending_actions_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'hostel_student') {
      return [Icons.grid_view_rounded, Icons.shopping_bag_outlined, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'mess_student') {
      return [Icons.shopping_bag_outlined, Icons.credit_card_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'delivery_partner') {
      return [Icons.local_shipping_rounded,  Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'farmer_seller') {
      return [Icons.agriculture_rounded, Icons.forum_outlined, Icons.person_outline_rounded];
    } else if (role == 'store_customer') {
      return [Icons.shopping_bag_outlined, Icons.forum_outlined, Icons.person_outline_rounded];
    }
    return [Icons.shopping_bag_outlined, Icons.forum_outlined, Icons.person_outline_rounded];
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
