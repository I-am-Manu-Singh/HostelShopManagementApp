import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:animate_do/animate_do.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isBusy = false;
  String _status = 'INITIALIZING CAMERA...';
  bool _faceDetected = false;
  File? _capturedFace;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(options: FaceDetectorOptions(enableContours: true, enableClassification: true));
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
    
    _controller!.startImageStream((image) => _processCameraImage(image));
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final faces = await _faceDetector.processImage(
        InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation90deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        ),
      );
      
      if (mounted) {
        setState(() {
          _faceDetected = faces.isNotEmpty;
          _status = _faceDetected ? 'FACE DETECTED: PLEASE STAY STILL' : 'LOOK AT THE CAMERA...';
        });
      }
    } catch (_) {
      // Handle potential processing errors
    } finally {
      if (mounted) _isBusy = false;
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

  Future<void> _captureEnrollment() async {
    if (!_faceDetected || _controller == null) return;
    
    setState(() => _status = 'SAVING FACE DATA...');
    
    final xFile = await _controller!.takePicture();
    final path = join((await getTemporaryDirectory()).path, '${DateTime.now()}.jpg');
    await xFile.saveTo(path);

    setState(() {
      _capturedFace = File(path);
      _status = 'FACE DATA CAPTURED SUCCESSFULLY';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Mock embedding for now (in production, use a TFLite model to get real descriptor)
        final List<double> mockEmbedding = List.generate(512, (i) => i.toDouble() / 512.0);
        
        await _db.registerFaceData(mockEmbedding);
        
        await Supabase.instance.client.from('profiles').update({
          'is_verified': true,
          'metadata': {'face_enrolled': true, 'enrolled_at': DateTime.now().toIso8601String()}
        }).eq('id', user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FACE ENROLLED SUCCESSFULLY'), backgroundColor: Colors.greenAccent));
          Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'ENROLLMENT FAILED: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context))),
      body: Column(
        children: [
          const SizedBox(height: 48),
          Text('FACE REGISTRATION', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(height: 12),
          Text('SET UP FACE UNLOCK', style: GoogleFonts.outfit(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 60),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _faceDetected ? Colors.greenAccent : (isDark ? Colors.white12 : Colors.black12), width: 3)),
                  child: ClipOval(
                    child: _controller != null && _controller!.value.isInitialized
                        ? CameraPreview(_controller!)
                        : Container(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                  ),
                ),
                if (_faceDetected)
                   FadeIn(child: const Icon(Icons.center_focus_strong_rounded, color: Colors.greenAccent, size: 280)),
              ],
            ),
          ),
          const SizedBox(height: 60),
          Text(_status, style: GoogleFonts.outfit(color: _faceDetected ? Colors.greenAccent : (isDark ? Colors.white24 : Colors.black26), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(40),
            child: GestureDetector(
              onTap: _captureEnrollment,
              child: Container(
                width: double.infinity, height: 65,
                decoration: BoxDecoration(color: _faceDetected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.center,
                child: Text('REGISTER FACE', style: GoogleFonts.outfit(color: _faceDetected ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
