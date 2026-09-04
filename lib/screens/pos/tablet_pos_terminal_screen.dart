import 'package:flutter/material.dart';
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
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoadingCatalog = true;

  // Running Cart
  final List<OrderItem> _cart = [];
  double _cartDiscount = 0.0;
  bool _isCameraScannerOpen = false;

  // Student Account Selection
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;

  // Parked / Held Carts
  final List<Map<String, dynamic>> _heldCarts = [];

  @override
  void initState() {
    super.initState();
    PosHardwareService().init();
    _loadCatalog();
    _loadStudents();

    // Hook up hardware barcode wedge listener (USB/BT Barcode Scanner)
    BarcodeWedgeService().addListener(_onHardwareBarcodeScanned);
  }

  @override
  void dispose() {
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
        _applyFilters();
        _isLoadingCatalog = false;
      });
    }
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
        final matchesCategory = _selectedCategory == 'All' || it.category.toLowerCase() == _selectedCategory.toLowerCase();
        final matchesQuery = _searchQuery.isEmpty ||
            it.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (it.skuQr?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return matchesCategory && matchesQuery;
      }).toList();
    });
  }

  Future<void> _onHardwareBarcodeScanned(String barcode) async {
    if (!mounted) return;
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return;

    // 1. Check in local catalog first
    try {
      final item = _catalog.firstWhere(
        (it) => (it.barcode?.toLowerCase().trim() == cleanCode.toLowerCase()) ||
                (it.skuQr?.toLowerCase().trim() == cleanCode.toLowerCase()) ||
                (it.id.toLowerCase().trim() == cleanCode.toLowerCase()),
      );
      _addToCart(item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned: ${item.name} (+1)'), duration: const Duration(seconds: 1), backgroundColor: Colors.green),
      );
      return;
    } catch (_) {}

    // 2. Not in active local catalog -> Attempt online open database lookup (Open Food Facts / UPCitemdb)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching product registries for: $cleanCode...'), duration: const Duration(seconds: 1), backgroundColor: Colors.indigo),
    );

    final onlineResult = await ProductLookupService().fetchProductDetailsOnline(cleanCode);
    if (!mounted) return;

    // 3. Prompt Quick-Add Dialog (Pre-populated from API or blank for loose kirana / manual entry)
    _showQuickAddProductDialog(cleanCode, onlineResult);
  }

  void _showQuickAddProductDialog(String barcode, BarcodeProductLookupResult lookup) {
    final nameCtrl = TextEditingController(text: lookup.name ?? '');
    final priceCtrl = TextEditingController(text: '');
    final costCtrl = TextEditingController(text: '');
    final brandCtrl = TextEditingController(text: lookup.brand ?? '');
    final categoryCtrl = TextEditingController(text: lookup.category ?? 'Groceries');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(lookup.found ? Icons.auto_awesome : Icons.add_circle, color: lookup.found ? Colors.amberAccent : Colors.tealAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lookup.found ? "Online Registry Match (${lookup.source})" : "New Barcode / Loose Kirana Entry",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                  Text("Barcode: $barcode", style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: "Product Name *",
                      labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Selling Price (₹) *",
                            labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                            filled: true,
                            fillColor: Color(0xFF0F172A),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Cost / MRP (₹)",
                            labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                            filled: true,
                            fillColor: Color(0xFF0F172A),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: brandCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Brand",
                            labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                            filled: true,
                            fillColor: Color(0xFF0F172A),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: categoryCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Category",
                            labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                            filled: true,
                            fillColor: Color(0xFF0F172A),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (lookup.imageUrl != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(lookup.imageUrl!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("Product image found and linked from registry", style: TextStyle(color: Colors.white60, fontSize: 11))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      if (name.isEmpty || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid product name and selling price'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final List<String> tags = [];
                      if (lookup.allergens != null) {
                        for (final a in lookup.allergens!) {
                          tags.add('Contains $a');
                        }
                      }
                      final newItem = await ProductLookupService().registerProductInDatabase(
                        name: name,
                        barcode: barcode,
                        price: price,
                        costPrice: double.tryParse(costCtrl.text.trim()),
                        brand: brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
                        category: categoryCtrl.text.trim().isEmpty ? 'Groceries' : categoryCtrl.text.trim(),
                        weightMl: lookup.quantity ?? lookup.servingSize,
                        packageType: lookup.packageType,
                        imageUrl: lookup.imageUrl,
                        description: lookup.description,
                        ingredients: lookup.ingredients,
                        tags: tags.isNotEmpty ? tags : null,
                        nutritionalInfo: lookup.nutritionalInfo,
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        if (newItem != null) {
                          _catalog.add(newItem);
                          _applyFilters();
                          _addToCart(newItem);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved to database and added to cart: ${newItem.name}'), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to save to database'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text("Save & Add to Cart", style: TextStyle(fontWeight: FontWeight.bold)),
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
        );
      } else {
        _cart.add(OrderItem(
          id: item.id,
          name: item.name,
          qty: 1,
          price: item.price,
        ));
      }
    });
  }

  void _updateCartQuantity(int index, int delta) {
    setState(() {
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
        );
      }
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cart parked on hold. You can recall it anytime.'), backgroundColor: Colors.teal),
    );
  }

  void _recallHeldCart(int index) {
    final held = _heldCarts.removeAt(index);
    setState(() {
      _cart.clear();
      _cart.addAll(held['items']);
      _cartDiscount = held['discount'] ?? 0.0;
      _selectedStudent = held['student'];
    });
  }

  // Tax calculations
  double get _subtotal => _cart.fold(0.0, (sum, it) => sum + (it.price * it.qty));
  double get _taxableAmount => (_subtotal - _cartDiscount).clamp(0.0, 999999.0);
  // Default GST split: 2.5% CGST + 2.5% SGST = 5%
  double get _cgst => _taxableAmount * 0.025;
  double get _sgst => _taxableAmount * 0.025;
  double get _netTotal => _taxableAmount + _cgst + _sgst;

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Snacks', 'Beverages', 'Grocery', 'Dairy', 'Stationery', 'Mandi'];

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        BarcodeWedgeService().handleKeyEvent(event);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              // Top Tablet POS Bar
              _buildTopBar(),
              // Split Content (Left Pane: Catalog 62%, Right Pane: Cart & Checkout 38%)
              Expanded(
                child: Row(
                  children: [
                    // Catalog Pane
                    Expanded(
                      flex: 62,
                      child: _buildCatalogPane(categories),
                    ),
                    const VerticalDivider(color: Colors.white12, width: 1),
                    // Running Ticket / Cart Pane
                    Expanded(
                      flex: 38,
                      child: _buildCartPane(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.point_of_sale, color: Colors.amberAccent, size: 26),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("HOSTEL POS TERMINAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Connected • USB/BT Wedge Ready", style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
            ],
          ),
          const Spacer(),
          // Action Buttons
          if (_heldCarts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.pause_circle_filled, color: Colors.tealAccent, size: 18),
                backgroundColor: const Color(0xFF334155),
                label: Text("Held Carts (${_heldCarts.length})", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _showHeldCartsDialog,
              ),
            ),
          IconButton.filledTonal(
            icon: const Icon(Icons.inventory_2, color: Colors.greenAccent, size: 20),
            tooltip: "Stock Inwarding / Purchase GRN",
            onPressed: () => showDialog(
              context: context,
              builder: (_) => PosStockInwardDialog(existingItems: _catalog),
            ).then((_) => _loadCatalog()),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.analytics, color: Colors.lightBlueAccent, size: 20),
            tooltip: "Reports & Financial Analytics",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PosAnalyticsReportScreen()),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.print, color: Colors.amberAccent, size: 20),
            tooltip: "Printer & Hardware Settings",
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const PosHardwareSettingsDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPane(List<String> categories) {
    return Column(
      children: [
        // Search & Scan bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Search item name or scan barcode...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                style: IconButton.styleFrom(backgroundColor: _isCameraScannerOpen ? Colors.redAccent : Colors.amberAccent),
                icon: Icon(_isCameraScannerOpen ? Icons.close : Icons.camera_alt, color: Colors.black),
                tooltip: "Camera Barcode Scanner",
                onPressed: () => setState(() => _isCameraScannerOpen = !_isCameraScannerOpen),
              ),
            ],
          ),
        ),

        // Optional Camera Barcode Scanner Viewport
        if (_isCameraScannerOpen)
          Container(
            height: 160,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final code = barcode.rawValue;
                  if (code != null) {
                    _onHardwareBarcodeScanned(code);
                    break;
                  }
                }
              },
            ),
          ),

        // Category Horizontal Bar
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final isSel = _selectedCategory == cat;
              return ChoiceChip(
                selected: isSel,
                selectedColor: Colors.amberAccent,
                backgroundColor: const Color(0xFF1E293B),
                label: Text(cat, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

        // Product Grid
        Expanded(
          child: _isLoadingCatalog
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : _filteredCatalog.isEmpty
                  ? const Center(child: Text("No products found", style: TextStyle(color: Colors.white54)))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.15,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _filteredCatalog.length,
                      itemBuilder: (context, index) {
                        final item = _filteredCatalog[index];
                        final isLowStock = item.stockQuantity <= 5;
                        return InkWell(
                          onTap: () => _addToCart(item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLowStock ? Colors.redAccent.withValues(alpha: 0.2) : Colors.greenAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Stock: ${item.stockQuantity}",
                                        style: TextStyle(fontSize: 10, color: isLowStock ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (item.skuQr != null)
                                      const Icon(Icons.qr_code, size: 14, color: Colors.white38),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Rs ${item.price.toStringAsFixed(1)}",
                                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
                                      child: const Icon(Icons.add, size: 14, color: Colors.black),
                                    ),
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

  Widget _buildCartPane() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Customer / Student Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>?>(
                      value: _selectedStudent,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text("Select Student (Khata) or Walk-in", style: TextStyle(color: Colors.white60, fontSize: 12)),
                      items: [
                        const DropdownMenuItem<Map<String, dynamic>?>(
                          value: null,
                          child: Text("Walk-in Store Customer", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        ..._students.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text("${s['full_name']} (Bal: Rs ${s['balance'] ?? 0})", style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedStudent = val),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.pause, color: Colors.tealAccent, size: 20),
                  tooltip: "Park / Hold Cart",
                  onPressed: _cart.isNotEmpty ? _holdCurrentCart : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: "Clear Cart",
                  onPressed: _cart.isNotEmpty ? _clearCart : null,
                ),
              ],
            ),
          ),

          // Running Cart Items List
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.white24),
                        SizedBox(height: 8),
                        Text("Cart is empty", style: TextStyle(color: Colors.white38)),
                        Text("Scan a barcode or tap products", style: TextStyle(color: Colors.white24, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
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
                                  Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1),
                                  Text("Rs ${item.price.toStringAsFixed(1)} ea", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                            // Qty Buttons
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => _updateCartQuantity(index, -1),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                                    child: const Icon(Icons.remove, size: 14, color: Colors.white),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text("${item.qty}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                InkWell(
                                  onTap: () => _updateCartQuantity(index, 1),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Total
                            Text(
                              "Rs ${(item.price * item.qty).toStringAsFixed(1)}",
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Cart Bill Summary & Checkout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              children: [
                _summaryRow("Subtotal:", "Rs ${_subtotal.toStringAsFixed(2)}"),
                if (_cartDiscount > 0)
                  _summaryRow("Discount:", "-Rs ${_cartDiscount.toStringAsFixed(2)}", color: Colors.redAccent),
                _summaryRow("CGST (2.5%) + SGST (2.5%):", "Rs ${(_cgst + _sgst).toStringAsFixed(2)}"),
                const Divider(color: Colors.white24, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("NET AMOUNT:", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Rs ${_netTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.point_of_sale, size: 20),
                    label: const Text("PAY & PRINT RECEIPT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                              _loadCatalog(); // refresh stock numbers
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

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value, style: TextStyle(color: color ?? Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showHeldCartsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Parked / Held Orders", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _heldCarts.length,
            itemBuilder: (context, i) {
              final h = _heldCarts[i];
              final itemsCount = (h['items'] as List).length;
              return ListTile(
                title: Text(h['name'], style: const TextStyle(color: Colors.white)),
                subtitle: Text("$itemsCount items on hold", style: const TextStyle(color: Colors.white54)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
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
