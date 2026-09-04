import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';

class GateTerminalScreen extends StatefulWidget {
  const GateTerminalScreen({super.key});

  @override
  State<GateTerminalScreen> createState() => _GateTerminalScreenState();
}

class _GateTerminalScreenState extends State<GateTerminalScreen> {
  CameraController? _cameraController;
  final MobileScannerController _scannerController = MobileScannerController();
  final FaceDetector _faceDetector = FaceDetector(options: FaceDetectorOptions(enableContours: false, enableClassification: false));
  final _db = DatabaseService();
  
  bool _isProcessing = false;
  String _terminalStatus = 'READY';
  Map<String, dynamic>? _lastScannedUser;
  Color _statusColor = Colors.indigoAccent;
  bool _showBarcode = true; // Default to barcode for faster login
  Timer? _clearTimer;
  DateTime _now = DateTime.now();
  late Timer _clockTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.isNotEmpty ? cameras.first : null;
      if (back != null) {
        _cameraController = CameraController(back, ResolutionPreset.high, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Camera Init Note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Camera permission is required for face detection terminal.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  String _selectedAttendanceType = 'gate'; // 'gate', 'mess', 'night', 'hostel'

  Future<void> _processSuccessfulDetection(String identifier, String method) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _clearTimer?.cancel();

    setState(() {
      _terminalStatus = 'VERIFYING...';
      _statusColor = Colors.amberAccent;
    });

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('*, rooms(room_number)')
          .or('id.eq.$identifier, biometric_id.eq.$identifier, phone_no.eq.$identifier')
          .maybeSingle();

      if (res != null) {
        // Query pending dues from hostel enrollment or mess card
        double pendingDue = 0;
        String pendingType = '';
        try {
          final enr = await Supabase.instance.client
              .from('hostel_enrollments')
              .select('total_price, paid_amount')
              .eq('user_id', res['id'])
              .maybeSingle();
          if (enr != null) {
            final tot = double.tryParse(enr['total_price']?.toString() ?? '0') ?? 0;
            final pd = double.tryParse(enr['paid_amount']?.toString() ?? '0') ?? 0;
            if (tot - pd > 0) {
              pendingDue = tot - pd;
              pendingType = 'Hostel Rent';
            }
          }
          final mc = await Supabase.instance.client
              .from('mess_cards')
              .select('status, expiry_date')
              .eq('user_id', res['id'])
              .maybeSingle();
          if (mc != null && (mc['status'] == 'Expired' || (mc['expiry_date'] != null && DateTime.parse(mc['expiry_date']).isBefore(DateTime.now())))) {
            pendingType = pendingType.isEmpty ? 'Mess Card Expired' : '$pendingType & Mess Card';
          }
        } catch (_) {}

        final success = await _db.markAttendance(
          type: _selectedAttendanceType, 
          studentId: res['id'],
          status: 'Present'
        );
        
        if (success) {
          setState(() {
            _lastScannedUser = res;
            if (pendingDue > 0 || pendingType.contains('Expired')) {
              _terminalStatus = 'ACCESS GRANTED (DUES PENDING: ₹${pendingDue.toInt()})';
              _statusColor = Colors.orangeAccent;
            } else {
              _terminalStatus = 'ACCESS GRANTED';
              _statusColor = Colors.greenAccent;
            }
          });

          if (pendingDue > 0 || pendingType.contains('Expired')) {
            _showPendingDuesFlash(
              studentName: res['full_name'] ?? 'STUDENT',
              pendingAmount: pendingDue,
              pendingNote: pendingType,
              roomNum: res['rooms']?['room_number']?.toString() ?? 'N/A',
            );
          }
        } else {
          _handleFailure('SYNC ERROR');
        }
      } else {
        _handleFailure('USER NOT FOUND');
      }
    } catch (e) {
      _handleFailure('ERROR');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _clearTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() {
            _lastScannedUser = null;
            _terminalStatus = 'READY';
            _statusColor = Colors.indigoAccent;
          });
        });
      }
    }
  }

  void _handleFailure(String msg) {
    setState(() {
      _terminalStatus = msg;
      _statusColor = Colors.redAccent;
    });
  }

  void _showPendingDuesFlash({
    required String studentName,
    required double pendingAmount,
    required String pendingNote,
    required String roomNum,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E0A0A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.redAccent.withOpacity(0.35), blurRadius: 40, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
              ),
              const SizedBox(height: 16),
              Text('NOTICE: PAYMENT DUE', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 12),
              Text(studentName.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('ROOM $roomNum', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                child: Column(
                  children: [
                    Text('PENDING BALANCE', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('₹${pendingAmount.toInt()}', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(pendingNote.toUpperCase(), style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('ACKNOWLEDGE & PASS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      body: Column(
        children: [
          // SCANNER PANEL (Top)
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                _showBarcode ? _buildBarcodeScanner() : _buildFaceScanner(),
                _buildScannerOverlay(),
                _buildTerminalMetadata(),
                _buildTechLines(),
              ],
            ),
          ),
          
          // DATA PANEL (Bottom)
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF08090A).withOpacity(0.8),
                border: const Border(top: BorderSide(color: Colors.white12, width: 1)),
              ),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      children: [
                        _buildAttendanceTypeSelector(),
                        const SizedBox(height: 20),
                        _buildStatusIndicator(),
                        const SizedBox(height: 32),
                        _lastScannedUser != null 
                          ? _buildUserDetails()
                          : _buildWaitingPrompt(),
                        const SizedBox(height: 32),
                        _buildTerminalControls(),
                      ],
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

  Widget _buildFaceScanner() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }
    return SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _cameraController!.value.previewSize!.height, height: _cameraController!.value.previewSize!.width, child: CameraPreview(_cameraController!))));
  }

  Widget _buildBarcodeScanner() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
           if (barcode.rawValue != null) {
             _processSuccessfulDetection(barcode.rawValue!, 'barcode');
           }
        }
      },
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border.all(color: _statusColor.withOpacity(0.2), width: 2),
      ),
      child: Center(
        child: FadeIn(
          duration: const Duration(seconds: 2),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7, 
            height: MediaQuery.of(context).size.width * 0.7, 
            decoration: BoxDecoration(
              border: Border.all(color: _statusColor, width: 2), 
              borderRadius: BorderRadius.circular(48),
              boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)],
            ),
            child: Stack(
              children: [
                _cornerPiece(top: 0, left: 0, angle: 0),
                _cornerPiece(top: 0, right: 0, angle: 1.57),
                _cornerPiece(bottom: 0, left: 0, angle: 4.71),
                _cornerPiece(bottom: 0, right: 0, angle: 3.14),
                Center(child: Container(width: 4, height: MediaQuery.of(context).size.width * 0.7, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, _statusColor.withOpacity(0.5), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cornerPiece({double? top, double? bottom, double? left, double? right, required double angle}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(width: 60, height: 60, decoration: BoxDecoration(border: Border(top: BorderSide(color: _statusColor, width: 8), left: BorderSide(color: _statusColor, width: 8)), borderRadius: const BorderRadius.only(topLeft: Radius.circular(24))))),
    );
  }

  Widget _buildAttendanceTypeSelector() {
    final types = [
      {'id': 'gate', 'label': 'GATE PASS', 'icon': Icons.door_sliding_rounded},
      {'id': 'mess', 'label': 'MESS', 'icon': Icons.restaurant_rounded},
      {'id': 'night', 'label': 'NIGHT ROLL', 'icon': Icons.nights_stay_rounded},
      {'id': 'hostel', 'label': 'HOSTEL', 'icon': Icons.home_work_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: types.map((t) {
          final isSelected = _selectedAttendanceType == t['id'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedAttendanceType = t['id'] as String),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigoAccent : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.indigoAccent : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t['label'] as String,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _statusColor.withOpacity(0.4), width: 2), gradient: LinearGradient(colors: [_statusColor.withOpacity(0.1), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Icon(_statusColor == Colors.greenAccent ? Icons.verified_user_rounded : (_statusColor == Colors.redAccent ? Icons.gpp_bad_rounded : Icons.shield_rounded), color: _statusColor, size: 54),
        ),
        const SizedBox(height: 20),
        Text(_terminalStatus, style: GoogleFonts.outfit(color: _statusColor, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 4)),
      ],
    );
  }

  Widget _buildUserDetails() {
    return FadeInUp(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _statusColor, width: 2)),
            child: CircleAvatar(radius: 64, backgroundColor: Colors.white.withOpacity(0.05), backgroundImage: (_lastScannedUser?['avatar_url'] != null) ? NetworkImage(_lastScannedUser!['avatar_url']) : null, child: (_lastScannedUser?['avatar_url'] == null) ? Icon(Icons.person_rounded, size: 60, color: _statusColor) : null),
          ),
          const SizedBox(height: 24),
          Text(_lastScannedUser?['full_name']?.toString().toUpperCase() ?? 'DETECTING...', style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(_lastScannedUser?['role']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'LOADING...', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 24),
          _detailRow(Icons.meeting_room_rounded, 'ROOM', _lastScannedUser?['rooms']?['room_number'] ?? 'N/A'),
          _detailRow(Icons.calendar_today_rounded, 'TIME', '${_now.hour}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.1))),
            child: const Row(children: [Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 14), SizedBox(width: 8), Text('IDENTITY VERIFIED', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))]),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, color: Colors.white24, size: 16), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 10))]),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildWaitingPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_2_rounded, color: Colors.indigoAccent, size: 48),
        const SizedBox(height: 16),
        Text('WAITING FOR SCAN', style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2.5)),
        const SizedBox(height: 8),
        Text('Present ID badge or Profile QR to the scanner', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildTerminalMetadata() {
    final timeStr = '${_now.hour}:${_now.minute.toString().padLeft(2, '0')}';
    return Positioned(
      top: 48, left: 48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)])), const SizedBox(width: 16), Text('LIVE · $timeStr', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2))]),
          const SizedBox(height: 8),
          Text('LOC: MAIN ACCESS GATE', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildTechLines() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: TechLinePainter(),
        ),
      ),
    );
  }

  Widget _buildTerminalControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _controlBtn(_showBarcode ? Icons.camera_front_rounded : Icons.qr_code_scanner_rounded, _showBarcode ? 'FACE AUTH' : 'SCAN QR', () => setState(() => _showBarcode = !_showBarcode)),
          _controlBtn(Icons.refresh_rounded, 'RESET', () => _initializeCamera()),
          _controlBtn(Icons.close_rounded, 'EXIT', () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _controlBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Icon(icon, color: Colors.white54, size: 24)), const SizedBox(height: 12), Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerController.dispose();
    _faceDetector.close();
    _clearTimer?.cancel();
    _clockTimer.cancel();
    super.dispose();
  }
}

class TechLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.indigoAccent.withOpacity(0.1)..strokeWidth = 1..style = PaintingStyle.stroke;
    
    // Vertical grid
    for (double i = 0; i < size.width; i += size.width / 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    // Horizontal grid
    for (double i = 0; i < size.height; i += size.height / 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
