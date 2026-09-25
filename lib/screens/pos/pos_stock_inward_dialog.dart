import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/shop.dart';
import '../../services/barcode_wedge_service.dart';
import '../../services/pos_sync_service.dart';
import '../../services/database_service.dart';
import '../admin/admin_edit_product_screen.dart';

class PosStockInwardDialog extends StatefulWidget {
  final List<ShopItem> existingItems;
  const PosStockInwardDialog({super.key, required this.existingItems});

  @override
  State<PosStockInwardDialog> createState() => _PosStockInwardDialogState();
}

class _PosStockInwardDialogState extends State<PosStockInwardDialog> {
  ShopItem? _selectedItem;
  late List<ShopItem> _availableItems;
  final _qtyCtrl = TextEditingController(text: "10");
  final _costCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController(text: "Mandi / Wholesale Vendor");
  final _invoiceRefCtrl = TextEditingController();

  bool _isCameraActive = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _availableItems = List<ShopItem>.from(widget.existingItems);
    BarcodeWedgeService().addListener(_onHardwareBarcode);
  }

  @override
  void dispose() {
    BarcodeWedgeService().removeListener(_onHardwareBarcode);
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _sellPriceCtrl.dispose();
    _vendorCtrl.dispose();
    _invoiceRefCtrl.dispose();
    super.dispose();
  }

  void _onHardwareBarcode(String barcode) {
    if (!mounted) return;
    _matchItemByBarcode(barcode);
  }

  Future<void> _openCreateProductFlow({String? barcode}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditProductScreen(scannedSku: barcode),
      ),
    );

    if (result == true && mounted) {
      // Reload items from database
      final updatedList = await DatabaseService().fetchShopItems();
      if (!mounted) return;
      setState(() {
        _availableItems = updatedList;
      });
      if (barcode != null && barcode.isNotEmpty) {
        _matchItemByBarcode(barcode);
      } else if (updatedList.isNotEmpty) {
        setState(() {
          _selectedItem = updatedList.last;
          _sellPriceCtrl.text = _selectedItem!.price.toStringAsFixed(2);
          _costCtrl.text = _selectedItem!.costPrice != null && _selectedItem!.costPrice! > 0
              ? _selectedItem!.costPrice!.toStringAsFixed(2)
              : (_selectedItem!.price * 0.75).toStringAsFixed(2);
        });
      }
    }
  }

  void _matchItemByBarcode(String barcode) {
    final cleanCode = barcode.trim().toLowerCase();
    try {
      final found = _availableItems.firstWhere(
        (it) => (it.barcode?.toLowerCase().trim() == cleanCode) ||
                (it.skuQr?.toLowerCase().trim() == cleanCode) ||
                (it.id.toLowerCase().trim() == cleanCode),
      );
      setState(() {
        _selectedItem = found;
        _sellPriceCtrl.text = found.price.toStringAsFixed(2);
        _costCtrl.text = found.costPrice != null && found.costPrice! > 0
            ? found.costPrice!.toStringAsFixed(2)
            : (found.price * 0.75).toStringAsFixed(2);
        _isCameraActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matched: ${found.name}'), backgroundColor: Colors.green),
      );
    } catch (_) {
      // Prompt to create this new product directly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found for "$barcode"'),
          backgroundColor: Colors.orange.shade800,
          action: SnackBarAction(
            label: '+ Create Product',
            textColor: Colors.amberAccent,
            onPressed: () => _openCreateProductFlow(barcode: barcode),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _submitInward() async {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or scan an item first'), backgroundColor: Colors.red),
      );
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceCtrl.text.trim());

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await PosSyncService().inwardStock(
      itemId: _selectedItem!.id,
      addedQuantity: qty,
      purchaseCost: cost,
      newSellingPrice: sellPrice,
      vendorName: _vendorCtrl.text.trim(),
      invoiceRef: _invoiceRefCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully inwarded $qty units of ${_selectedItem!.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update inventory'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF121418) : Colors.white;
    final containerBg = isDark ? const Color(0xFF0A0C0E) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Stock Inwarding / GRN",
                        style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor.withOpacity(0.7)),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ShopItem>(
                      value: _selectedItem,
                      dropdownColor: dialogBg,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "Select Item or Scan Barcode",
                        labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                        filled: true,
                        fillColor: containerBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _availableItems.map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text("${item.name} (Stock: ${item.stockQuantity})", overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedItem = val;
                            _sellPriceCtrl.text = val.price.toStringAsFixed(2);
                            _costCtrl.text = (val.price * 0.75).toStringAsFixed(2);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.amber),
                    icon: Icon(_isCameraActive ? Icons.camera_alt : Icons.qr_code_scanner, color: Colors.black),
                    tooltip: "Scan Barcode with Camera",
                    onPressed: () => setState(() => _isCameraActive = !_isCameraActive),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: "Create / Register New Product in Inventory",
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("New Item", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _openCreateProductFlow(),
                    ),
                  ),
                ],
              ),
              if (_isCameraActive) ...[
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final val = barcode.rawValue;
                        if (val != null) {
                          _matchItemByBarcode(val);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_selectedItem != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: containerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current Stock: ${_selectedItem!.stockQuantity} ${_selectedItem!.unit}", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                      Text("Current MRP: ₹ ${_selectedItem!.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInput("Qty", _qtyCtrl, isNumber: true, isDark: isDark, textColor: textColor, containerBg: containerBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInput("Buy Cost (₹)", _costCtrl, isNumber: true, isDark: isDark, textColor: textColor, containerBg: containerBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInput("MRP (₹)", _sellPriceCtrl, isNumber: true, isDark: isDark, textColor: textColor, containerBg: containerBg)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildInput("Vendor / Supplier", _vendorCtrl, isDark: isDark, textColor: textColor, containerBg: containerBg)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInput("Invoice Ref / Bill No.", _invoiceRefCtrl, isDark: isDark, textColor: textColor, containerBg: containerBg)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text("Commit Stock Inwarding", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: _isSubmitting ? null : _submitInward,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNumber = false, required bool isDark, required Color textColor, required Color containerBg}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(color: textColor, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
        filled: true,
        fillColor: containerBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}