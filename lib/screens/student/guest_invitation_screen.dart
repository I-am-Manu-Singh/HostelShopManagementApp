import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestInvitationScreen extends StatefulWidget {
  const GuestInvitationScreen({super.key});

  @override
  State<GuestInvitationScreen> createState() => _GuestInvitationScreenState();
}

class _GuestInvitationScreenState extends State<GuestInvitationScreen> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _daysController = TextEditingController(text: '1');
  bool _qrGenerated = false;
  bool _isSubmitting = false;
  String? _generatedCode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('GUEST INVITE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
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
                if (!_qrGenerated) ...[
                  Text('INVITATION DETAILS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                  const SizedBox(height: 32),
                  _buildInput('GUEST NAME', 'Enter guest full name', _nameController, isDark, icon: Icons.person_rounded),
                  const SizedBox(height: 20),
                  _buildInput('RELATIONSHIP', 'e.g. Parent, Sibling, Friend', _relationController, isDark, icon: Icons.people_rounded),
                  const SizedBox(height: 20),
                  _buildInput('STAY DURATION', 'How many days?', _daysController, isDark, icon: Icons.calendar_today_rounded, keyboardType: TextInputType.number),
                  const SizedBox(height: 60),
                  _buildGenerateButton(),
                ] else ...[
                  _buildQRDisplay(isDark),
                ],
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

  Widget _buildInput(String label, String hint, TextEditingController c, bool isDark, {IconData? icon, TextInputType keyboardType = TextInputType.text}) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Row(children: [
          Icon(icon, color: Colors.indigoAccent, size: 20),
          const SizedBox(width: 16),
          Expanded(child: TextField(controller: c, keyboardType: keyboardType, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 13), border: InputBorder.none))),
        ]),
      ),
    ]);
  }

  Widget _buildGenerateButton() {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity, height: 60,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _generateAndSaveInvite,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          child: _isSubmitting 
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('GENERATE INVITE QR', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
        ),
      ),
    );
  }

  Future<void> _generateAndSaveInvite() async {
     if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter guest name'), backgroundColor: Colors.redAccent));
        return;
     }

     setState(() => _isSubmitting = true);
     try {
       final user = Supabase.instance.client.auth.currentUser;
       final code = 'GUEST_${_nameController.text.trim().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
       
       await Supabase.instance.client.from('guest_invitations').insert({
         'user_id': user!.id,
         'guest_name': _nameController.text.trim(),
         'relationship': _relationController.text.trim(),
         'stay_duration': int.tryParse(_daysController.text) ?? 1,
         'pass_code': code,
       });

       if (mounted) {
         setState(() {
           _generatedCode = code;
           _qrGenerated = true;
           _isSubmitting = false;
         });
       }
     } catch (e) {
       if (mounted) {
         setState(() => _isSubmitting = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
       }
     }
  }

  Widget _buildQRDisplay(bool isDark) {
    return Column(
      children: [
        Text('GUEST ENTRY PASS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
        const SizedBox(height: 48),
        FadeInScale(
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36), boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)]),
            child: Column(
              children: [
                QrImageView(
                  data: _generatedCode ?? 'ERROR',
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 32),
                Text(_nameController.text.toUpperCase(), style: GoogleFonts.outfit(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('VALID FOR: ${_daysController.text} DAYS', style: GoogleFonts.outfit(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text('EXPIRY: ${DateFormat('dd MMM yyyy').format(DateTime.now().add(Duration(days: int.tryParse(_daysController.text) ?? 1)))}', style: GoogleFonts.outfit(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 60),
        Text('Please share this QR code with your guest. It will be scanned at the campus entry.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 48),
        TextButton(onPressed: () => setState(() => _qrGenerated = false), child: Text('CREATE NEW INVITE', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
      ],
    );
  }
}

class FadeInScale extends StatelessWidget {
  final Widget child;
  const FadeInScale({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return FadeIn(child: ZoomIn(child: child));
  }
}
