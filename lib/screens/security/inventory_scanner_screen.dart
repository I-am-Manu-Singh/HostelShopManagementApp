import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/product_lookup_service.dart';
import '../../models/shop.dart';

enum ScannerWorkflowMode { single, batch }

class ScannedBatchItem {
  final String barcode;
  final BarcodeProductLookupResult? lookup;
  bool isSaving;
  bool isSaved;
  String? error;

  ScannedBatchItem({
    required this.barcode,
    this.lookup,
    this.isSaving = false,
    this.isSaved = false,
    this.error,
  });
}

class InventoryScannerScreen extends StatefulWidget {
  final List<ShopItem>? existingCatalog;
  const InventoryScannerScreen({super.key, this.existingCatalog});

  @override
  State<InventoryScannerScreen> createState() => _InventoryScannerScreenState();
}

class _InventoryScannerScreenState extends State<InventoryScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  ScannerWorkflowMode _mode = ScannerWorkflowMode.single;
  bool _isSingleScanned = false;
  
  // Continuous batch queue
  final List<ScannedBatchItem> _batchItems = [];
  final Set<String> _scannedBarcodesSet = {};
  bool _isBatchProcessing = false;
  int _lastScanTimeMs = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _mode == ScannerWorkflowMode.single ? 'ITEM DISCOVERY SCAN' : 'CONTINUOUS BATCH SCAN (${_batchItems.length})',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, _mode == ScannerWorkflowMode.batch ? _batchItems.length : null),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.bolt_rounded, color: Colors.white), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white), onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcodeDetected,
          ),
          _buildScannerOverlay(context),
          _buildModeToggle(isDark),
          if (_mode == ScannerWorkflowMode.batch) _buildBatchDrawer(isDark),
        ],
      ),
    );
  }

  void _handleBarcodeDetected(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final b in barcodes) {
      final code = b.rawValue?.trim();
      if (code == null || code.isEmpty) continue;

      if (_mode == ScannerWorkflowMode.single) {
        if (_isSingleScanned) return;
        _isSingleScanned = true;
        Navigator.pop(context, code);
        return;
      }

      // Continuous batch mode: throttle to avoid re-reading same barcode in under 1.5s
      if (now - _lastScanTimeMs < 1200) continue;
      if (_scannedBarcodesSet.contains(code)) continue;

      _lastScanTimeMs = now;
      _scannedBarcodesSet.add(code);

      final batchItem = ScannedBatchItem(barcode: code, isSaving: true);
      setState(() {
        _batchItems.insert(0, batchItem);
      });

      // Beep / Feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned barcode: $code. Resolving details...'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.indigoAccent,
        ),
      );

      // Async online lookup in sequence
      _resolveBatchItem(batchItem);
    }
  }

  Future<void> _resolveBatchItem(ScannedBatchItem item) async {
    try {
      final res = await ProductLookupService().fetchProductDetailsOnline(item.barcode);
      if (mounted) {
        setState(() {
          final idx = _batchItems.indexWhere((it) => it.barcode == item.barcode);
          if (idx != -1) {
            _batchItems[idx] = ScannedBatchItem(
              barcode: item.barcode,
              lookup: res,
              isSaving: false,
              isSaved: false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          item.isSaving = false;
          item.error = e.toString();
        });
      }
    }
  }

  Widget _buildModeToggle(bool isDark) {
    return Positioned(
      top: 12,
      left: 20,
      right: 20,
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mode = ScannerWorkflowMode.single),
                child: Container(
                  decoration: BoxDecoration(
                    color: _mode == ScannerWorkflowMode.single ? Colors.indigoAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'SINGLE ADD',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mode = ScannerWorkflowMode.batch),
                child: Container(
                  decoration: BoxDecoration(
                    color: _mode == ScannerWorkflowMode.batch ? Colors.amberAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'BATCH MULTI-SCAN',
                    style: GoogleFonts.outfit(
                      color: _mode == ScannerWorkflowMode.batch ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.68;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size,
            height: size * 0.8,
            decoration: BoxDecoration(
              border: Border.all(color: _mode == ScannerWorkflowMode.batch ? Colors.amberAccent : Colors.indigoAccent, width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                _scanCorner(0, 0, 36, 0, 0, 36),
                _scanCorner(size, 0, -36, 0, 0, 36),
                _scanCorner(0, size * 0.8, 36, 0, 0, -36),
                _scanCorner(size, size * 0.8, -36, 0, 0, -36),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
            child: Text(
              _mode == ScannerWorkflowMode.single
                  ? 'ALIGN BARCODE TO OPEN & EDIT PRODUCT'
                  : 'SCAN IN SEQUENCE • TAP STOP WHEN DONE',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCorner(double left, double top, double dx1, double dy1, double dx2, double dy2) {
    final color = _mode == ScannerWorkflowMode.batch ? Colors.amberAccent : Colors.indigoAccent;
    return Positioned(
      left: left + (dx1 < 0 ? dx1 : 0),
      top: top + (dy2 < 0 ? dy2 : 0),
      child: Container(
        width: dx1.abs() == 0 ? 3 : dx1.abs(),
        height: dy2.abs() == 0 ? 3 : dy2.abs(),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildBatchDrawer(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCANNED BATCH QUEUE (${_batchItems.length})',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    const Text(
                      'Auto-resolved from Indian FMCG registries',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: _isBatchProcessing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(_isBatchProcessing ? 'SAVING...' : 'STOP & COMMIT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isBatchProcessing || _batchItems.isEmpty) ? null : _commitBatchToDatabase,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _batchItems.isEmpty
                  ? Center(
                      child: Text('Scan items one after another to populate queue.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                    )
                  : ListView.builder(
                      itemCount: _batchItems.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (ctx, i) {
                        final item = _batchItems[i];
                        final l = item.lookup;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: item.isSaved ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.isSaved ? Icons.check_circle : (l != null && l.found ? Icons.inventory_2_rounded : Icons.pending_rounded),
                                color: item.isSaved ? Colors.greenAccent : (l != null && l.found ? Colors.amberAccent : Colors.white38),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l?.name ?? 'Resolving Product...',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Code: ${item.barcode} • Brand: ${l?.brand ?? "Local"} • ${l?.quantity ?? "1 Unit"}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.isSaving)
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent))
                              else if (item.isSaved)
                                const Text('SAVED', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commitBatchToDatabase() async {
    setState(() => _isBatchProcessing = true);
    int savedCount = 0;

    for (int i = 0; i < _batchItems.length; i++) {
      final item = _batchItems[i];
      if (item.isSaved) continue;

      final l = item.lookup;
      final productName = (l != null && l.name != null && l.name!.trim().isNotEmpty) ? l.name!.trim() : 'Product ${item.barcode}';
      final category = l?.category ?? 'Groceries';
      final brand = l?.brand;
      final weight = l?.quantity ?? l?.servingSize;
      final img = l?.imageUrl;
      final desc = l?.description;
      final ing = l?.ingredients;
      final pack = l?.packageType;
      final nutr = l?.nutritionalInfo;
      
      final List<String> tags = [];
      if (l?.allergens != null) {
        for (final a in l!.allergens!) {
          tags.add('Contains $a');
        }
      }

      final saved = await ProductLookupService().registerProductInDatabase(
        name: productName,
        barcode: item.barcode,
        price: 10.0, // Baseline editable placeholder price
        costPrice: 8.0,
        stockQuantity: 50,
        category: category,
        brand: brand,
        weightMl: weight,
        imageUrl: img,
        description: desc,
        ingredients: ing,
        packageType: pack,
        tags: tags.isNotEmpty ? tags : null,
        nutritionalInfo: nutr,
      );

      if (saved != null) {
        savedCount++;
        setState(() {
          _batchItems[i].isSaved = true;
        });
      }
    }

    if (mounted) {
      setState(() => _isBatchProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully committed $savedCount new products to inventory database!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, savedCount);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

