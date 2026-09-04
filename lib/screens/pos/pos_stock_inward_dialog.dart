import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/shop.dart';
import '../../services/barcode_wedge_service.dart';
import '../../services/pos_sync_service.dart';

class PosStockInwardDialog extends StatefulWidget {
  final List<ShopItem> existingItems;
  const PosStockInwardDialog({super.key, required this.existingItems});

  @override
  State<PosStockInwardDialog> createState() => _PosStockInwardDialogState();
}

class _PosStockInwardDialogState extends State<PosStockInwardDialog> {
  ShopItem? _selectedItem;
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

  void _matchItemByBarcode(String barcode) {
    try {
      final cleanCode = barcode.trim().toLowerCase();
      final found = widget.existingItems.firstWhere(
        (it) => (it.barcode?.toLowerCase().trim() == cleanCode) ||
                (it.skuQr?.toLowerCase().trim() == cleanCode) ||
                (it.id.toLowerCase().trim() == cleanCode),
      );
      setState(() {
        _selectedItem = found;
        _sellPriceCtrl.text = found.price.toStringAsFixed(2);
        _costCtrl.text = (found.price * 0.75).toStringAsFixed(2); // default est
        _isCameraActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matched Product: ${found.name}'), backgroundColor: Colors.green),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No item found matching barcode: $barcode'), backgroundColor: Colors.orange),
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
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text("Stock Inwarding / Purchase GRN", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Barcode Scan / Selection Bar
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ShopItem>(
                      initialValue: _selectedItem,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Select Item or Scan Barcode",
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: widget.existingItems.map((item) {
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
                    style: IconButton.styleFrom(backgroundColor: Colors.amberAccent),
                    icon: Icon(_isCameraActive ? Icons.camera_alt : Icons.qr_code_scanner, color: Colors.black),
                    tooltip: "Scan Barcode with Camera",
                    onPressed: () => setState(() => _isCameraActive = !_isCameraActive),
                  ),
                ],
              ),

              if (_isCameraActive) ...[
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
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
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current Stock: ${_selectedItem!.stockQuantity} ${_selectedItem!.unit}", style: const TextStyle(color: Colors.white70)),
                      Text("Current MRP: Rs ${_selectedItem!.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInput("Inward Quantity", _qtyCtrl, isNumber: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInput("Unit Cost Price (Buy)", _costCtrl, isNumber: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInput("New Selling Price (MRP)", _sellPriceCtrl, isNumber: true),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput("Supplier / Vendor Name", _vendorCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInput("Invoice Ref / Bill No.", _invoiceRefCtrl),
                  ),
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
                      : const Icon(Icons.add_shopping_cart),
                  label: const Text("Commit Stock Inwarding", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: _isSubmitting ? null : _submitInward,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
