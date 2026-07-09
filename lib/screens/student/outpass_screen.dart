import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class OutpassScreen extends StatefulWidget {
  const OutpassScreen({super.key});

  @override
  State<OutpassScreen> createState() => _OutpassScreenState();
}

class _OutpassScreenState extends State<OutpassScreen> {
  final _destController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _timeOut = DateTime.now().add(const Duration(hours: 1));
  DateTime _timeIn = DateTime.now().add(const Duration(hours: 4));
  bool _isSubmitting = false;
  List<dynamic> _activeLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final res = await Supabase.instance.client
          .from('hostel_outpasses')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _activeLogs = res; _isLoadingLogs = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _submitOutpass() async {
    if (_destController.text.isEmpty || _reasonController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.redAccent));
       return;
    }
    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('hostel_outpasses').insert({
        'user_id': user!.id,
        'destination': _destController.text.trim(),
        'reason': _reasonController.text.trim(),
        'time_out': _timeOut.toIso8601String(),
        'time_in': _timeIn.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted. Waiting for approval.'), backgroundColor: Colors.greenAccent));
        _destController.clear();
        _reasonController.clear();
        _fetchLogs();
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('OUTPASS REQUEST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildRefractionOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 32),
                _buildForm(isDark),
                const SizedBox(height: 48),
                Text('REQUEST HISTORY', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                const SizedBox(height: 16),
                _isLoadingLogs 
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                  : _activeLogs.isEmpty 
                    ? Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No previous requests', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 12, fontWeight: FontWeight.bold))))
                    : Column(children: _activeLogs.map((log) => _buildRequestCard(log, isDark)).toList()),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.door_front_door_rounded, color: Colors.indigoAccent, size: 28)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('APPLY FOR OUTPASS', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Quick approval for campus exit', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ])),
        ],
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          _buildInput('DESTINATION', 'Where are you going?', _destController, isDark),
          const SizedBox(height: 20),
          _buildInput('REASON', 'Why are you leaving?', _reasonController, isDark),
          const SizedBox(height: 24),
          Row(children: [
             Expanded(child: _buildTimeInput('TIME OUT', _timeOut, (d) => setState(() => _timeOut = d), isDark)),
             const SizedBox(width: 16),
             Expanded(child: _buildTimeInput('EXPECTED RETURN', _timeIn, (d) => setState(() => _timeIn = d), isDark)),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOutpass,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('SUBMIT REQUEST', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController c, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: TextField(controller: c, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 13), border: InputBorder.none)),
      ),
    ]);
  }

  Widget _buildTimeInput(String label, DateTime dt, Function(DateTime) onSelected, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 8),
      InkWell(
        onTap: () async {
          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dt));
          if (time != null) {
            final now = DateTime.now();
            onSelected(DateTime(now.year, now.month, now.day, time.hour, time.minute));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          child: Row(children: [
            const Icon(Icons.access_time_filled_rounded, color: Colors.indigoAccent, size: 16),
            const SizedBox(width: 12),
            Text(DateFormat('hh:mm a').format(dt), style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildRequestCard(dynamic log, bool isDark) {
    final status = log['status']?.toString().toUpperCase() ?? 'PENDING';
    final textColor = isDark ? Colors.white : Colors.black;
    Color statusColor = status == 'PENDING' ? Colors.orangeAccent : Colors.greenAccent;
    if (status == 'REJECTED') statusColor = Colors.redAccent;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ID: ${log['id'].toString().substring(0,8).toUpperCase()}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, fontSize: 10)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Icon(Icons.location_on_rounded, color: Colors.indigoAccent, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(log['destination'].toString().toUpperCase(), style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.history_rounded, color: Colors.indigoAccent, size: 18),
            const SizedBox(width: 12),
            Text('${DateFormat('hh:mm a').format(DateTime.parse(log['time_out']))} - ${DateFormat('hh:mm a').format(DateTime.parse(log['time_in']))}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}
