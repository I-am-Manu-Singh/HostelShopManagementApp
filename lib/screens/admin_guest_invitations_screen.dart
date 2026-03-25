import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminGuestInvitationsScreen extends StatefulWidget {
  final bool hideAppBar;
  final DateTime? selectedDate;
  const AdminGuestInvitationsScreen({super.key, this.hideAppBar = false, this.selectedDate});

  @override
  State<AdminGuestInvitationsScreen> createState() => _AdminGuestInvitationsScreenState();
}

class _AdminGuestInvitationsScreenState extends State<AdminGuestInvitationsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _invites = [];
  String _filterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchInvites();
  }

  Future<void> _fetchInvites() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 🧠 FIXED: Join on user_id to profiles or just user_id if alias profiles.
      final res = await _client.from('guest_invitations').select('*, profiles:user_id(*)').order('created_at', ascending: false);
      if (mounted) setState(() { _invites = res; _isLoading = false; });
    } catch (_) {
      try {
         // Fallback if join is ambiguous
         final res = await _client.from('guest_invitations').select('*').order('created_at', ascending: false);
         if (mounted) setState(() { _invites = res; _isLoading = false; });
      } catch (e) {
         if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('guest_invitations').update({
        'status': status,
        'approved_by': user?.id,
      }).eq('id', id);
      _fetchInvites();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    final filtered = _invites.where((i) => _filterStatus == 'ALL' || (i['status']?.toString().toUpperCase() == _filterStatus)).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.hideAppBar ? null : AppBar(
        title: Text('GUEST MANAGEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: textColor), onPressed: _fetchInvites),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Column(
            children: [
              _buildFilterBar(isDark),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchInvites,
                  child: filtered.isEmpty 
                    ? _emptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => FadeInUp(
                          delay: Duration(milliseconds: i * 50),
                          child: _buildInviteCard(filtered[i], cardColor, borderColor, isDark),
                        ),
                      ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final statuses = ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'ARRIVED', 'DEPARTED'];
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: statuses.length,
        itemBuilder: (context, i) {
          final s = statuses[i];
          final sel = _filterStatus == s;
          return GestureDetector(
            onTap: () => setState(() => _filterStatus = s),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(15)),
              alignment: Alignment.center,
              child: Text(s, style: GoogleFonts.outfit(color: sel ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInviteCard(dynamic data, Color cardColor, Color borderColor, bool isDark) {
    final profile = data['profiles'];
    final status = data['status']?.toString() ?? 'Pending';
    bool isPending = status.toLowerCase() == 'pending';
    final textColor = isDark ? Colors.white : Colors.black;
    
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
                Text(data['guest_name']?.toString().toUpperCase() ?? 'GUEST SYSTEM', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('HOSTED BY: ${profile?['full_name'] ?? "UNKNOWN STUDENT"}', style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))),
            ],
          ),
          const SizedBox(height: 24),
          _detailRow(Icons.people_rounded, 'RELATIONSHIP', data['relationship'] ?? 'NOT SPECIFIED', isDark),
          const SizedBox(height: 12),
          _detailRow(Icons.calendar_today_rounded, 'STAY DURATION', '${data['stay_duration']} DAYS', isDark),
          const SizedBox(height: 12),
          _detailRow(Icons.qr_code_rounded, 'PASS CODE', data['pass_code'] ?? 'N/A', isDark),
          if (isPending) ...[
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: _actionBtn('REJECTED', Colors.redAccent.withOpacity(0.1), Colors.redAccent,  () => _updateStatus(data['id'], 'Rejected'))),
              const SizedBox(width: 12),
              Expanded(child: _actionBtn('APPROVED', Colors.indigoAccent, Colors.white, () => _updateStatus(data['id'], 'Approved'))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String val, bool isDark) {
    return Row(children: [Icon(icon, color: Colors.indigoAccent, size: 14), const SizedBox(width: 12), Text('$label: ', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)), Expanded(child: Text(val, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))]);
  }

  Widget _actionBtn(String label, Color bg, Color text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(height: 50, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Text(label, style: GoogleFonts.outfit(color: text, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))),
    );
  }

  Color _getStatusColor(String s) {
    s = s.toLowerCase();
    if (s == 'approved' || s == 'arrived') return Colors.greenAccent;
    if (s == 'rejected' || s == 'departed') return Colors.redAccent;
    return Colors.orangeAccent;
  }

  Widget _emptyState(bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline_rounded, size: 60, color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 16), Text('NO GUEST ACTIVITY DETECTED', style: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))]));
  }
}
