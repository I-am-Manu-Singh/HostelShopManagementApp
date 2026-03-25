import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

class InventoryScannerScreen extends StatefulWidget {
  const InventoryScannerScreen({super.key});

  @override
  State<InventoryScannerScreen> createState() => _InventoryScannerScreenState();
}

class _InventoryScannerScreenState extends State<InventoryScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('ITEM DISCOVERY SCAN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.bolt_rounded, color: Colors.white), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white), onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _isScanned = true;
                  Navigator.pop(context, barcode.rawValue);
                }
              }
            },
          ),
          _buildScannerOverlay(context),
          _buildHelperPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.indigoAccent, width: 2),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              children: [
                _scanCorner(0, 0, 40, 0, 0, 40),
                _scanCorner(size, 0, -40, 0, 0, 40),
                _scanCorner(0, size, 40, 0, 0, -40),
                _scanCorner(size, size, -40, 0, 0, -40),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Text('ALIGN BARCODE WITHIN THE FRAME', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _scanCorner(double left, double top, double dx1, double dy1, double dx2, double dy2) {
    return Positioned(
      left: left + (dx1 < 0 ? dx1 : 0),
      top: top + (dy2 < 0 ? dy2 : 0),
      child: Container(
        width: dx1.abs() == 0 ? 2 : dx1.abs(),
        height: dy2.abs() == 0 ? 2 : dy2.abs(),
        decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildHelperPanel(bool isDark) {
    return Positioned(
      bottom: 60, left: 24, right: 24,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.indigoAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SMART_INDEXER_ACTIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Recognizing standard UPC, EAN, and QR formats.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
