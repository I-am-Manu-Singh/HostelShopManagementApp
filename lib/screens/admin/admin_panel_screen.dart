import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_personnel_hub_screen.dart';
import 'admin_order_control_screen.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_room_intelligence_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_block_management_screen.dart';
import 'admin_inventory_management_screen.dart';
import '../campus_stories_screen.dart';
import 'admin_fee_package_screen.dart';
import 'admin_mess_menu_screen.dart';
import 'admin_outpass_screen.dart';
import 'admin_procurement_screen.dart';
import 'admin_audit_nexus_screen.dart';
import '../live_security_dashboard.dart';
import '../notifications_screen.dart';
import '../employee/staff_task_hub_screen.dart';
import '../lending_book_screen.dart';
import 'admin_biometric_sync_screen.dart';
import '../gate_terminal_screen.dart';
import 'admin_guest_invitations_screen.dart';
import 'admin_approvals_center_screen.dart';
import 'admin_broadcast_screen.dart';
import '../central_attendance_log_screen.dart';
import 'admin_room_inspection_screen.dart';
import 'admin_fleet_console_screen.dart';
import 'meter_reading_matrix_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  String _role = 'admin';
  int _studentCount = 0;
  int _activeComplaints = 0;
  int _pendingApprovals = 0;
  int _pendingOrders = 0;
  int _lowStockCount = 0;
  int _expiringMessCards = 0;
  double _totalDues = 0;
  double _totalRevenue = 0;
  double _hostelRev = 0;
  double _shopRev = 0;
  int _totalRooms = 0;
  int _occupiedRooms = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      String userRole = 'admin';
      if (user != null) {
        try {
          final profileRes = await client.from('profiles').select('role').eq('id', user.id).maybeSingle();
          if (profileRes != null) {
            userRole = profileRes['role'] ?? 'admin';
          }
        } catch (_) {}
      }

      final enrollments = await client.from('hostel_enrollments').select('total_price, paid_amount');
      final orders = await client.from('shop_orders').select('total_price, order_status');
      final students = await client.from('profiles').select('id').inFilter('role', ['hostel_student', 'mess_student']);
      final complaints = await client.from('complaints').select('id').neq('status', 'Resolved');
      
      final roomsRes = await client.from('hostel_rooms').select('id, occupancy_status');
      
      // Approvals Aggregation
      final outpasses = await client.from('hostel_outpasses').select('id').eq('status', 'Pending');
      final guests = await client.from('guest_invitations').select('id').eq('status', 'Pending');
      final payments = await client.from('payment_approvals').select('id').eq('status', 'Pending');
      
      final lowStock = await client.from('shop_items').select('id').lt('stock_quantity', 10);

      double hRev = 0;
      double sRev = 0;
      double dues = 0;

      for (var r in (enrollments as List)) {
        hRev += (r['total_price'] as num).toDouble();
        dues += (double.tryParse(r['total_price']?.toString() ?? '0') ?? 0) - (double.tryParse(r['paid_amount']?.toString() ?? '0') ?? 0);
      }
      for (var r in (orders as List)) sRev += (r['total_price'] as num).toDouble();

      int pendingOrd = (orders as List).where((o) => o['order_status'] == 'Placed' || o['order_status'] == 'Packing').length;

      // Load Expiring Mess Cards
      final now = DateTime.now();
      final threshold = now.add(const Duration(days: 3)).toIso8601String();
      final expiring = await client.from('mess_cards').select('id').lte('expiry_date', threshold).gte('expiry_date', now.toIso8601String());

      if (mounted) {
        setState(() {
          _role = userRole;
          _hostelRev = hRev;
          _shopRev = sRev;
          _totalRevenue = hRev + sRev;
          _studentCount = (students as List).length;
          _activeComplaints = (complaints as List).length;
          _pendingApprovals = (outpasses as List).length + (guests as List).length + (payments as List).length;
          _pendingOrders = pendingOrd;
          _lowStockCount = (lowStock as List).length;
          _totalDues = dues.clamp(0, double.infinity);
          _expiringMessCards = (expiring as List).length;
          _totalRooms = (roomsRes as List).length;
          _occupiedRooms = (roomsRes as List).where((r) => r['occupancy_status']?.toString().toLowerCase() == 'occupied').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ADMIN DASHBOARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 20), onPressed: () => print('🚀 [SYS_PING] MISSION CRITICAL PING SUCCESSFUL!')),
          IconButton(icon: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          _buildLiveStatus(isDark),
          const SizedBox(width: 16)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildBackgroundGlow(isDark),
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(child: Text('DASHBOARD OVERVIEW', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2))),
                    const SizedBox(height: 20),
                    _buildOverviewGrid(cardColor, borderColor, isDark),
                    const SizedBox(height: 40),
                    _buildSectionHeader('FINANCIAL OVERVIEW'),
                    const SizedBox(height: 16),
                    _buildRevenueDiagnostic(cardColor, borderColor, isDark),
                    const SizedBox(height: 40),
                    _buildSectionHeader('HUB NAVIGATION'),
                    const SizedBox(height: 16),
                    _buildHubGrid(isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildLiveStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1))),
      child: Row(children: [const Icon(Icons.circle, color: Colors.greenAccent, size: 8), const SizedBox(width: 8), Text('SECURE', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(isDark ? 0.05 : 0.03), shape: BoxShape.circle))));
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2));
  }

  Widget _buildOverviewGrid(Color cardColor, Color borderColor, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    return GridView.count(
      crossAxisCount: w > 900 ? 6 : (w > 600 ? 3 : 2),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: w > 600 ? 1.6 : 1.4,
      children: [
        _statCard('TOTAL REVENUE', '₹${(_totalRevenue / 1000).toStringAsFixed(1)}K', Icons.account_balance_wallet_outlined, Colors.greenAccent, cardColor, borderColor, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen()))),
        _statCard('DUE RENT', '₹${(_totalDues / 1000).toStringAsFixed(1)}K', Icons.error_outline_rounded, Colors.redAccent, cardColor, borderColor, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen()))),
        _statCard('APPROVALS', '$_pendingApprovals PENDING', Icons.fact_check_rounded, Colors.amberAccent, cardColor, borderColor, isDark, () => _handleApprovalNavigation()),
        _statCard('MESS RENEWAL', '$_expiringMessCards CARDS', Icons.credit_card_rounded, Colors.pinkAccent, cardColor, borderColor, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen(filterType: 'Mess')))),
        _statCard('COMPLAINTS', '$_activeComplaints ACTIVE', Icons.warning_amber_rounded, Colors.orangeAccent, cardColor, borderColor, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminComplaintsScreen()))),
        _statCard('ACTIVE ORDERS', '$_pendingOrders ORDERS', Icons.shopping_bag_rounded, Colors.cyanAccent, cardColor, borderColor, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrderControlScreen()))),
      ],
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color, Color cardColor, Color borderColor, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildRevenueDiagnostic(Color cardColor, Color borderColor, bool isDark) {
    final hostelPct = _totalRevenue > 0 ? (_hostelRev / _totalRevenue * 100).toInt() : 0;
    final shopPct = _totalRevenue > 0 ? (_shopRev / _totalRevenue * 100).toInt() : 0;
    final occupancyPct = _totalRooms > 0 ? (_occupiedRooms / _totalRooms * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(28), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Revenue and Occupancy distribution', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Real-time updates', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
            ]),
            const Icon(Icons.analytics_rounded, color: Colors.indigoAccent),
          ]),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             _miniMetric('HOSTEL', '$hostelPct%', Colors.indigoAccent, isDark),
             _miniMetric('SHOP', '$shopPct%', Colors.orangeAccent, isDark),
             _miniMetric('ROOMS', '$occupancyPct%', Colors.greenAccent, isDark),
          ]),
        ],
      ),
    );
  }

 Widget _miniMetric(String label, String val, Color c, bool isDark) {
  return Column(
    children: [
      Text(
        val,
        style: GoogleFonts.outfit(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

Widget _buildHubGrid(bool isDark) {
  final bool isOwner = _role == 'owner' || _role == 'hostel_owner';
  return Column(
    children: [
      _hubSection(
        'FINANCE',
        [
          if (isOwner)
            {
              'icon': Icons.menu_book_rounded,
              'label': 'Lending Book',
              'value': 'ACTIVE',
              'color': Colors.amberAccent,
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => LendingBookScreen())),
            },
          {
            'icon': Icons.account_balance_rounded,
            'label': 'Rent Tracker',
            'value': '₹${(_totalDues/1000).toStringAsFixed(1)}K',
            'color': Colors.amberAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen())),
          },
          {
            'icon': Icons.price_change_rounded,
            'label': 'Fee Plans',
            'value': 'FEE SETUP',
            'color': Colors.indigoAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeePackageScreen())),
          },
        ],
        isDark,
      ),

      const SizedBox(height: 32),

      _hubSection(
        'RESIDENT & HOUSING',
        [
          if (isOwner)
            {
              'icon': Icons.badge_outlined,
              'label': 'Registry',
              'value': '$_studentCount IDS',
              'color': Colors.blueAccent,
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPersonnelHubScreen())),
            },
          {
            'icon': Icons.apartment_rounded,
            'label': 'Manage Blocks',
            'value': '$_totalRooms UNITS',
            'color': Colors.purpleAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBlockManagementScreen())),
          },
          {
            'icon': Icons.room_preferences_rounded,
            'label': 'Room Inspector',
            'value': 'INSPECT',
            'color': Colors.indigoAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRoomInspectionScreen())),
          },
        ],
        isDark,
      ),

      const SizedBox(height: 32),

      _hubSection(
        'SERVICES',
        [
          {
            'icon': Icons.restaurant_menu_rounded,
            'label': 'Attendance',
            'value': 'LOG ACTIVE',
            'color': Colors.orangeAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => CentralAttendanceLogScreen())),
          },
          {
            'icon': Icons.receipt_long_rounded,
            'label': 'Procurements',
            'value': 'HISTORY',
            'color': Colors.tealAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProcurementScreen())),
          },
          {
            'icon': Icons.local_shipping_rounded,
            'label': 'Fleet Console',
            'value': 'FLEET LOGS',
            'color': Colors.greenAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFleetConsoleScreen())),
          },
          {
            'icon': Icons.electric_meter_rounded,
            'label': 'Meter & Power',
            'value': 'MATRIX + INTEL',
            'color': Colors.amberAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeterReadingMatrixScreen())),
          },
        ],
        isDark,
      ),

      const SizedBox(height: 32),

      _hubSection(
        'GOVERNANCE & COMMERCE',
        [
          {
            'icon': Icons.sensor_door_outlined,
            'label': 'Exit / Outpass',
            'value': 'OUTPASSES',
            'color': Colors.pinkAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOutpassScreen())),
          },
          {
            'icon': Icons.shopping_basket_rounded,
            'label': 'Orders Hub',
            'value': '$_pendingOrders ORD',
            'color': Colors.pinkAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrderControlScreen())),
          },
          {
            'icon': Icons.inventory_2_outlined,
            'label': 'Inventory',
            'value': '$_lowStockCount LOW',
            'color': Colors.orangeAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminInventoryManagementScreen())),
          },
          {
            'icon': Icons.campaign_rounded,
            'label': 'Broadcasts',
            'value': 'ANNOUNCEMENTS',
            'color': Colors.indigoAccent,
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
          },
        ],
        isDark,
      ),
    ],
  );
}

  Widget _hubSection(String title, List<Map<String, dynamic>> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 2)),
            Container(width: 40, height: 1, color: Colors.indigoAccent.withOpacity(0.1)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.3,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _hubTile(items[i], isDark),
        ),
      ],
    );
  }

  Widget _hubTile(Map<String, dynamic> item, bool isDark) {
    return GestureDetector(
      onTap: item['onTap'] as VoidCallback,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.1), shape: BoxShape.circle), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
               Text(item['label'] as String, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
               if (item['value'] != null) Text(item['value'] as String, style: TextStyle(color: (item['color'] as Color).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ])),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }

  void _handleApprovalNavigation() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsCenterScreen()));
  }

  Widget _buildSystemTicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: const Row(children: [Icon(Icons.check_circle_outline_rounded, color: Colors.indigoAccent, size: 14), SizedBox(width: 12), Expanded(child: Text('LOG: System ready. Database sync complete.', style: TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)))]),
    );
  }
}
