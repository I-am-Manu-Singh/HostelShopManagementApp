import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestSecurityScannerScreen extends StatefulWidget {
  const GuestSecurityScannerScreen({super.key});

  @override
  State<GuestSecurityScannerScreen> createState() => _GuestSecurityScannerScreenState();
}

class _GuestSecurityScannerScreenState extends State<GuestSecurityScannerScreen> {
  final _client = Supabase.instance.client;
  bool _isProcessing = false;
  Map<String, dynamic>? _scannedInvite;
  MobileScannerController cameraController = MobileScannerController();

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.startsWith('GUEST_')) {
        setState(() => _isProcessing = true);
        await _lookupInvite(code);
      }
    }
  }

  Future<void> _lookupInvite(String code) async {
    try {
      final res = await _client
          .from('guest_invitations')
          .select('*, profiles:user_id(*)')
          .eq('pass_code', code)
          .maybeSingle();

      if (res != null) {
        setState(() => _scannedInvite = res);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid or Expired Pass'), backgroundColor: Colors.redAccent));
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _markEntry(String status) async {
    if (_scannedInvite == null) return;
    try {
      await _client.from('guest_invitations').update({'status': status}).eq('id', _scannedInvite!['id']);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Guest marked as $status')));
      setState(() {
        _scannedInvite = null;
        _isProcessing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('SECURITY SCANNER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          _buildOverlay(),
          if (_scannedInvite != null) _buildResultSheet(isDark),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: Container(
        width: 250, height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.indigoAccent, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildResultSheet(bool isDark) {
    final data = _scannedInvite!;
    final profile = data['profiles'];
    final textColor = isDark ? Colors.white : Colors.black;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.indigoAccent.withOpacity(0.1), radius: 30, child: const Icon(Icons.person_rounded, color: Colors.indigoAccent, size: 30)),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['guest_name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('${data['relationship']} of ${profile?['full_name'] ?? 'Student'}', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12, fontWeight: FontWeight.bold)),
                ])),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [Text('STAY', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)), Text('${data['stay_duration']} Days', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))]),
                  Column(children: [Text('ROOM', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)), Text(profile?['room_number'] ?? 'N/A', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))]),
                  Column(children: [Text('STATUS', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)), Text(data['status'].toString().toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))]),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(child: _actionBtn('MARK DEPARTED', Colors.redAccent.withOpacity(0.1), Colors.redAccent, () => _markEntry('Departed'))),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn('MARK ARRIVED', Colors.greenAccent, Colors.black, () => _markEntry('Arrived'))),
              ],
            ),
            const SizedBox(height: 20),
            Center(child: TextButton(onPressed: () => setState(() { _scannedInvite = null; _isProcessing = false; }), child: const Text('CANCEL SCAN', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: text, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), minimumSize: const Size(double.infinity, 60)),
      child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
    );
  }
}
