import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StudentPaymentScreen extends StatefulWidget {
  final String? initialType; // 'Rent' or 'MessCard'
  const StudentPaymentScreen({super.key, this.initialType});

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  final _client = Supabase.instance.client;
  String _paymentType = 'Rent';
  final _amountCtrl = TextEditingController(text: '6500');
  File? _screenshot;
  bool _isUploading = false;
  String _role = 'hostel_student';
  double _baseRent = 6500;
  double _powerBill = 0;
  double _totalRent = 6500;

  @override
  void initState() {
    super.initState();
    _loadBilling();
  }

  Future<void> _loadBilling() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      final enrollment = await _client.from('hostel_enrollments').select('*, hostel_rooms(*)').eq('user_id', user.id).maybeSingle();
      final messCard = await _client.from('mess_cards').select().eq('user_id', user.id).eq('status', 'Active').maybeSingle();
      
      final Map<String, dynamic>? selectedPkgs = enrollment?['selected_packages'];
      final String? roomPlanName = selectedPkgs?['room_plan'];
      final List<dynamic> addonNames = selectedPkgs?['add_ons'] ?? [];
      
      // Fetch current rates from fee_structure
      final rates = await _client.from('fee_structure').select();
      final powerRate = (rates.firstWhere((r) => r['service_name'] == 'Power', orElse: () => {'price': 12.0})['price'] as num).toDouble();
      
      double calculatedBase = 0;
      
      // 1. Get Room Plan Price
      if (roomPlanName != null) {
        final Map<String, dynamic>? plan = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['service_name'].toString().toUpperCase() == roomPlanName.toUpperCase(), orElse: () => {});
        if (plan != null && plan.isNotEmpty) calculatedBase += (plan['price'] as num).toDouble();
      } else {
        calculatedBase = (enrollment?['total_price'] as num? ?? 6500).toDouble();
      }

      // 2. Add dynamic Add-ons
      for (var aName in addonNames) {
        final Map<String, dynamic>? addon = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['service_name'].toString().toUpperCase() == aName.toString().toUpperCase(), orElse: () => {});
        if (addon != null && addon.isNotEmpty) calculatedBase += (addon['price'] as num).toDouble();
      }

      // 3. Inject Mess Card if not already in add-ons
      if (messCard != null && !addonNames.any((a) => a.toString().toUpperCase() =='MESS')) {
        final Map<String, dynamic>? messPlan = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['category'] == 'Mess', orElse: () => {});
        if (messPlan != null && messPlan.isNotEmpty) calculatedBase += (messPlan['price'] as num).toDouble();
      }

      // 4. Calculate latest power bill
      final lastReading = await _client.from('meter_readings').select('electricity_charges').eq('student_id', user.id).order('month_period', ascending: false).limit(1).maybeSingle();
      double power = 0;
      if (lastReading != null) {
        power = (lastReading['electricity_charges'] as num? ?? 0.0).toDouble();
      }

      if (mounted) {
        setState(() {
          _role = profile?['role'] ?? 'hostel_student';
          _baseRent = calculatedBase;
          _powerBill = power;
          _totalRent = _baseRent + _powerBill;
          
          if (widget.initialType != null) {
            _paymentType = widget.initialType!;
          } else {
             _paymentType = (_role == 'mess_student' || _role == 'hostel_student') ? 'Rent' : 'MessCard';
          }
          _amountCtrl.text = _paymentType == 'Rent' ? _totalRent.toStringAsFixed(0) : '2500';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _screenshot = File(image.path));
    }
  }

  Future<void> _submitPayment() async {
    if (_screenshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI PROOF REQUIRED'), backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _isUploading = true);
    try {
      final user = _client.auth.currentUser;
      final fileName = 'approvals/${user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Usually we'd upload to Supabase Storage:
      // await _client.storage.from('documents').upload(fileName, _screenshot!);
      // String url = _client.storage.from('documents').getPublicUrl(fileName);
      
      // MOCK for now since we're and-box
      String mockUrl = 'https://hostel-assets.s3.amazonaws.com/proofs/upi_success.png';

      await _client.from('payment_approvals').insert({
        'user_id': user.id,
        'payment_type': _paymentType,
        'amount': double.parse(_amountCtrl.text),
        'screenshot_url': mockUrl,
        'status': 'Pending',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment request submitted. Awaiting approval.'), backgroundColor: Colors.indigoAccent));
      }
    } catch (_) { if (mounted) setState(() => _isUploading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MAKE PAYMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildRefractionOrbs(),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
                _buildTypeSelector(isDark),
                const SizedBox(height: 16),
                if (_paymentType == 'Rent') _buildBillingBreakdown(isDark),
                const SizedBox(height: 32),
                _buildUPINexus(isDark),
               const SizedBox(height: 32),
               _sectionHeader('EVIDENCE UPLOAD'),
               const SizedBox(height: 16),
               _buildScreenshotBox(isDark),
               const SizedBox(height: 48),
               SizedBox(
                 width: double.infinity, height: 60,
                 child: ElevatedButton(
                   onPressed: _isUploading ? null : _submitPayment,
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                   child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('INITIATE HQ APPROVAL', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
                 ),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    List<String> types = _role == 'mess_student' ? ['MessCard'] : ['Rent', 'MessCard'];
    return Row(children: types.map((t) {
      bool sel = _paymentType == t;
      return Expanded(child: GestureDetector(onTap: () => setState(() { _paymentType = t; _amountCtrl.text = t == 'Rent' ? _totalRent.toStringAsFixed(0) : '2500'; }), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(15), border: Border.all(color: sel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))), child: Center(child: Text(t.toUpperCase(), style: GoogleFonts.outfit(color: sel ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))))));
    }).toList());
  }

  Widget _buildUPINexus(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(35), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
             child: QrImageView(data: 'upi://pay?pa=hostel@upi&am=${_amountCtrl.text}&cu=INR', version: QrVersions.auto, size: 180, foregroundColor: Colors.black),
           ),
           const SizedBox(height: 24),
           Text('TOTAL PAYABLE: ₹${_amountCtrl.text}', style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
           const SizedBox(height: 8),
           Text('SCAN QR TO PAY VIA ANY UPI APP', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildScreenshotBox(bool isDark) {
    return GestureDetector(
      onTap: _pickScreenshot,
      child: Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: _screenshot != null 
          ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(_screenshot!, fit: BoxFit.cover))
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_photo_alternate_outlined, color: Colors.indigoAccent, size: 42), const SizedBox(height: 12), Text('TAP TO ATTACH UPI PROOF', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildBillingBreakdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(children: [
        _billingRow('BASE RENT', '₹${_baseRent.toInt()}', isDark),
        const SizedBox(height: 12),
        _billingRow('POWER (LATEST)', '₹${_powerBill.toInt()}', isDark, color: Colors.amberAccent),
        const Divider(height: 24, color: Colors.white10),
        _billingRow('TOTAL TO PAY', '₹${_totalRent.toInt()}', isDark, isTotal: true),
      ]),
    );
  }

  Widget _billingRow(String l, String v, bool isDark, {Color? color, bool isTotal = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
      Text(v, style: GoogleFonts.outfit(color: color ?? (isDark ? Colors.white : Colors.black), fontSize: isTotal ? 16 : 13, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _buildRefractionOrbs() => Positioned(bottom: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  Widget _sectionHeader(String l) => Text(l, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
}
