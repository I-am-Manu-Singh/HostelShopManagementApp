import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../services/cart_service.dart';
import '../../models/shop.dart';
import 'shop_order_status_screen.dart';

class ShopCheckoutScreen extends StatefulWidget {
  final bool isMandiMode;
  const ShopCheckoutScreen({super.key, this.isMandiMode = false});

  @override
  State<ShopCheckoutScreen> createState() => _ShopCheckoutScreenState();
}

class _ShopCheckoutScreenState extends State<ShopCheckoutScreen> {
  final _client = Supabase.instance.client;
  final _auth = LocalAuthentication();
  
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  // Mandi options
  final _locationController = TextEditingController();
  final _advanceController = TextEditingController();
  String _userType = 'domestic'; // domestic vs commercial
  DateTime? _bookingDate;
  
  String _deliveryType = 'Pickup';
  String _paymentMethod = 'Wallet';
  XFile? _upiScreenshot;
  bool _isProcessing = false;
  Map<String, dynamic>? _profile;
  final double _deliveryFee = 20.0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('profiles').select().eq('id', user.id).single();
      if (mounted) {
        setState(() {
          _profile = res;
          _phoneController.text = (res['phone_no'] ?? '').toString();
          _altPhoneController.text = (res['alt_phone_no'] ?? '').toString();
          _addressController.text = (res['last_delivery_address'] ?? res['delivery_address'] ?? '').toString();
          _locationController.text = (res['delivery_location'] ?? '').toString();
          _userType = res['user_type'] == 'commercial' ? 'commercial' : 'domestic';
          _emergencyNameController.text = (res['last_emergency_name'] ?? '').toString();
          _emergencyRelationController.text = (res['last_emergency_relation'] ?? '').toString();
          _emergencyPhoneController.text = (res['last_emergency_phone'] ?? '').toString();
        });
      }
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = Provider.of<CartProvider>(context);
    final textColor = isDark ? Colors.white : Colors.black;
    if (cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.indigoAccent.withOpacity(0.2)), const SizedBox(height: 20), Text('CART IS EMPTY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white38 : Colors.black38))])),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('CHECKOUT CONFIG', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Desktop/Wide View: 2-column layout split
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('DELIVERY METHOD'),
                        const SizedBox(height: 16),
                        Row(children: [_toggleBtn('Pickup', _deliveryType == 'Pickup', () => setState(() => _deliveryType = 'Pickup')), const SizedBox(width: 12), _toggleBtn('Home Delivery', _deliveryType == 'Home Delivery', () => setState(() => _deliveryType = 'Home Delivery'))]),
                        const SizedBox(height: 32),
                        
                        _sectionLabel('PAYMENT METHOD'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _paymentTile('Wallet', Icons.account_balance_wallet_outlined, _paymentMethod == 'Wallet', () => setState(() => _paymentMethod = 'Wallet'), isDark),
                            const SizedBox(width: 10),
                            _paymentTile('UPI / QR', Icons.qr_code_rounded, _paymentMethod == 'UPI', () => setState(() => _paymentMethod = 'UPI'), isDark),
                            const SizedBox(width: 10),
                            _paymentTile('Cash', Icons.payments_outlined, _paymentMethod == 'Cash', () => setState(() => _paymentMethod = 'Cash'), isDark),
                          ],
                        ),
                        if (_paymentMethod == 'UPI') ...[const SizedBox(height: 24), _buildUPIUpload(isDark)],
                        const SizedBox(height: 32),

                        _sectionLabel('PRIMARY COMMUNICATION'),
                        const SizedBox(height: 16),
                        _buildTextField('PRIMARY CONTACT PHONE', _phoneController, isDark),
                        const SizedBox(height: 12),
                        _buildTextField('ALTERNATE CONTACT', _altPhoneController, isDark),
                        if (_deliveryType == 'Home Delivery' || widget.isMandiMode) ...[
                          const SizedBox(height: 12),
                          _buildTextField('DELIVERY ADDRESS', _addressController, isDark),
                          const SizedBox(height: 12),
                          _buildTextField('DELIVERY LOCATION / AREA', _locationController, isDark),
                        ],
                        const SizedBox(height: 32),

                        if (widget.isMandiMode) ...[
                          _sectionLabel('MANDI BOOKING CONFIG'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _toggleBtn('Domestic', _userType == 'domestic', () => setState(() => _userType = 'domestic')),
                              const SizedBox(width: 12),
                              _toggleBtn('Commercial', _userType == 'commercial', () => setState(() => _userType = 'commercial')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField('BOOKING ADVANCE PAYMENT (₹)', _advanceController, isDark),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _bookingDate == null 
                                  ? 'SELECT BOOKING/CUTTING DATE' 
                                  : 'BOOKED DATE: ${DateFormat('yyyy-MM-dd').format(_bookingDate!)}',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.calendar_today_rounded, color: Colors.indigoAccent),
                            onTap: () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (selected != null) {
                                setState(() => _bookingDate = selected);
                              }
                            },
                          ),
                          const SizedBox(height: 32),
                        ],

                        if (!widget.isMandiMode) ...[
                          _sectionLabel('EMERGENCY CONTACT'),
                          const SizedBox(height: 16),
                          _buildTextField('PERSON NAME', _emergencyNameController, isDark),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _buildTextField('RELATION', _emergencyRelationController, isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField('PHONE NO', _emergencyPhoneController, isDark)),
                          ]),
                          const SizedBox(height: 32),
                        ],

                        _sectionLabel('SPECIAL INSTRUCTIONS'),
                        const SizedBox(height: 16),
                        _buildTextField('ORDER NOTES / INSTRUCTIONS', _instructionsController, isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.black12),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: _sectionLabel('CART INVENTORY'),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            _buildCartItemsList(cart, isDark),
                          ],
                        ),
                      ),
                      _buildTotalSummary(cart, isDark),
                      _buildAuthorizeButton(cart, isDark),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile View: Single column layout
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _sectionLabel('DELIVERY METHOD'),
                    const SizedBox(height: 16),
                    Row(children: [_toggleBtn('Pickup', _deliveryType == 'Pickup', () => setState(() => _deliveryType = 'Pickup')), const SizedBox(width: 12), _toggleBtn('Home Delivery', _deliveryType == 'Home Delivery', () => setState(() => _deliveryType = 'Home Delivery'))]),
                    const SizedBox(height: 32),
                    
                    _sectionLabel('PAYMENT METHOD'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _paymentTile('Wallet', Icons.account_balance_wallet_outlined, _paymentMethod == 'Wallet', () => setState(() => _paymentMethod = 'Wallet'), isDark),
                        const SizedBox(width: 10),
                        _paymentTile('UPI / QR', Icons.qr_code_rounded, _paymentMethod == 'UPI', () => setState(() => _paymentMethod = 'UPI'), isDark),
                        const SizedBox(width: 10),
                        _paymentTile('Cash', Icons.payments_outlined, _paymentMethod == 'Cash', () => setState(() => _paymentMethod = 'Cash'), isDark),
                      ],
                    ),
                    if (_paymentMethod == 'UPI') ...[const SizedBox(height: 24), _buildUPIUpload(isDark)],
                    const SizedBox(height: 32),

                    _sectionLabel('CART INVENTORY'),
                    const SizedBox(height: 16),
                    _buildCartItemsList(cart, isDark),
                    const SizedBox(height: 32),

                    _sectionLabel('PRIMARY COMMUNICATION'),
                    const SizedBox(height: 16),
                    _buildTextField('PRIMARY CONTACT PHONE', _phoneController, isDark),
                    const SizedBox(height: 12),
                    _buildTextField('ALTERNATE CONTACT', _altPhoneController, isDark),
                    if (_deliveryType == 'Home Delivery' || widget.isMandiMode) ...[
                      const SizedBox(height: 12),
                      _buildTextField('DELIVERY ADDRESS', _addressController, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('DELIVERY LOCATION / AREA', _locationController, isDark),
                    ],
                    const SizedBox(height: 32),

                    if (widget.isMandiMode) ...[
                      _sectionLabel('MANDI BOOKING CONFIG'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _toggleBtn('Domestic', _userType == 'domestic', () => setState(() => _userType = 'domestic')),
                          const SizedBox(width: 12),
                          _toggleBtn('Commercial', _userType == 'commercial', () => setState(() => _userType = 'commercial')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('BOOKING ADVANCE PAYMENT (₹)', _advanceController, isDark),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _bookingDate == null 
                              ? 'SELECT BOOKING/CUTTING DATE' 
                              : 'BOOKED DATE: ${DateFormat('yyyy-MM-dd').format(_bookingDate!)}',
                          style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded, color: Colors.indigoAccent),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (selected != null) {
                            setState(() => _bookingDate = selected);
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                    ],

                    if (!widget.isMandiMode) ...[
                      _sectionLabel('EMERGENCY CONTACT'),
                      const SizedBox(height: 16),
                      _buildTextField('PERSON NAME', _emergencyNameController, isDark),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _buildTextField('RELATION', _emergencyRelationController, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('PHONE NO', _emergencyPhoneController, isDark)),
                      ]),
                      const SizedBox(height: 32),
                    ],

                    _sectionLabel('SPECIAL INSTRUCTIONS'),
                    const SizedBox(height: 16),
                    _buildTextField('ORDER NOTES / INSTRUCTIONS', _instructionsController, isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              _buildTotalSummary(cart, isDark),
              _buildAuthorizeButton(cart, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String l) => Text(l, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.5));

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 52, decoration: BoxDecoration(color: active ? Colors.indigoAccent : Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? Colors.indigoAccent : Colors.indigoAccent.withOpacity(0.1))), child: Center(child: Text(label.toUpperCase(), style: TextStyle(color: active ? Colors.black : Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5))))));

  Widget _paymentTile(String title, IconData icon, bool active, VoidCallback onTap, bool isDark) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: active ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)), border: Border.all(color: active ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.1))), borderRadius: BorderRadius.circular(20)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? Colors.black : (isDark ? Colors.white38 : Colors.black38), size: 18), const SizedBox(height: 6), Text(title.toUpperCase(), style: TextStyle(color: active ? Colors.black : (isDark ? Colors.white38 : Colors.black38), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5))]))));

  Widget _buildTextField(String label, TextEditingController ctrl, bool isDark) => Container(padding: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), borderRadius: BorderRadius.circular(20)), child: TextField(controller: ctrl, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14), decoration: InputDecoration(border: InputBorder.none, hintText: label, hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold))));

  Widget _buildUPIUpload(bool isDark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: Column(children: [Row(children: [const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigoAccent), const SizedBox(width: 16), Expanded(child: Text('Scan and upload receipt.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)))]), const SizedBox(height: 20), GestureDetector(onTap: () async { final img = await ImagePicker().pickImage(source: ImageSource.gallery); if (img != null) setState(() => _upiScreenshot = img); }, child: Container(height: 140, width: double.infinity, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20)), child: _upiScreenshot == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file_rounded, color: isDark ? Colors.white24 : Colors.black26), const SizedBox(height: 4), Text('UPLOAD SCREENSHOT', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900))]) : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(_upiScreenshot!.path), fit: BoxFit.cover))))]));

  Widget _buildTotalSummary(CartProvider cart, bool isDark) {
    final subTotal = cart.totalAmount;
    final delivery = _deliveryType == 'Home Delivery' ? _deliveryFee : 0.0;
    final textCol = isDark ? Colors.white : Colors.black;
    final subCol = isDark ? Colors.white24 : Colors.black26;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('DELIVERY LOGISTICS', style: TextStyle(color: subCol, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
          Text(delivery == 0 ? 'FREE' : '₹${delivery.toInt()}', style: TextStyle(color: delivery == 0 ? Colors.greenAccent : textCol, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TOTAL PAYABLE', style: TextStyle(color: subCol, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
          Text('₹${(subTotal + delivery).toInt()}', style: GoogleFonts.outfit(color: textCol, fontSize: 34, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _buildCartItemsList(CartProvider cart, bool isDark) {
    return Column(
      children: cart.items.entries.map((e) {
        final item = cart.getItemDetail(e.key);
        if (item == null) return const SizedBox();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text('₹${(item.discountPrice ?? item.price).toInt()} / unit', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10)),
                      if (cart.weightQuantities.containsKey(e.key)) ...[
                        const SizedBox(width: 8),
                        Text('•  ${cart.weightQuantities[e.key]} ${cart.weightUnits[e.key]}', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                ]),
              ),
              Row(children: [
                _qtyBtn(Icons.remove_rounded, () => cart.removeItem(e.key)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${e.value}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.indigoAccent))),
                _qtyBtn(Icons.add_rounded, () => cart.addItem(item)),
              ]),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.indigoAccent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.all(6), child: Icon(icon, size: 14, color: Colors.white))),
    );
  }

  Widget _buildAuthorizeButton(CartProvider cart, bool isDark) {
    return Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 40), child: SizedBox(width: double.infinity, height: 68, child: ElevatedButton(onPressed: _isProcessing ? null : () async {
      if (_paymentMethod == 'UPI' && _upiScreenshot == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI TRANSFERS REQUIRE SCREENSHOT VERIFICATION.'), backgroundColor: Colors.orangeAccent)); return; }
      if (_phoneController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PRIMARY CONTACT PHONE IS MANDATORY'), backgroundColor: Colors.redAccent)); return; }
      if (_deliveryType == 'Home Delivery' && _addressController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ADDRESS MANDATORY FOR HOME DELIVERY'), backgroundColor: Colors.orangeAccent)); return; }
      try { 
        final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported(); 
        if (canAuth) { 
           final didAuth = await _auth.authenticate(localizedReason: 'Authorize purchase of ₹${(cart.totalAmount + (_deliveryType == 'Home Delivery' ? _deliveryFee : 0.0)).toInt()}'); 
           if (!didAuth) return; 
        } 
      } catch (_) {}
      
      setState(() => _isProcessing = true);
      try {
        final error = await cart.checkout(
          deliveryType: _deliveryType, 
          paymentMethod: _paymentMethod, 
          upiScreenshotUrl: _upiScreenshot != null ? 'https://hostel-mgmt.up.railway.app/mock-upi-receipt.png' : null, 
          deliveryAddress: _addressController.text, 
          phoneNo: _phoneController.text, 
          altPhoneNo: _altPhoneController.text,
          emergencyName: _emergencyNameController.text,
          emergencyRelation: _emergencyRelationController.text,
          emergencyPhone: _emergencyPhoneController.text,
          instructions: _instructionsController.text,
          isBooking: widget.isMandiMode,
          bookingDate: _bookingDate,
          advancePaid: double.tryParse(_advanceController.text) ?? 0.0,
          userType: _userType,
          deliveryLocation: _locationController.text,
        );
        if (mounted) {
          if (error == null) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShopOrderStatusScreen()));
          } else {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPOT ERROR: $error'), backgroundColor: Colors.redAccent));
          }
        }
      } catch (e) {
        if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TERMINAL REJECTED: $e'), backgroundColor: Colors.redAccent)); }
      }
    }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0), child: _isProcessing ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('PLACE ORDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)))));
  }
}
