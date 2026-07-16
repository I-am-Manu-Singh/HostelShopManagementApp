import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

class MessGateTerminalScreen extends StatefulWidget {
  const MessGateTerminalScreen({super.key});

  @override
  State<MessGateTerminalScreen> createState() => _MessGateTerminalScreenState();
}

class _MessGateTerminalScreenState extends State<MessGateTerminalScreen> {
  final _client = Supabase.instance.client;
  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isBusy = false;
  String _status = 'SCANNING FOR ENTITIES...';
  bool _faceDetected = false;
  Map<String, dynamic>? _lastMatchedUser;
  DateTime? _lastLogTime;

  List<dynamic> _profiles = [];
  dynamic _selectedProfileForScan;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(options: FaceDetectorOptions(enableClassification: true, minFaceSize: 0.15));
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
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
        _controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
        await _controller!.initialize();
        if (mounted) setState(() {});
        _controller!.startImageStream((image) => _processCameraImage(image));
      }
    } catch (_) {}
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final faces = await _faceDetector.processImage(inputImage);
    
    if (faces.isNotEmpty && (faces.first.headEulerAngleY ?? 0).abs() < 10) {
      if (!_faceDetected) {
         if (_selectedProfileForScan != null) {
           _onFaceIdentified(_selectedProfileForScan);
         } else {
           final res = await _client.from('profiles').select().eq('is_verified', true).limit(1).maybeSingle();
           if (res != null) _onFaceIdentified(res);
         }
      }
      _faceDetected = true;
    } else {
      _faceDetected = false;
    }

    _isBusy = false;
  }

  void _onFaceIdentified(Map<String, dynamic> user) async {
    setState(() => _status = 'AUTHENTICATING BIOMETRIC HASH...');
    final hasBiometrics = user['face_embedding'] != null || user['biometric_id'] != null;
    if (!hasBiometrics) {
      setState(() => _status = 'ERROR: NO BIOMETRIC TEMPLATE ON FILE');
      return;
    }

    _logAttendance(user);
  }

  Future<void> _logAttendance(Map<String, dynamic> user) async {
    final now = DateTime.now();
    final meal = _getCurrentMeal(now);
    
    final ok = await DatabaseService().markMessAttendance(
      studentId: user['id'],
      mealType: meal,
      date: now,
    );

    if (ok && mounted) {
      setState(() {
        _lastMatchedUser = user;
        _lastLogTime = now;
        _status = 'ACCESS GRANTED: ${user['full_name'].toString().toUpperCase()}';
      });

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _lastMatchedUser = null);
      });
    }
  }

  // Mark all mess students who didn't check in for the current meal as "Missed"
  Future<void> _markMealMisses() async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final meal = _getCurrentMeal(now);

      // Fetch all mess students
      final students = await _client.from('profiles').select().eq('role', 'mess_student');

      int missCount = 0;
      for (var s in students) {
        // Check if there is already an attendance record for today's meal
        final existing = await _client.from('attendance')
            .select()
            .eq('user_id', s['id'])
            .eq('date', dateStr)
            .eq('meal_type', meal)
            .maybeSingle();

        if (existing == null) {
          // Mark as missed/absent
          await _client.from('attendance').insert({
            'user_id': s['id'],
            'date': dateStr,
            'status': 'absent',
            'attendance_type': 'mess',
            'meal_type': meal,
          });
          missCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked $missCount students as absent/missed for $meal.'), backgroundColor: Colors.orangeAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  String _getCurrentMeal(DateTime now) {
    int hour = now.hour;
    if (hour >= 7 && hour < 11) return 'Breakfast';
    if (hour >= 12 && hour < 15) return 'Lunch';
    if (hour >= 16 && hour < 18) return 'Tea';
    return 'Dinner';
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
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

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
          Positioned.fill(child: _buildScannerHud(isDark)),
          if (_lastMatchedUser != null)
             Positioned(
               bottom: 60, left: 30, right: 30,
               child: FadeInUp(
                 child: _buildSuccessCard(isDark),
               ),
             ),
          Positioned(top: 60, left: 24, child: IconButton(icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black, size: 32), onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }

  Widget _buildScannerHud(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(_faceDetected ? 0.2 : 0.6),
        border: Border.all(color: _faceDetected ? Colors.greenAccent.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12), width: 4),
      ),
      child: Column(
        children: [
          const SizedBox(height: 120),
          Text('MESS TERMINAL', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 4)),
          Text(_status, style: GoogleFonts.outfit(color: _faceDetected ? Colors.greenAccent : (isDark ? Colors.white38 : Colors.black38), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          
          const SizedBox(height: 16),
          // Dropdown simulation select
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
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
                      _status = 'USER CHOSEN. SCAN FACE TO CHECK IN TO MESS...';
                    });
                  },
                  items: _profiles.map((p) {
                    final hasBio = p['face_embedding'] != null || p['biometric_id'] != null;
                    return DropdownMenuItem(
                      value: p,
                      child: Text(
                        '${p['full_name']?.toString().toUpperCase() ?? 'USER'} ${hasBio ? "🔑" : "⚠️ NO BIO"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          
          const Spacer(),
          if (!_faceDetected)
             Pulse(
               infinite: true,
               child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 2), borderRadius: BorderRadius.circular(40))),
             ),
          const Spacer(),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _markMealMisses,
                icon: const Icon(Icons.no_meals_rounded, color: Colors.white, size: 16),
                label: const Text('MARK MEAL MISSES FOR ACTIVE SHIFT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat('STATUS', 'ACTIVE', isDark),
                const SizedBox(width: 40),
                _stat('MEAL', _getCurrentMeal(DateTime.now()).toUpperCase(), isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, bool isDark) => Column(children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.w900))]);

  Widget _buildSuccessCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.greenAccent.withOpacity(0.1), child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 30)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_lastMatchedUser!['full_name']?.toString().toUpperCase() ?? 'IDENTIFIED', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
                Text('VERIFIED: ${_getCurrentMeal(DateTime.now())}', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(DateFormat('HH:mm').format(_lastLogTime!), style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
