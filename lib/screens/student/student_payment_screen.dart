import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/receipt_service.dart';
import '../../services/storage_upload_service.dart';

class StudentPaymentScreen extends StatefulWidget {
  final String? initialType; // 'Rent' or 'MessCard'
  const StudentPaymentScreen({super.key, this.initialType});

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  final _client = Supabase.instance.client;
  String _paymentType = 'Rent';
  final _amountCtrl = TextEditingController(text: '0');
  File? _screenshot;
  bool _isUploading = false;
  String _role = 'hostel_student';
  double _baseRent = 0;
  double _powerBill = 0;
  double _totalRent = 0;
  double _messPrice = 0;

  // Student & cycle details
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _enrollment;
  DateTime? _cycleStartDate;
  DateTime? _cycleEndDate;
  int _cycleDays = 30;
  String? _roomPlan;
  List<dynamic> _addOns = [];
  dynamic _latestCollection;

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
      
      double calculatedBase = 0;
      
      // 1. Get Room Plan Price
      if (roomPlanName != null) {
        final Map<String, dynamic>? plan = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['service_name'].toString().toUpperCase() == roomPlanName.toUpperCase(), orElse: () => {});
        if (plan != null && plan.isNotEmpty) calculatedBase += (plan['price'] as num).toDouble();
      } else if (enrollment?['total_price'] != null) {
        calculatedBase = (enrollment!['total_price'] as num).toDouble();
      } else {
        // Dynamic fallback from fee_structure Accommodation category
        final roomFeePlan = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['category'] == 'Hostel' || r['category'] == 'Accommodation', orElse: () => {});
        calculatedBase = roomFeePlan.isNotEmpty ? (roomFeePlan['price'] as num).toDouble() : 0.0;
      }

      // 2. Add dynamic Add-ons
      for (var aName in addonNames) {
        final Map<String, dynamic>? addon = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['service_name'].toString().toUpperCase() == aName.toString().toUpperCase(), orElse: () => {});
        if (addon != null && addon.isNotEmpty) calculatedBase += (addon['price'] as num).toDouble();
      }

      // 3. Determine Mess Card price dynamically from fee_structure
      double messFee = 0.0;
      final Map<String, dynamic>? messPlan = rates.cast<Map<String, dynamic>>().firstWhere((r) => r['category'] == 'Mess', orElse: () => {});
      if (messPlan != null && messPlan.isNotEmpty) {
        messFee = (messPlan['price'] as num).toDouble();
      }
      if (messCard != null && !addonNames.any((a) => a.toString().toUpperCase() == 'MESS')) {
        calculatedBase += messFee;
      }

      // 4. Calculate latest power bill
      final lastReading = await _client.from('meter_readings').select('electricity_charges').eq('student_id', user.id).order('month_period', ascending: false).limit(1).maybeSingle();
      double power = 0;
      if (lastReading != null) {
        power = (lastReading['electricity_charges'] as num? ?? 0.0).toDouble();
      }

      // 5. Determine Billing Cycle from joining date (created_at)
      DateTime? startDate;
      DateTime? endDate;
      int cycleDuration = 30;

      final joinDateStr = enrollment?['created_at'];
      if (joinDateStr != null) {
        final joined = DateTime.parse(joinDateStr);
        final now = DateTime.now();
        final joinDay = joined.day;

        // Current cycle start: day of month matching join day
        final candidateStart = DateTime(now.year, now.month, joinDay > 28 ? 28 : joinDay);
        if (now.isBefore(candidateStart)) {
          // In previous month's cycle
          final prevMonth = now.month == 1 ? 12 : now.month - 1;
          final prevYear = now.month == 1 ? now.year - 1 : now.year;
          startDate = DateTime(prevYear, prevMonth, joinDay > 28 ? 28 : joinDay);
          endDate = candidateStart;
        } else {
          startDate = candidateStart;
          final nextMonth = now.month == 12 ? 1 : now.month + 1;
          final nextYear = now.month == 12 ? now.year + 1 : now.year;
          endDate = DateTime(nextYear, nextMonth, joinDay > 28 ? 28 : joinDay);
        }
        cycleDuration = endDate.difference(startDate).inDays;
      }

      // Fetch latest fiscal collection record if any
      final lastCol = await _client.from('fiscal_collections').select().eq('user_id', user.id).order('created_at', ascending: false).limit(1).maybeSingle();

      if (mounted) {
        setState(() {
          _profile = profile;
          _enrollment = enrollment;
          _role = profile?['role'] ?? 'hostel_student';
          _baseRent = calculatedBase;
          _powerBill = power;
          _totalRent = _baseRent + _powerBill;
          _messPrice = messFee;
          _cycleStartDate = startDate;
          _cycleEndDate = endDate;
          _cycleDays = cycleDuration;
          _roomPlan = roomPlanName;
          _addOns = addonNames;
          _latestCollection = lastCol;
          
          if (widget.initialType != null) {
            _paymentType = widget.initialType!;
          } else {
             _paymentType = (_role == 'mess_student' || _role == 'hostel_student') ? 'Rent' : 'MessCard';
          }
          _amountCtrl.text = _paymentType == 'Rent' ? _totalRent.toStringAsFixed(0) : _messPrice.toStringAsFixed(0);
        });
      }
    } catch (_) {}
  }

  Future<void> _downloadReceiptPdf() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    final roomData = _enrollment?['hostel_rooms'];
    final roomNum = roomData?['room_number']?.toString() ?? 'N/A';
    final building = roomData?['building']?.toString() ?? 'Campus';
    
    final receiptData = _latestCollection ?? {
      'id': 'BILL-${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
      'collection_type': _paymentType,
      'base_rent': _baseRent,
      'electricity_charges': _powerBill,
      'amount': _paymentType == 'Rent' ? _totalRent : _messPrice,
      'payment_method': 'UPI / Digital Bank',
      'billing_start_date': _cycleStartDate?.toIso8601String(),
      'billing_end_date': _cycleEndDate?.toIso8601String(),
      'days_billed': _cycleDays,
    };

    await ReceiptService.generateFiscalReceipt(
      receiptData,
      _profile?['full_name'] ?? 'Student Member',
      roomNumber: roomNum,
      buildingName: building,
      phone: _profile?['phone_no'],
      roomPlan: _roomPlan ?? (_paymentType == 'Rent' ? 'Standard Room' : 'Mess Card Meal Plan'),
      addOns: _addOns,
      cycleStart: _cycleStartDate,
      cycleEnd: _cycleEndDate,
      daysBilled: _cycleDays,
    );
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    // Ask whether to take photo with Camera or pick from Gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SELECT PAYMENT PROOF', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.indigoAccent),
                title: Text('Take Photo with Camera', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.indigoAccent),
                title: Text('Select from Gallery / Files', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        setState(() => _screenshot = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not access camera/storage: $e'), backgroundColor: Colors.redAccent));
      }
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
      if (user == null) throw Exception('User not logged in');

      // Upload via StorageUploadService with automatic bucket fallback (documents -> receipts -> mandi-assets)
      final screenshotUrl = await StorageUploadService().uploadFile(
        file: _screenshot!,
        preferredBucket: 'documents',
        pathPrefix: 'approvals',
      );

      await _client.from('payment_approvals').insert({
        'user_id': user.id,
        'payment_type': _paymentType,
        'amount': double.parse(_amountCtrl.text),
        'screenshot_url': screenshotUrl,
        'status': 'Pending',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment request submitted. Awaiting approval.'), backgroundColor: Colors.indigoAccent));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e'), backgroundColor: Colors.redAccent));
      }
    }
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
        actions: [
          IconButton(
            tooltip: 'Download / Share Receipt PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.indigoAccent),
            onPressed: _downloadReceiptPdf,
          ),
        ],
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
                _buildBillingBreakdown(isDark),
                const SizedBox(height: 24),
                _buildReceiptDownloadButton(isDark),
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

  Widget _buildReceiptDownloadButton(bool isDark) {
    return OutlinedButton.icon(
      onPressed: _downloadReceiptPdf,
      icon: const Icon(Icons.download_rounded, color: Colors.indigoAccent, size: 18),
      label: Text('DOWNLOAD ITEMISED STATEMENT PDF', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.indigoAccent.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    List<String> types = _role == 'mess_student' ? ['MessCard'] : ['Rent', 'MessCard'];
    return Row(children: types.map((t) {
      bool sel = _paymentType == t;
      return Expanded(child: GestureDetector(onTap: () => setState(() { _paymentType = t; _amountCtrl.text = t == 'Rent' ? _totalRent.toStringAsFixed(0) : _messPrice.toStringAsFixed(0); }), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(15), border: Border.all(color: sel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))), child: Center(child: Text(t.toUpperCase(), style: GoogleFonts.outfit(color: sel ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))))));
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
    final cycleText = (_cycleStartDate != null && _cycleEndDate != null)
        ? '${DateFormat('dd MMM').format(_cycleStartDate!)} - ${DateFormat('dd MMM yyyy').format(_cycleEndDate!)} ($_cycleDays Days)'
        : 'Monthly Calendar Cycle';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.indigoAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 16, color: Colors.indigoAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('CURRENT BILLING CYCLE: $cycleText', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
        if (_roomPlan != null) ...[
          _billingRow('PLAN: ${_roomPlan!.toUpperCase()}', 'INCLUDED', isDark),
          const SizedBox(height: 8),
        ],
        for (var add in _addOns) ...[
          _billingRow('+ ADD-ON: ${add.toString().toUpperCase()}', 'ACTIVE', isDark, color: Colors.tealAccent),
          const SizedBox(height: 8),
        ],
        _billingRow('BASE RENT', '₹${_baseRent.toInt()}', isDark),
        const SizedBox(height: 12),
        _billingRow('POWER CHARGES', '₹${_powerBill.toInt()}', isDark, color: Colors.amberAccent),
        const Divider(height: 24, color: Colors.white10),
        _billingRow('TOTAL TO PAY', '₹${_totalRent.toInt()}', isDark, isTotal: true),
      ]),
    );
  }

  Widget _billingRow(String l, String v, bool isDark, {Color? color, bool isTotal = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
      Text(v, style: GoogleFonts.outfit(color: color ?? (isDark ? Colors.white : Colors.black), fontSize: isTotal ? 16 : 13, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _buildRefractionOrbs() => Positioned(bottom: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  Widget _sectionHeader(String l) => Text(l, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
}
