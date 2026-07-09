// lib/screens/mandi/mandi_purchase_order_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class MandiPurchaseOrderScreen extends StatefulWidget {
  const MandiPurchaseOrderScreen({super.key});

  @override
  State<MandiPurchaseOrderScreen> createState() => _MandiPurchaseOrderScreenState();
}

class _MandiPurchaseOrderScreenState extends State<MandiPurchaseOrderScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _purchaseOrders = [];
  List<dynamic> _sellers = [];
  List<dynamic> _mandiProducts = [];

  // Form states
  String? _selectedSellerId;
  String? _selectedProductId;
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  XFile? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    _loadPOData();
  }

  Future<void> _loadPOData() async {
    setState(() => _isLoading = true);
    try {
      final poRes = await _client.from('mandi_purchase_orders').select().order('created_at', ascending: false);
      final sellerRes = await _client.from('profiles').select('id, full_name, phone_no').eq('role', 'farmer_seller');
      final productRes = await _client.from('shop_items').select().eq('is_mandi', true);

      if (mounted) {
        setState(() {
          _purchaseOrders = poRes as List;
          _sellers = sellerRes as List;
          _mandiProducts = productRes as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PO Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) {
      setState(() => _selectedPhoto = img);
    }
  }

  Future<void> _createPurchaseOrder() async {
    if (_selectedSellerId == null || _selectedProductId == null || _qtyCtrl.text.isEmpty || _rateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all mandatory fields'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = _client.auth.currentUser;
      final seller = _sellers.firstWhere((s) => s['id'] == _selectedSellerId);
      final product = _mandiProducts.firstWhere((p) => p['id'] == _selectedProductId);
      final double qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
      final double rate = double.tryParse(_rateCtrl.text) ?? 0.0;
      final double total = qty * rate;

      String? photoUrl;
      if (_selectedPhoto != null) {
        final file = File(_selectedPhoto!.path);
        final fileName = 'po_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from('mandi-assets').upload(fileName, file);
        photoUrl = _client.storage.from('mandi-assets').getPublicUrl(fileName);
      }

      await _client.from('mandi_purchase_orders').insert({
        'created_by': user!.id,
        'seller_id': _selectedSellerId,
        'seller_name': seller['full_name'],
        'seller_phone': seller['phone_no'],
        'product_id': _selectedProductId,
        'product_name': product['name'],
        'quantity': qty,
        'unit': product['unit'] ?? 'kg',
        'rate_per_unit': rate,
        'total_amount': total,
        'photo_url': photoUrl,
        'notes': _notesCtrl.text,
        'status': 'sent',
      });

      // Clear fields
      _qtyCtrl.clear();
      _rateCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _selectedSellerId = null;
        _selectedProductId = null;
        _selectedPhoto = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase order sent to seller successfully'), backgroundColor: Colors.green),
      );
      _loadPOData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create purchase order: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('PURCHASE ORDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCreatePOSection(isDark, textColor),
                  const SizedBox(height: 40),
                  Text('PURCHASE ORDERS LIST', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  _buildPOList(isDark, textColor),
                ],
              ),
            ),
    );
  }

  Widget _buildCreatePOSection(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEW PURCHASE ORDER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 2)),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _selectedSellerId,
            hint: const Text('SELECT SELLER / FARMER'),
            dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
            items: _sellers.map((s) => DropdownMenuItem<String>(value: s['id'], child: Text(s['full_name'] ?? 'Seller'))).toList(),
            onChanged: (val) => setState(() => _selectedSellerId = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedProductId,
            hint: const Text('SELECT PRODUCE / ITEM'),
            dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
            items: _mandiProducts.map((p) => DropdownMenuItem<String>(value: p['id'], child: Text(p['name'] ?? 'Item'))).toList(),
            onChanged: (val) => setState(() => _selectedProductId = val),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: 'QUANTITY (Kg / Dozen / Pcs)', prefixIcon: Icon(Icons.production_quantity_limits)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _rateCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: 'PROPOSED RATE PER UNIT (₹)', prefixIcon: Icon(Icons.payments)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'SPECIAL PROVISIONS / NOTES', prefixIcon: Icon(Icons.notes)),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: _selectedPhoto == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_outlined, color: textColor.withOpacity(0.3)), const SizedBox(height: 4), Text('ATTACH PHOTO', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold))])
                  : ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_selectedPhoto!.path), fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _createPurchaseOrder,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SUBMIT PURCHASE ORDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOList(bool isDark, Color textColor) {
    if (_purchaseOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text('NO ORDERS FOUND', style: TextStyle(color: textColor.withOpacity(0.2), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _purchaseOrders.length,
      itemBuilder: (context, i) {
        final po = _purchaseOrders[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PO #${po['id'].toString().substring(0, 8).toUpperCase()}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
                  _statusBadge(po['status'] ?? 'sent'),
                ],
              ),
              const SizedBox(height: 12),
              _poRow('SELLER', po['seller_name'] ?? 'N/A', textColor),
              _poRow('PRODUCE', po['product_name'] ?? 'N/A', textColor),
              _poRow('VOLUME', '${po['quantity']} ${po['unit']}', textColor),
              _poRow('PROPOSED RATE', '₹${po['rate_per_unit']} / unit', textColor),
              _poRow('ESTIMATED YIELD', '₹${po['total_amount']}', Colors.green),
              if (po['photo_url'] != null) ...[
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(po['photo_url'], height: 120, width: double.infinity, fit: BoxFit.cover)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _poRow(String label, String val, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(val, style: GoogleFonts.outfit(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c = Colors.grey;
    if (status == 'received') c = Colors.green;
    if (status == 'sent') c = Colors.orange;
    if (status == 'cancelled') c = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
