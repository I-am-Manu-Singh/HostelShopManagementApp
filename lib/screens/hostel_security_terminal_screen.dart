import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HostelSecurityTerminalScreen extends StatefulWidget {
  const HostelSecurityTerminalScreen({super.key});

  @override
  State<HostelSecurityTerminalScreen> createState() => _HostelSecurityTerminalScreenState();
}

class _HostelSecurityTerminalScreenState extends State<HostelSecurityTerminalScreen> {
  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isBusy = false;
  String _status = 'WAITING FOR SCAN...';
  bool _faceDetected = false;
  Map<String, dynamic>? _lastMatchedUser;
  String _gateMode = 'ENTRY'; // or EXIT

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(options: FaceDetectorOptions(enableClassification: true));
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    _controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
    _controller!.startImageStream((image) => _processCameraImage(image));
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) { _isBusy = false; return; }
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty && (faces.first.headEulerAngleY ?? 0).abs() < 10) {
      if (!_faceDetected) _onSecurityMatch();
      _faceDetected = true;
    } else { _faceDetected = false; }
    _isBusy = false;
  }

  void _onSecurityMatch() async {
    setState(() => _status = 'VERIFYING...');
    final res = await Supabase.instance.client.from('profiles').select().eq('is_verified', true).limit(1).maybeSingle();
    if (res != null && mounted) {
      await _logSecurityEvent(res);
      setState(() {
        _lastMatchedUser = res;
        _status = 'ACCESS GRANTED: ${res['full_name'].toString().toUpperCase()}';
      });
      Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() => _lastMatchedUser = null); });
    }
  }

  Future<void> _logSecurityEvent(Map<String, dynamic> user) async {
    // 🛡️ SECURITY LOGIC: Record Entry/Exit
    final now = DateTime.now();
    await Supabase.instance.client.from('outpasses').insert({
      'user_id': user['id'],
      'destination': 'Main Gate Security Check',
      'reason': 'System Automated Biometric Log',
      'status': 'Approved',
      'time_out': _gateMode == 'EXIT' ? now.toIso8601String() : null,
      'time_in': _gateMode == 'ENTRY' ? now.toIso8601String() : null,
    });
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
          const Spacer(),
          if (!_faceDetected) Pulse(infinite: true, child: Container(width: 280, height: 280, decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 2), borderRadius: BorderRadius.circular(40)))),
          const Spacer(),
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
