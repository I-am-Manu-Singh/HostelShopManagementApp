import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_upload_service.dart';
import '../../services/receipt_service.dart';
import '../admin/admin_finance_hub_screen.dart';

class StudentRentMessHistoryScreen extends StatefulWidget {
  final String? studentId; // If null, defaults to logged-in user
  final String? studentName;
  final String? initialType; // 'Rent' or 'MessCard'

  const StudentRentMessHistoryScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.initialType,
  });

  @override
  State<StudentRentMessHistoryScreen> createState() => _StudentRentMessHistoryScreenState();
}

class _StudentRentMessHistoryScreenState extends State<StudentRentMessHistoryScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAdmin = false;
  late String _targetUserId;

  DateTime _selectedMonth = DateTime.now();

  // Profile & Enrollment
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _enrollment;
  Map<String, dynamic>? _messCard;

  // Billing Breakdown for selected month
  double _roomRent = 0.0;
  double _messFee = 0.0;
  double _electricityCharge = 0.0;
  double _additionalCharges = 0.0;
  double _totalDuesForMonth = 0.0;
  double _amountPaidForMonth = 0.0;
  double _pendingDueForMonth = 0.0;
  double _cumulativeNextMonthRent = 0.0;

  // Detailed Unit Breakdown
  int _roomDays = 30;
  double _roomDailyRate = 0.0;
  double _meterPreviousReading = 0.0;
  double _meterLatestReading = 0.0;
  double _meterUnitsConsumed = 0.0;
  double _electricityUnitRate = 12.0;
  bool _hasMeterReading = false;
  String _electricityStatus = 'Standard Tariff';

  // Selected Package names
  String? _roomPlanName;
  List<dynamic> _addOnNames = [];

  // Payment receipts & proofs
  List<dynamic> _monthlyCollections = [];
  List<dynamic> _paymentApprovals = [];

  // Payment processing & proof upload
  File? _newProofFile;
  bool _isUploadingProof = false;
  String _selectedPaymentMode = 'Rent'; // 'Rent', 'MessCard', 'Entire Due'

  // UTR / Transaction ID entry
  final TextEditingController _utrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentAuthUser = _client.auth.currentUser;
    _targetUserId = widget.studentId ?? (currentAuthUser?.id ?? '');
    if (widget.initialType != null) {
      _selectedPaymentMode = widget.initialType!;
    }
    _checkRoleAndLoad();
  }

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  Future<void> _checkRoleAndLoad() async {
    final currentAuthUser = _client.auth.currentUser;
    if (currentAuthUser != null) {
      try {
        final currentProfile = await _client.from('profiles').select('role').eq('id', currentAuthUser.id).maybeSingle();
        final role = currentProfile?['role'] ?? 'user';
        _isAdmin = role == 'admin' || role == 'hostel_manager' || role == 'owner';
      } catch (_) {}
    }
    await _fetchMonthDetails();
  }

  Future<void> _fetchMonthDetails() async {
    if (_targetUserId.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final prof = await _client.from('profiles').select().eq('id', _targetUserId).maybeSingle();
      final enroll = await _client.from('hostel_enrollments').select('*, hostel_rooms(*)').eq('user_id', _targetUserId).maybeSingle();
      final mCard = await _client.from('mess_cards').select().eq('user_id', _targetUserId).maybeSingle();
      final rates = await _client.from('fee_structure').select();

      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      // 1. Calculate Room Rent & Duration
      final Map<String, dynamic>? selectedPkgs = enroll?['selected_packages'];
      final String? rPlan = selectedPkgs?['room_plan'];
      final List<dynamic> addons = selectedPkgs?['add_ons'] ?? [];

      double calculatedRoom = 0.0;
      if (rPlan != null) {
        final plan = rates.cast<Map<String, dynamic>>().firstWhere(
          (r) => r['service_name'].toString().toUpperCase() == rPlan.toUpperCase(),
          orElse: () => {},
        );
        if (plan.isNotEmpty) calculatedRoom = (plan['price'] as num).toDouble();
      } else if (enroll?['total_price'] != null) {
        calculatedRoom = (enroll!['total_price'] as num).toDouble();
      } else {
        final defaultHostel = rates.cast<Map<String, dynamic>>().firstWhere(
          (r) => r['category'] == 'Hostel' || r['category'] == 'Accommodation',
          orElse: () => {},
        );
        calculatedRoom = defaultHostel.isNotEmpty ? (defaultHostel['price'] as num).toDouble() : 0.0;
      }

      int cycleDays = 30;
      if (enroll?['created_at'] != null) {
        final joined = DateTime.tryParse(enroll!['created_at'].toString());
        if (joined != null) {
          cycleDays = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
        }
      }
      final double dailyRoomRate = cycleDays > 0 ? (calculatedRoom / cycleDays) : 0.0;

      // 2. Calculate Mess Fee
      double calculatedMess = 0.0;
      final messPlan = rates.cast<Map<String, dynamic>>().firstWhere(
        (r) => r['category'] == 'Mess',
        orElse: () => {},
      );
      if (messPlan.isNotEmpty) {
        calculatedMess = (messPlan['price'] as num).toDouble();
      }

      // 3. Add-on charges (Laundry, Gym, AC Maintenance, etc.)
      double calculatedAddons = 0.0;
      for (var aName in addons) {
        final addon = rates.cast<Map<String, dynamic>>().firstWhere(
          (r) => r['service_name'].toString().toUpperCase() == aName.toString().toUpperCase(),
          orElse: () => {},
        );
        if (addon.isNotEmpty) calculatedAddons += (addon['price'] as num).toDouble();
      }

      // 4. Electricity Bill & Meter Unit Breakdown for this month period
      final monthPeriodStr = DateFormat('yyyy-MM').format(_selectedMonth);
      final meterRes = await _client
          .from('meter_readings')
          .select('electricity_charges, latest_reading, previous_reading, reading_date')
          .eq('student_id', _targetUserId)
          .ilike('month_period', '%$monthPeriodStr%')
          .maybeSingle();

      double electricity = 0.0;
      double prevR = 0.0;
      double lastR = 0.0;
      double units = 0.0;
      bool hasMeter = false;

      if (meterRes != null) {
        hasMeter = true;
        electricity = (meterRes['electricity_charges'] as num? ?? 0.0).toDouble();
        prevR = (meterRes['previous_reading'] as num? ?? 0.0).toDouble();
        lastR = (meterRes['latest_reading'] as num? ?? 0.0).toDouble();
        units = (lastR - prevR).clamp(0.0, double.infinity);
      } else {
        // Fallback: check latest reading for room
        final roomId = enroll?['room_id'];
        if (roomId != null) {
          final roomReading = await _client
              .from('meter_readings')
              .select('electricity_charges, latest_reading, previous_reading')
              .eq('room_id', roomId)
              .ilike('month_period', '%$monthPeriodStr%')
              .maybeSingle();
          if (roomReading != null) {
            hasMeter = true;
            electricity = (roomReading['electricity_charges'] as num? ?? 0.0).toDouble();
            prevR = (roomReading['previous_reading'] as num? ?? 0.0).toDouble();
            lastR = (roomReading['latest_reading'] as num? ?? 0.0).toDouble();
            units = (lastR - prevR).clamp(0.0, double.infinity);
          }
        }
      }

      final double ratePerUnit = units > 0 && electricity > 0 ? (electricity / units) : 12.0;

      // 5. Total payments recorded in fiscal_collections for this month
      final collectionsRes = await _client
          .from('fiscal_collections')
          .select()
          .eq('user_id', _targetUserId)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .order('created_at', ascending: false);

      double paidTotal = 0.0;
      for (var col in collectionsRes) {
        paidTotal += (col['amount'] as num? ?? col['total_amount'] as num? ?? 0.0).toDouble();
      }

      // 6. Payment Approvals submitted by student for this month
      final approvalsRes = await _client
          .from('payment_approvals')
          .select()
          .eq('user_id', _targetUserId)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .order('created_at', ascending: false);

      final totalDues = calculatedRoom + calculatedMess + calculatedAddons + electricity;
      final pendingDues = (totalDues - paidTotal).clamp(0.0, double.infinity);
      final cumulativeNextMonth = totalDues + pendingDues;

      if (mounted) {
        setState(() {
          _profile = prof;
          _enrollment = enroll;
          _messCard = mCard;
          _roomPlanName = rPlan;
          _addOnNames = addons;
          _roomRent = calculatedRoom;
          _roomDays = cycleDays;
          _roomDailyRate = dailyRoomRate;
          _messFee = calculatedMess;
          _additionalCharges = calculatedAddons;
          _electricityCharge = electricity;
          _hasMeterReading = hasMeter;
          _meterPreviousReading = prevR;
          _meterLatestReading = lastR;
          _meterUnitsConsumed = units;
          _electricityUnitRate = ratePerUnit;
          _electricityStatus = hasMeter ? 'Meter Verified' : 'Standard Tariff (Pending Reading)';
          _totalDuesForMonth = totalDues;
          _amountPaidForMonth = paidTotal;
          _pendingDueForMonth = pendingDues;
          _cumulativeNextMonthRent = cumulativeNextMonth;
          _monthlyCollections = collectionsRes;
          _paymentApprovals = approvalsRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading billing history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Launch UPI application directly with pre-filled payment parameters
  Future<void> _launchUpiIntent(double amount, String note) async {
    final cleanAmount = amount.toStringAsFixed(2);
    final upiUrl = 'upi://pay?pa=hostel@upi&pn=Campus%20Hostel&am=$cleanAmount&cu=INR&tn=${Uri.encodeComponent(note)}';
    final uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Copy UPI ID and show instruction
        await Clipboard.setData(const ClipboardData(text: 'hostel@upi'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UPI ID (hostel@upi) copied to clipboard! Pay via any UPI App and attach proof below.'),
              backgroundColor: Colors.indigoAccent,
            ),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: 'hostel@upi'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied hostel@upi: $e'),
            backgroundColor: Colors.indigoAccent,
          ),
        );
      }
    }
  }

  /// Unified Pay Rent & Proof Submission Bottom Sheet
  void _showPayRentModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payableAmount = _pendingDueForMonth > 0 ? _pendingDueForMonth : _totalDuesForMonth;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131722) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.indigoAccent.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, -10)),
              ],
            ),
            child: Column(
              children: [
                // Top Grab Bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PAY RENT & EXPENSES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigoAccent, letterSpacing: 1.5)),
                          Text('Cycle: $monthLabel • Total: ₹${payableAmount.toInt()}', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Mode Selector (Rent vs Mess vs Full Due)
                      Row(
                        children: [
                          _buildModalTabItem('Rent', 'ROOM ONLY', payableAmount, _selectedPaymentMode == 'Rent', () => setModalState(() => _selectedPaymentMode = 'Rent')),
                          const SizedBox(width: 8),
                          _buildModalTabItem('MessCard', 'MESS ONLY', _messFee, _selectedPaymentMode == 'MessCard', () => setModalState(() => _selectedPaymentMode = 'MessCard')),
                          const SizedBox(width: 8),
                          _buildModalTabItem('Entire Due', 'TOTAL DUE', payableAmount, _selectedPaymentMode == 'Entire Due', () => setModalState(() => _selectedPaymentMode = 'Entire Due')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Dynamic UPI QR Card
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                                  ],
                                ),
                                child: QrImageView(
                                  data: 'upi://pay?pa=hostel@upi&pn=Hostel%20Admin&am=${payableAmount.toStringAsFixed(2)}&cu=INR&tn=Rent_$monthLabel',
                                  version: QrVersions.auto,
                                  size: 170,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('₹${payableAmount.toInt()}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('VPA: hostel@upi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigoAccent)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(const ClipboardData(text: 'hostel@upi'));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied hostel@upi!'), duration: Duration(seconds: 1)));
                                    },
                                    child: const Icon(Icons.copy_rounded, size: 14, color: Colors.indigoAccent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: const Text('Open Installed UPI App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () => _launchUpiIntent(payableAmount, 'Rent $monthLabel'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Manual UTR / Reference No (Optional)
                      TextField(
                        controller: _utrController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'UTR / TRANSACTION REF (OPTIONAL)',
                          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                          hintText: 'e.g. 324158912301',
                          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11),
                          prefixIcon: const Icon(Icons.tag_rounded, color: Colors.indigoAccent, size: 18),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Proof Attachment Area
                      Text('ATTACH PAYMENT SCREENSHOT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.indigoAccent)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final source = await showModalBottomSheet<ImageSource>(
                            context: context,
                            backgroundColor: Theme.of(context).cardColor,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                            builder: (bCtx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt_rounded, color: Colors.indigoAccent),
                                    title: const Text('Take Camera Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.pop(bCtx, ImageSource.camera),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library_rounded, color: Colors.indigoAccent),
                                    title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.pop(bCtx, ImageSource.gallery),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (source == null) return;
                          final picked = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1920, maxHeight: 1920);
                          if (picked != null) {
                            setModalState(() => _newProofFile = File(picked.path));
                            setState(() => _newProofFile = File(picked.path));
                          }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.indigoAccent.withOpacity(0.3), style: BorderStyle.solid),
                          ),
                          child: _newProofFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.file(_newProofFile!, fit: BoxFit.cover, width: double.infinity),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_rounded, color: Colors.indigoAccent, size: 36),
                                    const SizedBox(height: 8),
                                    Text('Tap to select receipt or screenshot', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigoAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: _isUploadingProof
                              ? null
                              : () async {
                                  if (_newProofFile == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please attach payment screenshot proof'), backgroundColor: Colors.redAccent),
                                    );
                                    return;
                                  }

                                  Navigator.pop(modalCtx);
                                  await _executeSubmitPaymentProof(payableAmount);
                                },
                          child: _isUploadingProof
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text('SUBMIT FOR ADMIN APPROVAL', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalTabItem(String type, String label, double amount, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.indigoAccent : Colors.indigoAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? Colors.indigoAccent : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.indigoAccent, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text('₹${amount.toInt()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  /// Robust Payment Submission (Guards against schema variations in payment_approvals)
  Future<void> _executeSubmitPaymentProof(double amount) async {
    setState(() => _isUploadingProof = true);
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final utrNote = _utrController.text.trim();
    final noteString = 'Submitted for $monthLabel${utrNote.isNotEmpty ? ' [UTR: $utrNote]' : ''}';

    try {
      final uploadedUrl = await StorageUploadService().uploadFile(
        file: _newProofFile!,
        preferredBucket: 'documents',
        pathPrefix: 'rent_proofs',
      );

      // Attempt full insert with admin_notes
      try {
        await _client.from('payment_approvals').insert({
          'user_id': _targetUserId,
          'payment_type': _selectedPaymentMode == 'MessCard' ? 'MessCard' : 'Rent',
          'amount': amount,
          'screenshot_url': uploadedUrl,
          'status': 'Pending',
          'admin_notes': noteString,
        });
      } catch (insertError) {
        debugPrint('Insert with admin_notes failed, retrying without: $insertError');
        // Fallback: omit admin_notes in case remote schema cache lacks it
        await _client.from('payment_approvals').insert({
          'user_id': _targetUserId,
          'payment_type': _selectedPaymentMode == 'MessCard' ? 'MessCard' : 'Rent',
          'amount': amount,
          'screenshot_url': uploadedUrl,
          'status': 'Pending',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded successfully! Awaiting verification.'),
            backgroundColor: Colors.greenAccent,
          ),
        );
        _utrController.clear();
        setState(() => _newProofFile = null);
      }
      _fetchMonthDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  void _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECT BILLING CYCLE MONTH',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
      _fetchMonthDetails();
    }
  }

  Future<void> _downloadReceiptPdf() async {
    final roomData = _enrollment?['hostel_rooms'];
    final roomNum = roomData?['room_number']?.toString() ?? 'N/A';
    final building = roomData?['building_name']?.toString() ?? 'Campus';

    final receiptData = {
      'id': 'RENT-${DateFormat('yyyyMM').format(_selectedMonth)}-${_targetUserId.substring(0, 6)}',
      'created_at': DateTime.now().toIso8601String(),
      'collection_type': 'Rent & Utilities',
      'base_rent': _roomRent,
      'electricity_charges': _electricityCharge,
      'amount': _pendingDueForMonth > 0 ? _pendingDueForMonth : _totalDuesForMonth,
      'payment_method': 'UPI / Digital Bank',
      'days_billed': _roomDays,
    };

    await ReceiptService.generateFiscalReceipt(
      receiptData,
      _profile?['full_name'] ?? 'Student Member',
      roomNumber: roomNum,
      buildingName: building,
      phone: _profile?['phone_no'],
      roomPlan: _roomPlanName ?? 'Standard Room Plan',
      addOns: _addOnNames,
      daysBilled: _roomDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    final displayName = widget.studentName ?? _profile?['full_name'] ?? 'Student';
    final role = _profile?['role'] ?? 'hostel_student';
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FINANCE & RENT BREAKDOWN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: textColor)),
            Text(displayName, style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Download Statement PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.indigoAccent, size: 20),
            onPressed: _downloadReceiptPdf,
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent, size: 18),
            label: Text(monthLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.indigoAccent, fontSize: 11)),
            onPressed: _showMonthPicker,
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.indigoAccent),
              tooltip: 'Admin Finance Hub',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceHubScreen())).then((_) => _fetchMonthDetails()),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : RefreshIndicator(
              onRefresh: _fetchMonthDetails,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. Hero Total Card with Cumulative Next Month Projection & PAY RENT Action
                  _buildBillingHeroCard(isDark),
                  const SizedBox(height: 20),

                  // 2. Itemized Breakdown Matrix with Detailed Units
                  _buildSectionHeader('FEE COMPONENT & UNITS BREAKDOWN'),
                  const SizedBox(height: 12),

                  // Room Accommodation with Unit Days & Daily Rate
                  _buildDetailedRoomCard(isDark),
                  const SizedBox(height: 10),

                  // Mess & Food
                  _buildFeeItemTile(
                    'Mess & Food Subscription',
                    _messFee,
                    Icons.restaurant_rounded,
                    Colors.orangeAccent,
                    isDark,
                    subtitle: role == 'mess_student' ? 'Active Meal Pass' : 'Mess Card Meal Subscription',
                    badge: 'MONTHLY FIXED',
                  ),
                  const SizedBox(height: 10),

                  // Electricity Power Meter Detailed Unit Calculation Card
                  _buildDetailedElectricityCard(isDark),
                  const SizedBox(height: 10),

                  // Addons
                  if (_additionalCharges > 0) ...[
                    _buildFeeItemTile(
                      'Selected Add-ons & Amenities',
                      _additionalCharges,
                      Icons.add_circle_outline_rounded,
                      Colors.tealAccent,
                      isDark,
                      subtitle: _addOnNames.join(', '),
                      badge: '${_addOnNames.length} ACTIVE',
                    ),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 14),
                  // 3. Payment Status & Action Card
                  _buildSettlementCard(isDark),

                  const SizedBox(height: 28),
                  // 4. Receipts & Uploaded Proofs for Month
                  _buildSectionHeader('PAYMENT RECEIPTS & UPI AUDIT PROOFS'),
                  const SizedBox(height: 12),
                  if (_monthlyCollections.isEmpty && _paymentApprovals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                      child: Center(
                        child: Text(
                          'No payment proofs or receipts recorded for $monthLabel.',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 12),
                        ),
                      ),
                    )
                  else ...[
                    ..._monthlyCollections.map((col) => _buildCollectionRecordTile(col, isDark)),
                    ..._paymentApprovals.map((appr) => _buildApprovalRecordTile(appr, isDark)),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildBillingHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MONTHLY BILLING DUE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _pendingDueForMonth <= 0 ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _pendingDueForMonth <= 0 ? 'CLEARED' : 'DUE PENDING',
                  style: TextStyle(
                    color: _pendingDueForMonth <= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_pendingDueForMonth.toInt()}',
            style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w900, color: _pendingDueForMonth <= 0 ? Colors.greenAccent : Colors.redAccent),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Month Charges: ₹${_totalDuesForMonth.toInt()} • Cleared: ₹${_amountPaidForMonth.toInt()}',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT MONTH PROJECTED', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('Cumulative: ₹${_cumulativeNextMonthRent.toInt()}', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_rounded, size: 14),
                    label: const Text('PAY RENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showPayRentModal,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file_rounded, size: 14),
                    label: const Text('ATTACH PROOF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isUploadingProof ? null : _showPayRentModal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Detailed Room Accommodation breakdown with daily rate and billing units
  Widget _buildDetailedRoomCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigoAccent.withOpacity(0.15),
                child: const Icon(Icons.bed_outlined, color: Colors.indigoAccent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room Accommodation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(_roomPlanName ?? 'Standard Room Plan', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10)),
                  ],
                ),
              ),
              Text('₹${_roomRent.toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.indigoAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Billing Duration: $_roomDays Days', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                Text('Base Rate: ~₹${_roomDailyRate.toStringAsFixed(1)} / day', style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Detailed Electricity Power Meter card showing Start reading, End reading, Units consumed and rate per unit
  Widget _buildDetailedElectricityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.amberAccent.withOpacity(0.15),
                child: const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Electricity & Power Meter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(_electricityStatus, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10)),
                  ],
                ),
              ),
              Text('₹${_electricityCharge.toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.amberAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _unitMetric('PREVIOUS READING', _hasMeterReading ? _meterPreviousReading.toStringAsFixed(1) : 'N/A', isDark),
                    _unitMetric('LATEST READING', _hasMeterReading ? _meterLatestReading.toStringAsFixed(1) : 'N/A', isDark),
                    _unitMetric('UNITS USED', _hasMeterReading ? '${_meterUnitsConsumed.toStringAsFixed(1)} kWh' : '0.0', isDark, highlight: true),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tariff Rate: ₹${_electricityUnitRate.toStringAsFixed(1)} / kWh unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                    Text(
                      _hasMeterReading ? '(${_meterUnitsConsumed.toStringAsFixed(1)} × ₹${_electricityUnitRate.toStringAsFixed(0)} = ₹${_electricityCharge.toInt()})' : 'Pending Meter Entry',
                      style: const TextStyle(fontSize: 9, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitMetric(String label, String value, bool isDark, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(color: highlight ? Colors.amberAccent : (isDark ? Colors.white : Colors.black87), fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildFeeItemTile(String title, double amount, IconData icon, Color color, bool isDark, {String? subtitle, String? badge}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(badge, style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10)),
                ],
              ],
            ),
          ),
          Text('₹${amount.toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _pendingDueForMonth <= 0 ? Colors.green.withOpacity(0.05) : Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _pendingDueForMonth <= 0 ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(_pendingDueForMonth <= 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: _pendingDueForMonth <= 0 ? Colors.greenAccent : Colors.amberAccent, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingDueForMonth <= 0 ? 'ALL DUES SETTLED FOR THIS MONTH' : 'PENDING SETTLEMENT: ₹${_pendingDueForMonth.toInt()}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: _pendingDueForMonth <= 0 ? Colors.greenAccent : Colors.amberAccent),
                ),
                const SizedBox(height: 2),
                Text(
                  _pendingDueForMonth <= 0
                      ? 'Rent, food and meter balances are confirmed in campus records.'
                      : 'Scan UPI QR code or pay to hostel@upi, then attach screenshot.',
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ),
          if (_pendingDueForMonth > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showPayRentModal,
              child: const Text('PAY NOW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionRecordTile(dynamic col, bool isDark) {
    final amt = col['amount'] ?? col['total_amount'] ?? 0;
    final type = col['collection_type'] ?? 'Rent';
    final method = col['payment_method'] ?? 'UPI';
    final dateStr = col['created_at'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(col['created_at'])) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_rounded, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OFFICIAL RECEIPT: $type ($method)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent)),
                Text(dateStr, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 9)),
              ],
            ),
          ),
          Text('+₹$amt', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildApprovalRecordTile(dynamic appr, bool isDark) {
    final status = (appr['status'] ?? 'Pending').toString();
    final bool isApproved = status.toLowerCase() == 'approved';
    final bool isRejected = status.toLowerCase() == 'rejected';
    final color = isApproved ? Colors.greenAccent : (isRejected ? Colors.redAccent : Colors.amberAccent);
    final amt = appr['amount'] ?? 0;
    final screenshotUrl = appr['screenshot_url']?.toString();
    final notes = appr['admin_notes']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${appr['payment_type'] ?? 'Rent'} Proof: ₹$amt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                    Text('Status: ${status.toUpperCase()}', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (screenshotUrl != null && screenshotUrl.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.image_search_rounded, color: Colors.indigoAccent),
                  onPressed: () => _viewScreenshot(screenshotUrl, isDark),
                ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Admin Note: $notes', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  void _viewScreenshot(String url, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(url, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2));
  }
}
