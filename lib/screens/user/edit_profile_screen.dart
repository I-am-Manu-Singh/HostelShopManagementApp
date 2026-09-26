import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/storage_upload_service.dart';

// ── Role capability helpers ──────────────────────────────────────────────────
bool _needsParentInfo(String role) =>
    ['hostel_student', 'mess_student'].contains(role);
bool _needsAcademicInfo(String role) =>
    ['hostel_student', 'mess_student'].contains(role);
bool _needsHealthInfo(String role) =>
    ['hostel_student', 'mess_student', 'staff'].contains(role);
bool _needsCampusLogistics(String role) =>
    ['hostel_student', 'mess_student'].contains(role);
bool _needsMandiPrefs(String role) =>
    ['farmer_seller', 'delivery_partner', 'store_customer'].contains(role);
bool _needsHomeAddress(String role) => [
      'hostel_student',
      'mess_student',
      'staff',
      'store_customer',
      'farmer_seller',
      'delivery_partner',
    ].contains(role);

// ── Constants ────────────────────────────────────────────────────────────────
const List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const List<String> _indianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Delhi', 'Jammu & Kashmir', 'Ladakh', 'Chandigarh', 'Puducherry',
];
const List<String> _mandiUserTypes = ['domestic', 'commercial', 'wholesale'];
const List<String> _sessionYears = [
  '2020-21', '2021-22', '2022-23', '2023-24', '2024-25',
  '2025-26', '2026-27', '2027-28', '2028-29',
];

class EditProfileScreen extends StatefulWidget {
  final bool isOnboarding;
  final String? forceRole;
  const EditProfileScreen({super.key, this.isOnboarding = false, this.forceRole});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPasswordLoading = false;
  Map<String, dynamic>? _userData;
  String _role = 'store_customer';

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneNoCtrl = TextEditingController();
  String? _bloodGroup;
  final _medicalInfoCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _fNameCtrl = TextEditingController();
  final _fPhoneCtrl = TextEditingController();
  final _fWACtrl = TextEditingController();
  final _mNameCtrl = TextEditingController();
  final _mPhoneCtrl = TextEditingController();
  final _mWACtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _selectedState;
  final _instituteCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();
  final _schoolCityCtrl = TextEditingController();
  String? _sessionYear;
  final _meterReadingCtrl = TextEditingController();
  DateTime? _doj;
  final _mandiAddressCtrl = TextEditingController();
  final _mandiLocationCtrl = TextEditingController();
  String _mandiUserType = 'domestic';
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneNoCtrl, _medicalInfoCtrl,
      _emergencyContactCtrl, _fNameCtrl, _fPhoneCtrl, _fWACtrl,
      _mNameCtrl, _mPhoneCtrl, _mWACtrl, _addressCtrl, _cityCtrl,
      _instituteCtrl, _rollNoCtrl, _schoolCityCtrl, _meterReadingCtrl,
      _mandiAddressCtrl, _mandiLocationCtrl,
      _passwordController, _confirmPasswordController,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _fetchData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (res != null) {
        _nameCtrl.text = res['full_name'] ?? '';
        _emailCtrl.text = user.email ?? '';
        _phoneNoCtrl.text = res['phone_no'] ?? '';
        _bloodGroup = _bloodGroups.contains(res['blood_group']) ? res['blood_group'] as String? : null;
        _medicalInfoCtrl.text = res['medical_info'] ?? '';
        _emergencyContactCtrl.text = res['emergency_contact_no'] ?? res['emergency_contact'] ?? '';
        _fNameCtrl.text = res['father_name'] ?? '';
        _fPhoneCtrl.text = res['father_phone'] ?? '';
        _fWACtrl.text = res['father_whatsapp'] ?? '';
        _mNameCtrl.text = res['mother_name'] ?? '';
        _mPhoneCtrl.text = res['mother_phone'] ?? '';
        _mWACtrl.text = res['mother_whatsapp'] ?? '';
        _addressCtrl.text = res['home_address'] ?? '';
        _cityCtrl.text = res['city'] ?? '';
        _selectedState = _indianStates.contains(res['state']) ? res['state'] as String? : null;
        _instituteCtrl.text = res['institute'] ?? '';
        _rollNoCtrl.text = res['institute_roll_no'] ?? '';
        _schoolCityCtrl.text = res['school_city'] ?? '';
        _sessionYear = _sessionYears.contains(res['session_year']) ? res['session_year'] as String? : null;
        _meterReadingCtrl.text = (res['meter_reading'] ?? 0).toString();
        if (res['date_of_joining'] != null) _doj = DateTime.parse(res['date_of_joining'] as String);
        _mandiAddressCtrl.text = res['delivery_address'] ?? '';
        _mandiLocationCtrl.text = res['delivery_location'] ?? '';
        _mandiUserType = res['user_type'] ?? 'domestic';
        _role = widget.forceRole ?? res['role'] ?? 'store_customer';
      } else {
        _role = widget.forceRole ?? 'store_customer';
        _emailCtrl.text = user.email ?? '';
      }
      if (mounted) setState(() { _userData = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full name is required'), backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = _client.auth.currentUser;
      final payload = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'phone_no': _phoneNoCtrl.text.trim(),
        'blood_group': _bloodGroup,
        'medical_info': _medicalInfoCtrl.text.trim(),
        'emergency_contact_no': _emergencyContactCtrl.text.trim(),
        'father_name': _fNameCtrl.text.trim(),
        'father_phone': _fPhoneCtrl.text.trim(),
        'father_whatsapp': _fWACtrl.text.trim(),
        'mother_name': _mNameCtrl.text.trim(),
        'mother_phone': _mPhoneCtrl.text.trim(),
        'mother_whatsapp': _mWACtrl.text.trim(),
        'home_address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _selectedState,
        'institute': _instituteCtrl.text.trim(),
        'institute_roll_no': _rollNoCtrl.text.trim(),
        'school_city': _schoolCityCtrl.text.trim(),
        'session_year': _sessionYear,
        'meter_reading': double.tryParse(_meterReadingCtrl.text) ?? 0,
        'date_of_joining': _doj?.toIso8601String(),
        'delivery_address': _mandiAddressCtrl.text.trim(),
        'delivery_location': _mandiLocationCtrl.text.trim(),
        'user_type': _mandiUserType,
      };
      if (widget.isOnboarding) payload['onboarding_done'] = true;
      await _client.from('profiles').update(payload).eq('id', user!.id);
      if (widget.isOnboarding) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome! Profile set up successfully.'), backgroundColor: Colors.indigoAccent));
          Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PROFILE SYNCHRONIZED'), backgroundColor: Colors.indigoAccent));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updatePassword() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (pass.isEmpty || pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords mismatch.')));
      return;
    }
    setState(() => _isPasswordLoading = true);
    try {
      await _client.auth.updateUser(UserAttributes(password: pass));
      _passwordController.clear(); _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SECURITY KEY ESTABLISHED'), backgroundColor: Colors.indigoAccent));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final title = widget.isOnboarding ? 'COMPLETE YOUR PROFILE' : 'PROFILE EVOLUTION';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.isOnboarding,
        leading: widget.isOnboarding ? null : IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              widget.isOnboarding ? 'SAVE & CONTINUE' : 'SAVE',
              style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isOnboarding) ...[
                    const SizedBox(height: 8),
                    _buildOnboardingBanner(isDark),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionHeader('PROFILE PHOTO'),
                  _buildPhotoUploader(isDark),
                  const SizedBox(height: 28),
                  _buildSectionHeader('CORE IDENTITY'),
                  _buildField(_nameCtrl, 'FULL NAME *', Icons.person_outline_rounded, isDark),
                  _buildField(_phoneNoCtrl, 'CONTACT NUMBER *', Icons.phone_android_rounded, isDark, isPhone: true),
                  _buildField(_emailCtrl, 'EMAIL (READ-ONLY)', Icons.alternate_email_rounded, isDark, readOnly: true),
                  if (_needsHomeAddress(_role)) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('HOME ADDRESS'),
                    _buildField(_addressCtrl, 'HOME ADDRESS', Icons.home_work_outlined, isDark),
                    _buildField(_cityCtrl, 'CITY', Icons.location_city_rounded, isDark),
                    _buildDropdownPicker('STATE', Icons.map_rounded, _indianStates, _selectedState, (v) => setState(() => _selectedState = v), isDark),
                  ],
                  if (_needsParentInfo(_role)) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader("FATHER'S DETAILS"),
                    _buildField(_fNameCtrl, "FATHER'S NAME", Icons.badge_outlined, isDark),
                    _buildField(_fPhoneCtrl, "FATHER'S PHONE", Icons.phone_enabled_rounded, isDark, isPhone: true),
                    _buildField(_fWACtrl, "FATHER'S WHATSAPP", Icons.chat_bubble_outline_rounded, isDark, isPhone: true),
                    const SizedBox(height: 28),
                    _buildSectionHeader("MOTHER'S DETAILS"),
                    _buildField(_mNameCtrl, "MOTHER'S NAME", Icons.badge_outlined, isDark),
                    _buildField(_mPhoneCtrl, "MOTHER'S PHONE", Icons.phone_enabled_rounded, isDark, isPhone: true),
                    _buildField(_mWACtrl, "MOTHER'S WHATSAPP", Icons.chat_bubble_outline_rounded, isDark, isPhone: true),
                  ],
                  if (_needsAcademicInfo(_role)) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('ACADEMIC DETAILS'),
                    _buildField(_instituteCtrl, 'INSTITUTE / COLLEGE NAME', Icons.school_outlined, isDark),
                    _buildField(_rollNoCtrl, 'ROLL / ENROLMENT NO.', Icons.numbers_rounded, isDark),
                    _buildField(_schoolCityCtrl, 'INSTITUTE CITY', Icons.apartment_rounded, isDark),
                    _buildDropdownPicker('SESSION YEAR', Icons.history_edu_rounded, _sessionYears, _sessionYear, (v) => setState(() => _sessionYear = v), isDark),
                  ],
                  if (_needsHealthInfo(_role)) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('HEALTH & SAFETY'),
                    _buildBloodGroupPicker(isDark),
                    _buildField(_medicalInfoCtrl, 'MEDICAL INFO / ALLERGIES', Icons.health_and_safety_outlined, isDark),
                    _buildField(_emergencyContactCtrl, 'EMERGENCY CONTACT PHONE', Icons.emergency_outlined, isDark, isPhone: true),
                  ],
                  if (_needsCampusLogistics(_role)) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('CAMPUS LOGISTICS'),
                    _buildDatePicker('DATE OF JOINING (DOJ)', isDark),
                    _buildField(_meterReadingCtrl, 'METER READING (kWh)', Icons.speed_rounded, isDark, isNumeric: true),
                  ],
                  if (_needsMandiPrefs(_role)) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('MANDI MART PREFERENCES'),
                    _buildField(_mandiAddressCtrl, 'DELIVERY ADDRESS', Icons.home_rounded, isDark),
                    _buildField(_mandiLocationCtrl, 'DELIVERY LOCATION / AREA', Icons.pin_drop_rounded, isDark),
                    _buildMandiTypePicker(isDark),
                  ],
                  if (!widget.isOnboarding) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('VERIFICATION DOCUMENTS'),
                    _dossierCard(Icons.badge_outlined, 'STUDENT / STAFF ID', _userData?['passport_url'] ?? '', 'passport_url', isDark),
                    const SizedBox(height: 12),
                    _dossierCard(Icons.fingerprint_outlined, 'AADHAR CARD', _userData?['aadhar_url'] ?? '', 'aadhar_url', isDark),
                    const SizedBox(height: 12),
                    _dossierCard(Icons.medical_services_outlined, 'MEDICAL CERTIFICATE', _userData?['medical_certificate_url'] ?? '', 'medical_certificate_url', isDark),
                    const SizedBox(height: 28),
                    _buildSectionHeader('SECURITY TERMINAL'),
                    _buildSecuritySection(isDark),
                  ],
                  if (widget.isOnboarding) ...[
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text('SAVE & ENTER APP', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 15)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOnboardingBanner(bool isDark) {
    final roleLabel = {
      'hostel_student': 'Hostel Student',
      'mess_student': 'Mess Student',
      'staff': 'Staff Member',
      'store_customer': 'Store Customer',
      'farmer_seller': 'Mandi Farmer / Seller',
      'delivery_partner': 'Delivery Partner',
    }[_role] ?? 'Campus Member';
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.indigoAccent.withOpacity(0.15), Colors.purpleAccent.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.waving_hand_rounded, color: Colors.indigoAccent, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome aboard!', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text("Joining as $roleLabel. Fill your details to get started.", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Text(title, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
  );

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, bool isDark,
      {bool isNumeric = false, bool isPhone = false, bool readOnly = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: isNumeric ? TextInputType.number : isPhone ? TextInputType.phone : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 18),
          filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _doj ?? DateTime.now(),
          firstDate: DateTime(2010), lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigoAccent, brightness: isDark ? Brightness.dark : Brightness.light)),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _doj = picked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, color: Colors.indigoAccent, size: 18),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(_doj == null ? 'TAP TO SELECT DATE' : DateFormat('dd MMMM yyyy').format(_doj!),
                style: TextStyle(color: _doj == null ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const Spacer(),
          Icon(Icons.edit_calendar_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 16),
        ]),
      ),
    );
  }

  Widget _buildBloodGroupPicker(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BLOOD GROUP', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _bloodGroups.map((bg) {
          final sel = _bloodGroup == bg;
          return GestureDetector(
            onTap: () => setState(() => _bloodGroup = bg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? Colors.redAccent.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? Colors.redAccent : (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (sel) ...[const Icon(Icons.opacity_rounded, color: Colors.redAccent, size: 12), const SizedBox(width: 4)],
                Text(bg, style: TextStyle(color: sel ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black54), fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            ),
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildDropdownPicker(String label, IconData icon, List<String> items, String? value, void Function(String?) onChanged, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Row(children: [
        Icon(icon, color: Colors.indigoAccent, size: 18),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
          icon: Icon(Icons.unfold_more_rounded, color: Colors.indigoAccent, size: 18),
          isExpanded: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
          onChanged: onChanged,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        ))),
      ]),
    );
  }

  Widget _buildMandiTypePicker(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MANDI USER TYPE', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(children: _mandiUserTypes.map((t) {
          final sel = _mandiUserType == t;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _mandiUserType = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel ? Colors.indigoAccent.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Center(child: Text(t.toUpperCase(), style: TextStyle(color: sel ? Colors.indigoAccent : (isDark ? Colors.white54 : Colors.black45), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
            ),
          ));
        }).toList()),
      ]),
    );
  }

  Widget _buildSecuritySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(children: [
        TextField(controller: _passwordController, obscureText: _obscurePassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: _inputDeco('NEW SECURITY KEY', Icons.lock_outline_rounded, isDark)),
        const SizedBox(height: 16),
        TextField(controller: _confirmPasswordController, obscureText: _obscurePassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: _inputDeco('CONFIRM KEY', Icons.security_rounded, isDark)),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
          onPressed: _isPasswordLoading ? null : _updatePassword,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: _isPasswordLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('UPDATE PASSCODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
        )),
      ]),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, bool isDark) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontSize: 8, color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.w900, letterSpacing: 1),
    prefixIcon: Icon(icon, size: 18, color: Colors.indigoAccent),
    filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.01),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)),
  );

  Widget _buildPhotoUploader(bool isDark) {
    final String? url = _userData?['latest_photo_url'] as String? ?? _userData?['avatar_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Row(children: [
        CircleAvatar(radius: 32, backgroundColor: Colors.indigoAccent.withOpacity(0.1),
          backgroundImage: url != null && url.startsWith('http') ? NetworkImage(url) : null,
          child: url == null || !url.startsWith('http') ? const Icon(Icons.person_rounded, color: Colors.indigoAccent, size: 28) : null),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PROFILE PHOTO', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
          Text('Required for visual verification.', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
        ])),
        ElevatedButton(
          onPressed: _pickAndUploadPhoto,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          child: const Text('UPLOAD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _dossierCard(IconData icon, String title, String url, String field, bool isDark) {
    final bool hasFile = url.startsWith('http');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: Colors.indigoAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Icon(hasFile ? Icons.verified_rounded : Icons.pending_outlined, size: 14, color: hasFile ? Colors.greenAccent : Colors.orangeAccent),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _replaceDoc(field, title),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.cloud_upload_outlined, color: Colors.indigoAccent, size: 14), SizedBox(width: 8), Text('UPDATE DOCUMENT', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))])),
        ),
      ]),
    );
  }

  Future<void> _replaceDoc(String field, String title) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1920, maxHeight: 1920);
    if (file != null) {
      setState(() => _isLoading = true);
      try {
        final uploadedUrl = await StorageUploadService().uploadFile(file: File(file.path), preferredBucket: 'documents', pathPrefix: 'kyc_docs');
        await _client.from('profiles').update({field: uploadedUrl}).eq('id', _client.auth.currentUser!.id);
        _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title uploaded!'), backgroundColor: Colors.greenAccent));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
      } finally { if (mounted) setState(() => _isLoading = false); }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1200, maxHeight: 1200);
    if (file != null) {
      setState(() => _isLoading = true);
      try {
        final uploadedUrl = await StorageUploadService().uploadFile(file: File(file.path), preferredBucket: 'profiles', pathPrefix: 'avatars');
        await _client.from('profiles').update({'latest_photo_url': uploadedUrl}).eq('id', _client.auth.currentUser!.id);
        _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.greenAccent));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: Colors.redAccent));
      } finally { if (mounted) setState(() => _isLoading = false); }
    }
  }
}
