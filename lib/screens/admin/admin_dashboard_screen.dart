import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_personnel_hub_screen.dart';
import '../live_security_dashboard.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_outpass_screen.dart';
import 'admin_complaints_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _broadcasts = [];
  Map<String, dynamic> _stats = {
    'revenue': 0.0,
    'bookings': 0,
    'logistics': 0,
    'enquiries': 0,
    'personnel': 0,
    'reports': 0,
    'complaints': 0,
  };
  List<FlSpot> _revenueSpots = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final broadcastRes = await _client.from('global_announcements').select().order('created_at', ascending: false);
      final enrollRes = await _client.from('hostel_enrollments').select('total_price, paid_amount, created_at');
      final outRes = await _client.from('hostel_outpasses').select('id').eq('status', 'Pending');
      final complaintRes = await _client.from('complaints').select('id').neq('status', 'Resolved');
      final profileRes = await _client.from('profiles').select('id, role').inFilter('role', ['hostel_student', 'mess_student', 'staff']);

      double revenue = 0;
      Map<int, double> monthlyRev = {};
      for (var b in (enrollRes as List)) {
        double amt = (double.tryParse(b['paid_amount']?.toString() ?? '0') ?? 0);
        revenue += amt;
        
        final date = DateTime.tryParse(b['created_at'] ?? '');
        if (date != null) {
          monthlyRev[date.month] = (monthlyRev[date.month] ?? 0) + amt;
        }
      }

      List<FlSpot> spots = [];
      for (int i = 1; i <= 12; i++) {
        spots.add(FlSpot(i.toDouble(), (monthlyRev[i] ?? 0) / 1000)); // Scale to K
      }

      if (mounted) {
        setState(() {
          _broadcasts = (broadcastRes as List);
          _revenueSpots = spots;
          _stats = {
            'revenue': revenue,
            'bookings': (enrollRes as List).length,
            'logistics': (outRes as List).length,
            'enquiries': (complaintRes as List).length,
            'personnel': (profileRes as List).length,
            'reports': (complaintRes as List).length, 
            'complaints': (complaintRes as List).length,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('HQ_DASHBOARD_ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('HQ COMMAND CENTER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _loadDashboardData),
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 20), onPressed: () => _showBroadcastModal()),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildIntelligenceGraph(),
                const SizedBox(height: 32),
                const Text('OPERATIONAL METRICS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _statCard('OPS COMMAND', 'LIVE', Icons.security_rounded, Colors.indigoAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveSecurityDashboard()))),
                    _statCard('TOTAL REVENUE', '₹${(_stats['revenue'] / 1000).toStringAsFixed(1)}K', Icons.payments, Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen()))),
                    _statCard('ENROLLMENTS', '${_stats['bookings']}', Icons.assignment, Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen()))),
                    _statCard('FIELD PERSONNEL', '${_stats['personnel']}', Icons.people, Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPersonnelHubScreen()))),
                    _statCard('EXIT CLEARANCE', '${_stats['logistics']}', Icons.sensor_door_outlined, Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOutpassScreen()))),
                    _statCard('COMPLAINTS', '${_stats['complaints']}', Icons.report_problem, Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminComplaintsScreen()))),
                  ],
                ),
                const SizedBox(height: 40),
                const Text('GLOBAL BROADCAST CONTROL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                if (_broadcasts.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('NO ACTIVE BROADCASTS', style: TextStyle(color: Colors.grey, fontSize: 12))))
                else
                  ..._broadcasts.map((b) => _buildBroadcastCard(b)),
                const SizedBox(height: 100),
              ],
            ),
          ),
    );
  }

  Widget _buildIntelligenceGraph() {
    return FadeInDown(
      child: Container(
        height: 250,
        padding: const EdgeInsets.fromLTRB(10, 30, 30, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
        ),
        child: Column(
          children: [
            const Text('REVENUE INTELLIGENCE (MONTHLY)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenueSpots,
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent.withOpacity(0.3), Colors.blueAccent.withOpacity(0)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.withOpacity(0.05))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastCard(dynamic b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(b['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                onPressed: () async {
                  await _client.from('global_announcements').delete().eq('id', b['id']);
                  _loadDashboardData();
                },
              ),
            ],
          ),
          Text(b['title'] ?? 'URGENT INTEL', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(b['content'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  void _showBroadcastModal({dynamic existing}) {
    final titleCtrl = TextEditingController(text: existing?['title']);
    final contentCtrl = TextEditingController(text: existing?['content']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OFFICIAL BROADCAST', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 24),
            _modalInput(titleCtrl, 'Intel Title...', 1),
            const SizedBox(height: 16),
            _modalInput(contentCtrl, 'Intel Content...', 4),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  if (existing != null) {
                    await _client.from('global_announcements').update({'title': titleCtrl.text, 'content': contentCtrl.text, 'is_urgent': true}).eq('id', existing['id']);
                  } else {
                    await _client.from('global_announcements').insert({'title': titleCtrl.text, 'content': contentCtrl.text, 'created_at': DateTime.now().toIso8601String(), 'is_urgent': true});
                  }
                  Navigator.pop(ctx);
                  _loadDashboardData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text('ENGAGE BROADCAST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, int lines) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
    );
  }
}
