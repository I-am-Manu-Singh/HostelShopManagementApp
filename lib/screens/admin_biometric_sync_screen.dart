import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';

class AdminBiometricSyncScreen extends StatefulWidget {
  const AdminBiometricSyncScreen({super.key});

  @override
  State<AdminBiometricSyncScreen> createState() => _AdminBiometricSyncScreenState();
}

class _AdminBiometricSyncScreenState extends State<AdminBiometricSyncScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('*')
        .order('full_name');
    
    if (mounted) {
      setState(() {
        _students = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    }
  }

  Future<void> _resetBiometrics(String userId, String type) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (type == 'face') updateData['face_embedding'] = null;
      if (type == 'fingerprint') updateData['biometric_id'] = null;

      await Supabase.instance.client.from('profiles').update(updateData).eq('id', userId);
      _loadStudents();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RE-ENROLLMENT TRIGGERED FOR ${type.toUpperCase()}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RESET FAILED: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _students.where((s) => (s['full_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text('BIOMETRIC GOVERNANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearch(isDark),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _studentTile(filtered[index], isDark),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'SEARCH BY NAME OR ID...',
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigoAccent, size: 18),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _studentTile(Map<String, dynamic> s, bool isDark) {
    final hasFace = s['face_embedding'] != null;
    final hasFinger = s['biometric_id'] != null;
    final room = s['room_id']?.toString().split('-').first ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.indigoAccent.withOpacity(0.1), radius: 20, child: Text((s['full_name']?[0] ?? '?').toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['full_name'] ?? 'Unknown Student', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('ROOM: $room • BATCH: ${s['batch_year'] ?? '2024'}', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _statusBadge('FACE_ID', hasFace, Colors.greenAccent, isDark, () => _resetBiometrics(s['id'], 'face')),
              const SizedBox(width: 12),
              _statusBadge('FINGER_PT', hasFinger, Colors.orangeAccent, isDark, () => _resetBiometrics(s['id'], 'fingerprint')),
              const Spacer(),
              const Icon(Icons.verified_user_outlined, color: Colors.indigoAccent, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, bool active, Color color, bool isDark, VoidCallback onReset) {
    return GestureDetector(
      onLongPress: onReset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : (isDark ? Colors.white12 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(active ? Icons.check_circle_rounded : Icons.pending_rounded, size: 10, color: active ? color : (isDark ? Colors.white24 : Colors.black26)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(color: active ? color : (isDark ? Colors.white24 : Colors.black26), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
