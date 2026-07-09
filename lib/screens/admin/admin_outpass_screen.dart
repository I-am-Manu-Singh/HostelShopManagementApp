import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../hostel_security_terminal_screen.dart';

class AdminOutpassScreen extends StatefulWidget {
  final bool hideAppBar;
  final DateTime? selectedDate;
  const AdminOutpassScreen({super.key, this.hideAppBar = false, this.selectedDate});

  @override
  State<AdminOutpassScreen> createState() => _AdminOutpassScreenState();
}

class _AdminOutpassScreenState extends State<AdminOutpassScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      // 🧠 FIXED: Try fetching from hostel_outpasses with join
      final res = await _client.from('hostel_outpasses').select('*, profiles:user_id(*)').order('created_at', ascending: false);
      if (mounted) setState(() { _requests = res; _isLoading = false; });
    } catch (_) {
      try {
        // Fallback 1: Without join
        final res = await _client.from('hostel_outpasses').select().order('created_at', ascending: false);
        if (mounted) setState(() { _requests = res; _isLoading = false; });
      } catch (_) {
        try {
          // Fallback 2: Check if table is actually 'outpasses' (often used interchangeably in different PRs)
          final res = await _client.from('outpasses').select().order('created_at', ascending: false);
          if (mounted) setState(() { _requests = res; _isLoading = false; });
        } catch (_) {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('hostel_outpasses').update({
        'status': status,
        'approved_by': user?.id,
      }).eq('id', id);
      _fetchRequests();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.hideAppBar ? null : AppBar(
        title: Text('OUTPASS REQUESTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostelSecurityTerminalScreen())),
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.security_rounded, color: Colors.white),
        label: Text('OPEN SECURITY GATE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : RefreshIndicator(
            onRefresh: _fetchRequests,
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _requests.length,
              itemBuilder: (context, i) => FadeInUp(
                delay: Duration(milliseconds: i * 100),
                child: _buildRequestCard(_requests[i], cardColor, borderColor, isDark),
              ),
            ),
          ),
    );
  }

  Widget _buildRequestCard(dynamic data, Color cardColor, Color borderColor, bool isDark) {
    final profile = data['profiles'];
    final status = data['status']?.toString() ?? 'Pending';
    bool isPending = status == 'Pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(28), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile?['full_name']?.toString().toUpperCase() ?? 'STUDENT', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                Text(profile?['room_number'] != null ? 'ROOM ${profile['room_number']}' : 'ROOM PENDING', style: TextStyle(color: isDark ? Colors.white24 : Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isPending ? Colors.orangeAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: TextStyle(color: isPending ? Colors.orangeAccent : Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 24),
          _detailRow(Icons.location_on_rounded, 'DESTINATION', data['destination'] ?? 'NOT SPECIFIED', isDark),
          const SizedBox(height: 12),
          _safeTimeRow(data['time_out'], data['time_in'], isDark),
          const SizedBox(height: 12),
          _detailRow(Icons.help_outline_rounded, 'REASON', data['reason'] ?? 'PERSONAL REASON', isDark),
          if (isPending) ...[
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: _actionBtn('DENY', Colors.redAccent.withOpacity(0.1), Colors.redAccent, isDark, () => _updateStatus(data['id'], 'Rejected'))),
              const SizedBox(width: 12),
              Expanded(child: _actionBtn('APPROVE', Colors.indigoAccent, isDark ? Colors.black : Colors.white, isDark, () => _updateStatus(data['id'], 'Approved'))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _safeTimeRow(dynamic out, dynamic back, bool isDark) {
    try {
      final tOut = DateFormat('HH:mm').format(DateTime.parse(out.toString()));
      final tIn = DateFormat('HH:mm').format(DateTime.parse(back.toString()));
      return _detailRow(Icons.schedule_rounded, 'DURATION', '$tOut - $tIn', isDark);
    } catch(_) {
      return _detailRow(Icons.schedule_rounded, 'DURATION', 'TIME DATA CORRUPTED', isDark);
    }
  }

  Widget _detailRow(IconData icon, String label, String val, bool isDark) {
    return Row(children: [
      Icon(icon, color: Colors.indigoAccent, size: 14),
      const SizedBox(width: 12),
      Text('$label: ', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)),
      Expanded(child: Text(val, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _actionBtn(String label, Color bg, Color text, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(height: 48, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), alignment: Alignment.center, child: Text(label, style: GoogleFonts.outfit(color: text, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1))),
    );
  }
}
