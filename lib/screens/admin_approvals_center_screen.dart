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
        bottom: TabBar(
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
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminUnifiedPaymentApprovals(hideAppBar: true, selectedDate: _selectedDate),
          AdminOutpassScreen(hideAppBar: true, selectedDate: _selectedDate),
          AdminGuestInvitationsScreen(hideAppBar: true, selectedDate: _selectedDate),
        ],
      ),
    );
  }
}
