import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_outpass_screen.dart';
import 'admin_guest_invitations_screen.dart';
import 'admin_unified_payment_approvals.dart';

class AdminApprovalsCenterScreen extends StatefulWidget {
  const AdminApprovalsCenterScreen({super.key});

  @override
  State<AdminApprovalsCenterScreen> createState() => _AdminApprovalsCenterScreenState();
}

class _AdminApprovalsCenterScreenState extends State<AdminApprovalsCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('APPROVALS CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), onPressed: () async {
             final d = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
             if (d != null) setState(() => _selectedDate = d);
          }),
        ],
        bottom: MediaQuery.of(context).size.width > 800 
          ? null 
          : TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
              labelColor: Colors.indigoAccent,
              unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
              indicatorColor: Colors.indigoAccent,
              tabs: const [
                Tab(text: 'PAYMENTS', icon: Icon(Icons.payments_rounded, size: 18)),
                Tab(text: 'OUTPASSES', icon: Icon(Icons.calendar_today_rounded, size: 18)),
                Tab(text: 'GUESTS', icon: Icon(Icons.people_rounded, size: 18)),
              ],
            ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Desktop/Wide View: 2-column sidebar design
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        _buildSidebarTile(0, 'PAYMENTS', Icons.payments_rounded),
                        _buildSidebarTile(1, 'OUTPASSES', Icons.calendar_today_rounded),
                        _buildSidebarTile(2, 'GUESTS', Icons.people_rounded),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      AdminUnifiedPaymentApprovals(hideAppBar: true, selectedDate: _selectedDate),
                      AdminOutpassScreen(hideAppBar: true, selectedDate: _selectedDate),
                      AdminGuestInvitationsScreen(hideAppBar: true, selectedDate: _selectedDate),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile View: Default TabBarView
          return TabBarView(
            controller: _tabController,
            children: [
              AdminUnifiedPaymentApprovals(hideAppBar: true, selectedDate: _selectedDate),
              AdminOutpassScreen(hideAppBar: true, selectedDate: _selectedDate),
              AdminGuestInvitationsScreen(hideAppBar: true, selectedDate: _selectedDate),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebarTile(int index, String label, IconData icon) {
    final active = _tabController.index == index;
    return ListTile(
      selected: active,
      selectedTileColor: Colors.indigoAccent.withOpacity(0.08),
      leading: Icon(icon, color: active ? Colors.indigoAccent : Colors.grey),
      title: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: active ? Colors.indigoAccent : Colors.grey)),
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
    );
  }
}
