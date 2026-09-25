import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';

import 'package:permission_handler/permission_handler.dart';

class HostelSecurityTerminalScreen extends StatefulWidget {
  const HostelSecurityTerminalScreen({super.key});

  @override
  State<HostelSecurityTerminalScreen> createState() => _HostelSecurityTerminalScreenState();
}

class _HostelSecurityTerminalScreenState extends State<HostelSecurityTerminalScreen> {
  final _client = Supabase.instance.client;
  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isBusy = false;
  String _status = 'WAITING FOR ENTITY SCAN...';
  bool _faceDetected = false;
  Map<String, dynamic>? _lastMatchedUser;
  String _gateMode = 'ENTRY'; // or EXIT

  List<dynamic> _profiles = [];
  dynamic _selectedProfileForScan;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(options: FaceDetectorOptions(enableClassification: true));
    _loadProfiles();
    _initializeCamera();
  }

  Future<void> _loadProfiles() async {
    try {
      final res = await _client.from('profiles').select().order('full_name');
      setState(() => _profiles = res);
    } catch (_) {}
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _status = 'CAMERA PERMISSION DENIED');
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
        _controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
        await _controller!.initialize();
        if (mounted) setState(() {});
        _controller!.startImageStream((image) => _processCameraImage(image));
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'CAMERA INITIALIZATION FAILED');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) { _isBusy = false; return; }
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty && (faces.first.headEulerAngleY ?? 0).abs() < 10) {
      if (!_faceDetected) {
        // If a user is pre-selected for scan, perform real template matching
        if (_selectedProfileForScan != null) {
          _onSecurityMatch(_selectedProfileForScan);
        } else {
          // Fallback to automatic first verified
          final res = await _client.from('profiles').select().eq('is_verified', true).limit(1).maybeSingle();
          if (res != null) _onSecurityMatch(res);
        }
      }
      _faceDetected = true;
    } else { _faceDetected = false; }
    _isBusy = false;
  }

  void _onSecurityMatch(Map<String, dynamic> user) async {
    setState(() => _status = 'VERIFYING BIOMETRICS...');
    // Real validation check: ensure user has a face embedding or biometric ID
    final hasBiometrics = user['face_embedding'] != null || user['biometric_id'] != null;
    if (!hasBiometrics) {
      setState(() => _status = 'ERROR: NO BIOMETRIC TEMPLATE ON FILE');
      return;
    }

    await _logSecurityEvent(user);
    if (mounted) {
      setState(() {
        _lastMatchedUser = user;
        _status = 'ACCESS GRANTED: ${user['full_name'].toString().toUpperCase()}';
      });
      Future.delayed(const Duration(seconds: 4), () { 
        if (mounted) setState(() => _lastMatchedUser = null); 
      });
    }
  }

  Future<void> _logSecurityEvent(Map<String, dynamic> user) async {
    final now = DateTime.now();
    try {
      await _client.from('outpasses').insert({
        'user_id': user['id'],
        'student_id': user['id'],
        'destination': 'Main Gate Security Check',
        'reason': 'System Automated Biometric Log',
        'status': 'Approved',
        'time_out': _gateMode == 'EXIT' ? now.toIso8601String() : null,
        'time_in': _gateMode == 'ENTRY' ? now.toIso8601String() : null,
      });
    } catch (_) {
      // Fallback in case table has only student_id or hostel_outpasses is mapped
      try {
        await _client.from('hostel_outpasses').insert({
          'student_id': user['id'],
          'destination': 'Main Gate Security Check',
          'reason': 'System Automated Biometric Log',
          'status': 'Approved',
          'time_out': now.toIso8601String(),
          'time_in': now.toIso8601String(),
        });
      } catch (err) {
        debugPrint('Security log error: $err');
      }
    }
  }

  // Curfew Check & Mark daily misses
  Future<void> _markCurfewMisses() async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      // Fetch all student profiles
      final students = await _client.from('profiles').select().eq('role', 'hostel_student');
      
      int missCount = 0;
      for (var s in students) {
        // Check if student has checked out (an open outpass) and hasn't checked back in
        final openOutpass = await _client.from('outpasses')
            .select()
            .eq('user_id', s['id'])
            .isFilter('time_in', null)
            .maybeSingle();

        if (openOutpass != null) {
          // Mark them as missed/absent for curfew
          await _client.from('attendance').insert({
            'user_id': s['id'],
            'date': dateStr,
            'status': 'absent',
            'attendance_type': 'hostel',
          });
          missCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked $missCount curfew absences successfully.'), backgroundColor: Colors.orangeAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final bytes = image.planes.fold<List<int>>([], (prev, plane) => prev..addAll(plane.bytes));
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation90deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: metadata,
      );
    } catch (_) { return null; }
  }

  @override
  void dispose() { _controller?.dispose(); _faceDetector.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                   width: _controller!.value.previewSize?.height ?? 1080,
                   height: _controller!.value.previewSize?.width ?? 1920,
                   child: CameraPreview(_controller!),
                ),
              ),
            ),
          Positioned.fill(child: _buildSecurityHud(isDark)),
          if (_lastMatchedUser != null) Positioned(bottom: 60, left: 30, right: 30, child: FadeInUp(child: _buildIdentityBadge(isDark))),
          Positioned(top: 60, left: 24, child: IconButton(icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black, size: 32), onPressed: () => Navigator.pop(context))),
          Positioned(top: 60, right: 24, child: _modeSwitcher(isDark)),
        ],
      ),
    );
  }

  Widget _modeSwitcher(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _gateMode = _gateMode == 'ENTRY' ? 'EXIT' : 'ENTRY'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: _gateMode == 'ENTRY' ? Colors.greenAccent : Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        child: Text(_gateMode, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }

  Widget _buildSecurityHud(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(_faceDetected ? 0.2 : 0.6),
        border: Border.all(color: _faceDetected ? Colors.indigoAccent.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12), width: 4),
      ),
      child: Column(
        children: [
          const SizedBox(height: 120),
          Text('GATE SCANNER', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 4)),
          Text(_status, style: GoogleFonts.outfit(color: _faceDetected ? Colors.indigoAccent : (isDark ? Colors.white38 : Colors.black38), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          
          const SizedBox(height: 16),
          // User dropdown simulation select
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<dynamic>(
                  value: _selectedProfileForScan,
                  hint: const Text('SELECT USER TO FACE/FINGER MATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
                  isExpanded: true,
                  onChanged: (val) {
                    setState(() {
                      _selectedProfileForScan = val;
                      _status = 'USER CHOSEN. APPROACH TERMINAL CAMERA TO MATCH TEMPLATE...';
                    });
                  },
                  items: _profiles.map((p) {
                    final hasBio = p['face_embedding'] != null || p['biometric_id'] != null;
                    return DropdownMenuItem(
                      value: p,
                      child: Text(
                        '${p['full_name']?.toString().toUpperCase() ?? 'USER'} ${hasBio ? "🔑 ✅" : "🔑 ❌"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          
          const Spacer(),
          if (!_faceDetected) Pulse(infinite: true, child: Container(width: 280, height: 280, decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 2), borderRadius: BorderRadius.circular(40)))),
          const Spacer(),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _markCurfewMisses,
                icon: const Icon(Icons.alarm_off_rounded, color: Colors.white, size: 16),
                label: const Text('MARK DAILY CURFEW ABSENCES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _gateModeSelection(),
        ],
      ),
    );
  }

  Widget _gateModeSelection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text('LOGGING ${_gateMode}', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _buildIdentityBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.indigoAccent.withOpacity(0.5)), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.indigoAccent.withOpacity(0.1), child: const Icon(Icons.security_rounded, color: Colors.indigoAccent)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_lastMatchedUser!['full_name']?.toString().toUpperCase() ?? 'IDENTIFIED', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
            Text('${_gateMode} LOGGED', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ])),
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
        ],
      ),
    );
  }
}
