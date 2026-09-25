import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shop.dart';
import '../../services/barcode_wedge_service.dart';
import '../../services/database_service.dart';
import '../../services/pos_hardware_service.dart';
import 'pos_hardware_settings_dialog.dart';
import 'pos_stock_inward_dialog.dart';
import 'pos_payment_dialog.dart';
import 'pos_analytics_report_screen.dart';
import '../../services/product_lookup_service.dart';

class TabletPosTerminalScreen extends StatefulWidget {
  const TabletPosTerminalScreen({super.key});

  @override
  State<TabletPosTerminalScreen> createState() => _TabletPosTerminalScreenState();
}

class _TabletPosTerminalScreenState extends State<TabletPosTerminalScreen> {
  final _db = DatabaseService();
  final _client = Supabase.instance.client;
  final _focusNode = FocusNode();

  List<ShopItem> _catalog = [];
  List<ShopItem> _filteredCatalog = [];
  List<String> _dynamicCategories = ['All'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoadingCatalog = true;

  // Running Cart
  final List<OrderItem> _cart = [];
  double _cartDiscount = 0.0;
  bool _isCameraScannerOpen = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  MobileScannerController? _scannerController;

  // Student Account Selection
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;

  // Parked / Held Carts
  final List<Map<String, dynamic>> _heldCarts = [];

  RealtimeChannel? _catalogRealtimeSub;

  @override
  void initState() {
    super.initState();
    PosHardwareService().init();
    _loadCatalog();
    _loadStudents();
    BarcodeWedgeService().addListener(_onHardwareBarcodeScanned);
    _subscribeToCatalogChanges();
  }

  void _subscribeToCatalogChanges() {
    try {
      _catalogRealtimeSub = _client
          .channel('public:shop_items:pos')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shop_items',
            callback: (payload) {
              if (mounted) {
                // Silently refresh catalog so stock numbers and prices match immediately across terminals
                _db.fetchShopItems().then((items) {
                  if (mounted) {
                    setState(() {
                      _catalog = items;
                      _extractCategoriesFromCatalog();
                      _applyFilters();
                    });
                  }
                });
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_catalogRealtimeSub != null) {
      _client.removeChannel(_catalogRealtimeSub!);
    }
    _scannerController?.dispose();
    BarcodeWedgeService().removeListener(_onHardwareBarcodeScanned);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoadingCatalog = true);
    final items = await _db.fetchShopItems();
    if (mounted) {
      setState(() {
        _catalog = items;
        _extractCategoriesFromCatalog();
        _applyFilters();
        _isLoadingCatalog = false;
      });
    }
  }

  void _extractCategoriesFromCatalog() {
    final Set<String> categoriesSet = {'All'};
    for (var item in _catalog) {
      if (item.category.trim().isNotEmpty) {
        categoriesSet.add(item.category.trim());
      }
    }
    setState(() {
      _dynamicCategories = categoriesSet.toList();
      if (!_dynamicCategories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
    });
  }

  Future<void> _loadStudents() async {
    try {
      final res = await _client.from('profiles').select('id, full_name, balance, role').limit(100);
      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (_) {}
  }

  void _applyFilters() {
    setState(() {
      _filteredCatalog = _catalog.where((it) {
        final matchesCategory = _selectedCategory == 'All' || 
            it.category.trim().toLowerCase() == _selectedCategory.toLowerCase();
        
        final matchesQuery = _searchQuery.isEmpty ||
            it.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (it.skuQr?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            it.category.toLowerCase().contains(_searchQuery.toLowerCase());
            
        return matchesCategory && matchesQuery;
      }).toList();
    });
  }

  DateTime? _lastScannedTimestamp;
  String? _lastScannedBarcode;

  Future<void> _onHardwareBarcodeScanned(String barcode) async {
    if (!mounted) return;
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return;

    final now = DateTime.now();
    // Debounce duplicate barcode scans within 1.2 seconds for continuous scanners
    if (_lastScannedBarcode == cleanCode &&
        _lastScannedTimestamp != null &&
        now.difference(_lastScannedTimestamp!).inMilliseconds < 1200) {
      return;
    }
    _lastScannedBarcode = cleanCode;
    _lastScannedTimestamp = now;

    try {
      final item = _catalog.firstWhere(
        (it) => (it.barcode?.toLowerCase().trim() == cleanCode.toLowerCase()) ||
                (it.skuQr?.toLowerCase().trim() == cleanCode.toLowerCase()) ||
                (it.id.toLowerCase().trim() == cleanCode.toLowerCase()),
      );
      _addToCart(item);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.amberAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scanned: ${item.name} (+1 in cart)',
                  // FIX: Added white color styling to ensure readability on dark background
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  // Alternative if you prefer your global font family:
                  // style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 900),
          backgroundColor: const Color(0xFF1E293B),
        ),
      );
      return;
    } catch (_) {}

    final onlineResult = await ProductLookupService().fetchProductDetailsOnline(cleanCode);
    if (!mounted) return;
    _showQuickAddProductDialog(cleanCode, onlineResult);
  }

  void _showQuickAddProductDialog(String barcode, BarcodeProductLookupResult lookup) {
    final nameCtrl = TextEditingController(text: lookup.name ?? '');
    final priceCtrl = TextEditingController(text: '');
    final costCtrl = TextEditingController(text: '');
    final brandCtrl = TextEditingController(text: lookup.brand ?? '');
    final categoryCtrl = TextEditingController(text: lookup.category ?? 'Fast Food');
    bool isSaving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(lookup.found ? Icons.auto_awesome : Icons.add_circle, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lookup.found ? "Online Registry Match" : "New Barcode Entry",
                  style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Barcode: $barcode", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                    decoration: const InputDecoration(labelText: "Product Name *", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                          decoration: const InputDecoration(labelText: "Selling Price (₹) *", border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                          decoration: const InputDecoration(labelText: "Cost / MRP (₹)", border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      if (name.isEmpty || price <= 0) return;

                      setDialogState(() => isSaving = true);
                      final newItem = await ProductLookupService().registerProductInDatabase(
                        name: name,
                        barcode: barcode,
                        price: price,
                        costPrice: double.tryParse(costCtrl.text.trim()),
                        brand: brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
                        category: categoryCtrl.text.trim().isEmpty ? 'Fast Food' : categoryCtrl.text.trim(),
                        imageUrl: lookup.imageUrl,
                        description: lookup.description,
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        if (newItem != null && mounted) {
                          setState(() {
                            _catalog.add(newItem);
                            _extractCategoriesFromCatalog();
                            _applyFilters();
                            _addToCart(newItem);
                          });
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Save & Add", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(ShopItem item) {
    setState(() {
      final existingIndex = _cart.indexWhere((it) => it.id == item.id);
      if (existingIndex >= 0) {
        final current = _cart[existingIndex];
        _cart[existingIndex] = OrderItem(
          id: current.id,
          name: current.name,
          qty: current.qty + 1,
          price: current.price,
          taxRate: current.taxRate,
          hsnCode: current.hsnCode,
        );
      } else {
        _cart.add(OrderItem(
          id: item.id,
          name: item.name,
          qty: 1,
          price: item.price,
          taxRate: item.taxRate,
          hsnCode: item.hsnCode,
        ));
      }
    });
  }

  void _updateCartQuantity(int index, int delta) {
    setState(() {
      if (index < 0 || index >= _cart.length) return;
      final current = _cart[index];
      final newQty = current.qty + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = OrderItem(
          id: current.id,
          name: current.name,
          qty: newQty,
          price: current.price,
          taxRate: current.taxRate,
          hsnCode: current.hsnCode,
        );
      }
    });
  }

  void _setCustomCartQuantity(int index, int exactQty) {
    setState(() {
      if (index < 0 || index >= _cart.length) return;
      if (exactQty <= 0) {
        _cart.removeAt(index);
      } else {
        final current = _cart[index];
        _cart[index] = OrderItem(
          id: current.id,
          name: current.name,
          qty: exactQty,
          price: current.price,
          taxRate: current.taxRate,
          hsnCode: current.hsnCode,
        );
      }
    });
  }

  void _showCustomQuantityDialog(int index, bool isDark) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    final qtyCtrl = TextEditingController(text: '${item.qty}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF16181D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Custom Quantity: ${item.name}",
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter exact quantity or batch units to add/bill:", style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                labelText: "Quantity (Units)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              final parsed = int.tryParse(qtyCtrl.text.trim());
              if (parsed != null && parsed >= 0) {
                _setCustomCartQuantity(index, parsed);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _cartDiscount = 0.0;
      _selectedStudent = null;
    });
  }

  void _holdCurrentCart() {
    if (_cart.isEmpty) return;
    setState(() {
      _heldCarts.add({
        'name': "Held #${_heldCarts.length + 1} (${_selectedStudent?['full_name'] ?? 'Walk-in'})",
        'items': List<OrderItem>.from(_cart),
        'discount': _cartDiscount,
        'student': _selectedStudent,
        'time': DateTime.now(),
      });
      _clearCart();
    });
  }

  void _recallHeldCart(int index) {
    if (index < 0 || index >= _heldCarts.length) return;
    final held = _heldCarts.removeAt(index);
    setState(() {
      _cart.clear();
      _cart.addAll(List<OrderItem>.from(held['items']));
      _cartDiscount = held['discount'] ?? 0.0;
      _selectedStudent = held['student'];
    });
  }

  double get _subtotal => _cart.fold(0.0, (sum, it) => sum + (it.price * it.qty));

  // Dynamic GST calculation based on item-specific tax rate
  double get _cgst {
    if (_subtotal == 0) return 0.0;
    final discountRatio = _cartDiscount > 0 ? (1.0 - (_cartDiscount / _subtotal)).clamp(0.0, 1.0) : 1.0;
    return _cart.fold(0.0, (sum, it) {
      final rate = it.taxRate > 0 ? it.taxRate : 0.0;
      final lineTotal = it.price * it.qty * discountRatio;
      return sum + (lineTotal * (rate / 200.0));
    });
  }

  double get _sgst {
    if (_subtotal == 0) return 0.0;
    final discountRatio = _cartDiscount > 0 ? (1.0 - (_cartDiscount / _subtotal)).clamp(0.0, 1.0) : 1.0;
    return _cart.fold(0.0, (sum, it) {
      final rate = it.taxRate > 0 ? it.taxRate : 0.0;
      final lineTotal = it.price * it.qty * discountRatio;
      return sum + (lineTotal * (rate / 200.0));
    });
  }

  double get _netTotal => (_subtotal - _cartDiscount).clamp(0.0, 999999.0) + _cgst + _sgst;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => BarcodeWedgeService().handleKeyEvent(event),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          top: false,
          bottom: false,
          left: false,
          right: false,
          child: Column(
            children: [
              _buildTopBar(textColor, isDark),
              Expanded(
                child: isLandscape
                    ? Row(
                        children: [
                          Expanded(flex: 62, child: _buildCatalogPane(isDark, textColor)),
                          VerticalDivider(color: isDark ? Colors.white12 : Colors.black12, width: 1),
                          Expanded(flex: 38, child: _buildCartPane(isDark, textColor)),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 55, child: _buildCatalogPane(isDark, textColor)),
                          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                          Expanded(flex: 45, child: _buildCartPane(isDark, textColor)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color textColor, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      color: isDark ? const Color(0xFF121418) : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            "POS TERMINAL",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2),
          ),
          const Spacer(),
          if (_heldCarts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                label: Text("Held (${_heldCarts.length})", style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _showHeldCartsDialog,
              ),
            ),
          IconButton(
            icon: Icon(Icons.inventory_2_outlined, color: textColor, size: 20),
            tooltip: "Stock Inwarding",
            onPressed: () => showDialog(
              context: context,
              builder: (_) => PosStockInwardDialog(existingItems: _catalog),
            ).then((_) => _loadCatalog()),
          ),
          IconButton(
            icon: Icon(Icons.analytics_outlined, color: textColor, size: 20),
            tooltip: "Reports",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosAnalyticsReportScreen())),
          ),
          IconButton(
            icon: Icon(Icons.print_outlined, color: textColor, size: 20),
            tooltip: "Printer Settings",
            onPressed: () => showDialog(context: context, builder: (_) => const PosHardwareSettingsDialog()),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPane(bool isDark, Color textColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Search items, fast food, barcodes...",
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black54),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    _searchQuery = val.trim();
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: _isCameraScannerOpen ? Colors.redAccent : Colors.amber),
                icon: Icon(_isCameraScannerOpen ? Icons.close : Icons.camera_alt, color: Colors.black, size: 20),
                onPressed: () => setState(() => _isCameraScannerOpen = !_isCameraScannerOpen),
              ),
            ],
          ),
        ),
        if (_isCameraScannerOpen)
          Container(
            height: 160,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber, width: 2),
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController ??= MobileScannerController(
                    facing: _cameraFacing,
                    torchEnabled: false,
                  ),
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        _onHardwareBarcodeScanned(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Camera controls overlay: Front/Rear switch & Torch toggle
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.flash_on, color: Colors.amberAccent, size: 18),
                              tooltip: 'Toggle Torch',
                              onPressed: () => _scannerController?.toggleTorch(),
                            ),
                            IconButton(
                              icon: Icon(
                                _cameraFacing == CameraFacing.front ? Icons.camera_front : Icons.camera_rear,
                                color: Colors.white,
                                size: 18,
                              ),
                              tooltip: 'Switch Camera (Front/Rear)',
                              onPressed: () {
                                setState(() {
                                  _cameraFacing = _cameraFacing == CameraFacing.back
                                      ? CameraFacing.front
                                      : CameraFacing.back;
                                  _scannerController?.switchCamera();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Colors.amberAccent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _cameraFacing == CameraFacing.front ? 'Phone Front Camera Active' : 'Phone Rear Camera Active',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _dynamicCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _dynamicCategories[i];
              final isSel = _selectedCategory.toLowerCase() == cat.toLowerCase();
              return ChoiceChip(
                selected: isSel,
                selectedColor: Colors.amber,
                backgroundColor: isDark ? const Color(0xFF16181D) : Colors.grey.shade200,
                label: Text(cat, style: TextStyle(color: isSel ? Colors.black : textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedCategory = cat;
                      _applyFilters();
                    });
                  }
                },
              );
            },
          ),
        ),
        Expanded(
          child: _isLoadingCatalog
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : _filteredCatalog.isEmpty
                  ? Center(child: Text("No items available", style: TextStyle(color: isDark ? Colors.white38 : Colors.black45)))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _filteredCatalog.length,
                      itemBuilder: (context, index) {
                        final item = _filteredCatalog[index];
                        return InkWell(
                           onTap: () => _addToCart(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF16181D) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Stock: ${item.stockQuantity}", style: TextStyle(fontSize: 10, color: item.stockQuantity <= 5 ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
                                    if (item.barcode != null && item.barcode!.trim().isNotEmpty)
                                      const Tooltip(
                                        message: "Scan-Ready Barcode",
                                        child: Icon(Icons.barcode_reader, size: 14, color: Colors.amberAccent),
                                      )
                                    else if (item.skuQr != null && item.skuQr!.trim().isNotEmpty)
                                      Icon(Icons.qr_code, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                                  ],
                                ),
                                const Spacer(),
                                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("₹ ${item.price.toStringAsFixed(1)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Icon(Icons.add_circle, color: Colors.amber, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // Function to show searchable user selection dialog
  void _showUserSelectionDialog(bool isDark, Color textColor) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filteredStudents = _students.where((s) {
              final name = (s['full_name'] ?? '').toString().toLowerCase();
              final phone = (s['phone'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase()) || phone.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF16181D) : Colors.white,
              title: Text("Select Customer / User", style: TextStyle(color: textColor, fontSize: 16)),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Search by name or phone...",
                        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        prefixIcon: Icon(Icons.search, color: textColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0A0C0E) : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: Colors.amber),
                      title: Text("Walk-in Customer", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      onTap: () {
                        setState(() => _selectedStudent = null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final s = filteredStudents[index];
                          final balance = s['balance'] ?? 0;
                          final role = s['role'] ?? 'Customer';
                          return ListTile(
                            dense: true,
                            title: Text(s['full_name'] ?? 'Unknown', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            subtitle: Text("Role: $role | Balance: ₹ $balance", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11)),
                            onTap: () {
                              setState(() => _selectedStudent = s);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartPane(bool isDark, Color textColor) {
    // Extract wallet balance and role if a student is selected
    final double walletBalance = _selectedStudent != null ? double.tryParse(_selectedStudent!['balance'].toString()) ?? 0.0 : 0.0;
    final String userRole = _selectedStudent != null ? (_selectedStudent!['role'] ?? 'Customer') : 'Walk-in';

    return Container(
      color: isDark ? const Color(0xFF121418) : Colors.white,
      child: Column(
        children: [
          // User Selection & Search Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark ? const Color(0xFF0A0C0E) : Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showUserSelectionDialog(isDark, textColor),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F242D) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedStudent != null ? (_selectedStudent!['full_name'] ?? 'Selected User') : "Walk-in Customer / Khata",
                                style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Icon(Icons.search, size: 16, color: isDark ? Colors.white60 : Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause, color: Colors.tealAccent, size: 18),
                      onPressed: _cart.isNotEmpty ? _holdCurrentCart : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: _cart.isNotEmpty ? _clearCart : null,
                    ),
                  ],
                ),
                if (_selectedStudent != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      // Wallet Balance Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: walletBalance >= 0 ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: walletBalance >= 0 ? Colors.green : Colors.red, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wallet, size: 12, color: walletBalance >= 0 ? Colors.green : Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              "Balance: ₹ ${walletBalance.toStringAsFixed(1)}",
                              style: TextStyle(color: walletBalance >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // User Role Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              "Role: $userRole",
                              style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(child: Text("Cart is empty", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1),
                                  Text("₹ ${item.price.toStringAsFixed(1)} ea", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => _updateCartQuantity(index, -1),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                                    child: Icon(Icons.remove, size: 12, color: textColor),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _showCustomQuantityDialog(index, isDark),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("${item.qty}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.edit, size: 10, color: Colors.amber),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _updateCartQuantity(index, 1),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                                    child: Icon(Icons.add, size: 12, color: textColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Text("₹ ${(item.price * item.qty).toStringAsFixed(1)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0C0E) : Colors.grey.shade50,
              border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
            ),
            child: Column(
              children: [
                _summaryRow("Subtotal:", "₹ ${_subtotal.toStringAsFixed(2)}", textColor),
                if (_cartDiscount > 0) _summaryRow("Discount:", "-₹ ${_cartDiscount.toStringAsFixed(2)}", Colors.redAccent),
                _summaryRow("CGST + SGST (5%):", "₹ ${(_cgst + _sgst).toStringAsFixed(2)}", textColor),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("NET TOTAL:", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text("₹ ${_netTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.point_of_sale, size: 18),
                    label: const Text("PAY & PRINT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: _cart.isEmpty
                        ? null
                        : () async {
                            final res = await showDialog(
                              context: context,
                              builder: (_) => PosPaymentDialog(
                                items: _cart,
                                subtotal: _subtotal,
                                discount: _cartDiscount,
                                cgst: _cgst,
                                sgst: _sgst,
                                total: _netTotal,
                                selectedStudent: _selectedStudent,
                              ),
                            );
                            if (res != null) {
                              _clearCart();
                              _loadCatalog();
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
          Text(value, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showHeldCartsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text("Parked Orders", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _heldCarts.length,
            itemBuilder: (context, i) {
              final h = _heldCarts[i];
              return ListTile(
                title: Text(h['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
                subtitle: Text("${(h['items'] as List).length} items", style: const TextStyle(fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text("Recall"),
                  onPressed: () {
                    Navigator.pop(context);
                    _recallHeldCart(i);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}