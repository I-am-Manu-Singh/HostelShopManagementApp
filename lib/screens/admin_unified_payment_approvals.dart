import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_order_control_screen.dart';

class AdminUnifiedPaymentApprovals extends StatefulWidget {
  final bool hideAppBar;
  final DateTime? selectedDate;
  const AdminUnifiedPaymentApprovals({super.key, this.hideAppBar = false, this.selectedDate});

  @override
  State<AdminUnifiedPaymentApprovals> createState() => _AdminUnifiedPaymentApprovalsState();
}

class _AdminUnifiedPaymentApprovalsState extends State<AdminUnifiedPaymentApprovals> with SingleTickerProviderStateMixin {
  late TabController _innerController;

  @override
  void initState() {
    super.initState();
    _innerController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _innerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        /// 🔥 INTERNAL SUB-TABS (MINIFIED)
        Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
          child: TabBar(
            controller: _innerController,
            indicator: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(10)),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? Colors.white24 : Colors.black38,
            labelStyle: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'RENT'),
              Tab(text: 'MESS'),
              Tab(text: 'STORE'),
            ],
          ),
        ),
        
        /// 🔥 VIEWPORT FOR PAYMENTS
        Expanded(
          child: TabBarView(
            controller: _innerController,
            physics: const NeverScrollableScrollPhysics(), // 🛡️ PREVENT PARENT TAB BUBBLING
            children: [
               // Rent approvals - passing hidden fiscal flag
               AdminFinanceHubScreen(hideAppBar: true, filterType: 'Rent', initialDate: widget.selectedDate),
               
               // Mess approvals
               AdminFinanceHubScreen(hideAppBar: true, filterType: 'Mess', initialDate: widget.selectedDate),
               
               // Store approvals
               AdminOrderControlScreen(approvalsOnly: true, hideAppBar: true, initialDate: widget.selectedDate),
            ],
          ),
        ),
      ],
    );
  }
}
