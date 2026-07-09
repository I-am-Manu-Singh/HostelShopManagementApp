import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CampusCertificateScreen extends StatefulWidget {
  final Map<String, dynamic> enrollment;
  const CampusCertificateScreen({super.key, required this.enrollment});

  @override
  State<CampusCertificateScreen> createState() => _CampusCertificateScreenState();
}

class _CampusCertificateScreenState extends State<CampusCertificateScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _shareCertificate() async {
    final image = await _screenshotController.capture();
    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/campus_achievement.png').create();
      await imagePath.writeAsBytes(image);
      await Share.shareXFiles([XFile(imagePath.path)], text: 'Achievement Unlocked: Official Certification from Campus HQ!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.enrollment['hostel_rooms'] ?? {};
    final user = widget.enrollment['profiles'] ?? {};
    final studentName = user['full_name'] ?? 'Candidate Personnel';
    final enrollmentDate = DateFormat('MMMM dd, yyyy').format(DateTime.parse(widget.enrollment['created_at']));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('FORMAL CERTIFICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded, color: Colors.indigoAccent), onPressed: _shareCertificate),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.network('https://images.unsplash.com/photo-1541339907198-e08756ebafe3?auto=format&fit=crop&q=80&w=2070', fit: BoxFit.cover)),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.9), Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.9)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
              child: FadeInUp(
                child: Screenshot(
                  controller: _screenshotController,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      width: 450, height: 700,
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 60)],
                        border: Border.all(color: const Color(0xFF16181A), width: 12),
                        image: const DecorationImage(image: NetworkImage('https://www.transparenttextures.com/patterns/natural-paper.png'), opacity: 0.1, repeat: ImageRepeat.repeat),
                      ),
                      child: Column(
                        children: [
                          Text('CAMPUS MANAGEMENT HQ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 4, color: const Color(0xFF16181A))),
                          const SizedBox(height: 8),
                          const Divider(color: Color(0xFF16181A), thickness: 2, indent: 80, endIndent: 80),
                          const Spacer(flex: 2),
                          Text('CERTIFICATE', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 38, color: const Color(0xFF08090A), letterSpacing: 6)),
                          Text('OF RESIDENTIAL CONDUCT', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo.shade800, letterSpacing: 2)),
                          const Spacer(flex: 2),
                          Text('THIS IS TO FORMALLY CERTIFY THAT', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 32),
                          Text(studentName.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.bodoniModa(fontSize: 36, fontWeight: FontWeight.w900, color: const Color(0xFF16181A))),
                          const SizedBox(height: 32),
                          Text('HAS DEMONSTRATED EXEMPLARY CONDUCT WHILE RESIDING AT', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                          const SizedBox(height: 12),
                          // 🧠 Building mapping
                          Text('UNIT ${room['room_number']} • ${room['building']?.toUpperCase() ?? 'CAMPUS BLOCK'}', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF16181A))),
                          const Spacer(flex: 2),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                             _metric('DISCIPLINE', '100%', Icons.verified_user_rounded),
                             const SizedBox(width: 40),
                             _metric('DEPLOYED', enrollmentDate.split(',')[0], Icons.calendar_today_rounded),
                          ]),
                          const Spacer(flex: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                             _sign('WARDEN', 'A. K. SHARMA'),
                             _seal(),
                             _sign('HQ DIRECTOR', 'M. P. SINGH'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String val, IconData icon) {
    return Column(children: [Icon(icon, size: 20, color: Colors.indigo.shade900), const SizedBox(height: 8), Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)), Text(val, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF16181A)))]);
  }

  Widget _sign(String label, String name) {
    return Column(children: [Text(name, style: GoogleFonts.dancingScript(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), Container(width: 100, height: 1.5, color: Colors.black12), const SizedBox(height: 4), Text(label, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))]);
  }

  Widget _seal() {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.indigo.shade900, width: 2)), child: Icon(Icons.shield_rounded, size: 32, color: Colors.indigo.shade900));
  }
}
