import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/storage_upload_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  bool _isPasswordLoading = false;
  Map<String, dynamic>? _userData;
  
  // 🧬 LEGACY FIELDS
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _oldPhoneCtrl = TextEditingController(); // Standardizing this with student_phone
  final _bloodGroupCtrl = TextEditingController();
  final _medicalInfoCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();

  // 🧬 NEW IDENTITY FIELDS
  final _phoneNoCtrl = TextEditingController(); 
  final _fNameCtrl = TextEditingController();
  final _fPhoneCtrl = TextEditingController();
  final _fWACtrl = TextEditingController();
  final _mNameCtrl = TextEditingController();
  final _mPhoneCtrl = TextEditingController();
  final _mWACtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _instituteCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();
  final _schoolCityCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController();
  final _meterReadingCtrl = TextEditingController();
  DateTime? _doj;

  // Mandi controllers
  final _mandiAddressCtrl = TextEditingController();
  final _mandiLocationCtrl = TextEditingController();
  String _mandiUserType = 'domestic';

  // 🧬 SECURITY
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (res != null) {
        // CORE
        _nameCtrl.text = res['full_name'] ?? '';
        _emailCtrl.text = user.email ?? '';
        
        // LEGACY MAPPING
        _bloodGroupCtrl.text = res['blood_group'] ?? '';
        _medicalInfoCtrl.text = res['medical_info'] ?? '';
        _emergencyContactCtrl.text = res['emergency_contact_no'] ?? res['emergency_contact'] ?? '';
        
        // NEW MAPPING
        _phoneNoCtrl.text = res['phone_no'] ?? '';
        _fNameCtrl.text = res['father_name'] ?? '';
        _fPhoneCtrl.text = res['father_phone'] ?? '';
        _fWACtrl.text = res['father_whatsapp'] ?? '';
        _mNameCtrl.text = res['mother_name'] ?? '';
        _mPhoneCtrl.text = res['mother_phone'] ?? '';
        _mWACtrl.text = res['mother_whatsapp'] ?? '';
        _addressCtrl.text = res['home_address'] ?? '';
        _cityCtrl.text = res['city'] ?? '';
        _stateCtrl.text = res['state'] ?? '';
        _instituteCtrl.text = res['institute'] ?? '';
        _rollNoCtrl.text = res['institute_roll_no'] ?? '';
        _schoolCityCtrl.text = res['school_city'] ?? '';
        _sessionCtrl.text = res['session_year'] ?? '';
        _meterReadingCtrl.text = (res['meter_reading'] ?? 0).toString();
        
        if (res['date_of_joining'] != null) _doj = DateTime.parse(res['date_of_joining']);
        
        // Mandi data mapping
        _mandiAddressCtrl.text = res['delivery_address'] ?? '';
        _mandiLocationCtrl.text = res['delivery_location'] ?? '';
        _mandiUserType = res['user_type'] ?? 'domestic';
      }
      if (mounted) setState(() { _userData = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      await _client.from('profiles').update({
        'full_name': _nameCtrl.text,
        'phone_no': _phoneNoCtrl.text, // STANDARDIZED CORE FIELD
        'blood_group': _bloodGroupCtrl.text,
        'medical_info': _medicalInfoCtrl.text,
        'emergency_contact_no': _emergencyContactCtrl.text,
        'father_name': _fNameCtrl.text,
        'father_phone': _fPhoneCtrl.text,
        'father_whatsapp': _fWACtrl.text,
        'mother_name': _mNameCtrl.text,
        'mother_phone': _mPhoneCtrl.text,
        'mother_whatsapp': _mWACtrl.text,
        'home_address': _addressCtrl.text,
        'city': _cityCtrl.text,
        'state': _stateCtrl.text,
        'institute': _instituteCtrl.text,
        'institute_roll_no': _rollNoCtrl.text,
        'school_city': _schoolCityCtrl.text,
        'session_year': _sessionCtrl.text,
        'meter_reading': double.tryParse(_meterReadingCtrl.text) ?? 0,
        'date_of_joining': _doj?.toIso8601String(),
        'delivery_address': _mandiAddressCtrl.text,
        'delivery_location': _mandiLocationCtrl.text,
        'user_type': _mandiUserType,
      }).eq('id', user!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DYNAMIC PROFILE SYNCHRONIZED'), backgroundColor: Colors.indigoAccent));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.redAccent));
    } finally { setState(() => _isLoading = false); }
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
    } finally { setState(() => _isPasswordLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
      appBar: AppBar(
        title: Text('PROFILE EVOLUTION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(onPressed: _isLoading ? null : _saveProfile, child: Text('SAVE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, letterSpacing: 1))),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('CORE IDENTITY'),
                _buildField(_nameCtrl, 'FULL NAME', Icons.person_outline_rounded, isDark),
                _buildField(_phoneNoCtrl, 'CONTACT NUMBER', Icons.phone_android_rounded, isDark),
                _buildField(_emailCtrl, 'EMAIL ADDRESS (UNEDITABLE)', Icons.alternate_email_rounded, isDark, readOnly: true),
                
                const SizedBox(height: 32),
                _buildSectionHeader('PATERNAL INFRASTRUCTURE'),
                _buildField(_fNameCtrl, 'FATHER\'S NAME', Icons.badge_outlined, isDark),
                _buildField(_fPhoneCtrl, 'FATHER\'S PHONE', Icons.phone_enabled_rounded, isDark),
                _buildField(_fWACtrl, 'FATHER\'S WHATSAPP', Icons.chat_bubble_outline_rounded, isDark),
                
                const SizedBox(height: 32),
                _buildSectionHeader('MATERNAL INFRASTRUCTURE'),
                _buildField(_mNameCtrl, 'MOTHER\'S NAME', Icons.badge_outlined, isDark),
                _buildField(_mPhoneCtrl, 'MOTHER\'S PHONE', Icons.phone_enabled_rounded, isDark),
                _buildField(_mWACtrl, 'MOTHER\'S WHATSAPP', Icons.chat_bubble_outline_rounded, isDark),
                
                const SizedBox(height: 32),
                _buildSectionHeader('RESIDENTIAL & INSTITUTIONAL'),
                _buildField(_addressCtrl, 'HOME ADDRESS', Icons.home_work_outlined, isDark),
                Row(children: [
                  Expanded(child: _buildField(_cityCtrl, 'CITY', Icons.location_city_rounded, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_stateCtrl, 'STATE', Icons.map_rounded, isDark)),
                ]),
                _buildField(_instituteCtrl, 'INSTITUTE NAME', Icons.school_outlined, isDark),
                _buildField(_rollNoCtrl, 'ROLL NO.', Icons.numbers_rounded, isDark),
                _buildField(_schoolCityCtrl, 'INSTITUTE CITY', Icons.apartment_rounded, isDark),
                _buildField(_sessionCtrl, 'SESSION (20XX-XX)', Icons.history_edu_rounded, isDark),
                
                const SizedBox(height: 32),
                _buildSectionHeader('HEALTH & SAFETY (RESTORED LEGACY)'),
                _buildField(_bloodGroupCtrl, 'BLOOD GROUP', Icons.opacity_rounded, isDark),
                _buildField(_medicalInfoCtrl, 'MEDICAL INFO / ALLERGIES', Icons.health_and_safety_outlined, isDark),
                _buildField(_emergencyContactCtrl, 'PRIMARY EMERGENCY PHONE', Icons.emergency_outlined, isDark),
                
                const SizedBox(height: 32),
                _buildSectionHeader('CAMPUS LOGISTICS'),
                _buildDatePicker('DATE OF JOINING', isDark),
                _buildField(_meterReadingCtrl, 'METER READING', Icons.speed_rounded, isDark, isNumeric: true),
                
                const SizedBox(height: 32),
                _buildSectionHeader('MANDI MART PREFERENCES'),
                _buildField(_mandiAddressCtrl, 'MANDI DELIVERY ADDRESS', Icons.home_rounded, isDark),
                _buildField(_mandiLocationCtrl, 'DELIVERY LOCATION / NEIGHBORHOOD', Icons.pin_drop_rounded, isDark),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _mandiUserType = 'domestic'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _mandiUserType == 'domestic' ? Colors.indigoAccent.withOpacity(0.1) : Colors.transparent,
                            side: BorderSide(color: _mandiUserType == 'domestic' ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12)),
                          ),
                          child: Text('DOMESTIC USER', style: TextStyle(color: _mandiUserType == 'domestic' ? Colors.indigoAccent : (isDark ? Colors.white70 : Colors.black54), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _mandiUserType = 'commercial'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _mandiUserType == 'commercial' ? Colors.indigoAccent.withOpacity(0.1) : Colors.transparent,
                            side: BorderSide(color: _mandiUserType == 'commercial' ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12)),
                          ),
                          child: Text('COMMERCIAL USER', style: TextStyle(color: _mandiUserType == 'commercial' ? Colors.indigoAccent : (isDark ? Colors.white70 : Colors.black54), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                _buildSectionHeader('VISUAL & DOCUMENT ASSETS'),
                _buildPhotoUploader(isDark),
                const SizedBox(height: 16),
                _dossierCard(Icons.badge_outlined, 'STUDENT ID PROOF', _userData?['passport_url'] ?? 'No document uploaded', 'passport_url', isDark),
                const SizedBox(height: 12),
                _dossierCard(Icons.fingerprint_outlined, 'AADHAR CARD', _userData?['aadhar_url'] ?? 'No document uploaded', 'aadhar_url', isDark),
                const SizedBox(height: 12),
                _dossierCard(Icons.medical_services_outlined, 'MEDICAL CERTIFICATE', _userData?['medical_certificate_url'] ?? 'No document uploaded', 'medical_certificate_url', isDark),
                
                const SizedBox(height: 32),
                _buildSectionHeader('SECURITY TERMINAL'),
                _buildSecuritySection(isDark),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(title, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isNumeric = false, bool readOnly = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl, readOnly: readOnly,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
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
        final picked = await showDatePicker(context: context, initialDate: _doj ?? DateTime.now(), firstDate: DateTime(2010), lastDate: DateTime.now());
        if (picked != null) setState(() => _doj = picked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, color: Colors.indigoAccent, size: 18),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(_doj == null ? 'SELECT DATE' : DateFormat('MMM dd, yyyy').format(_doj!), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSecuritySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(
        children: [
          TextField(controller: _passwordController, obscureText: _obscurePassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: _inputDeco('NEW SECURITY KEY', Icons.lock_outline_rounded, isDark)),
          const SizedBox(height: 16),
          TextField(controller: _confirmPasswordController, obscureText: _obscurePassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: _inputDeco('CONFIRM KEY', Icons.security_rounded, isDark)),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: _updatePassword, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isPasswordLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('UPDATE PASSCODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)))),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label, labelStyle: TextStyle(fontSize: 8, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1),
      prefixIcon: Icon(icon, size: 18, color: Colors.indigoAccent),
      filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.01),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)),
    );
  }

  Widget _buildPhotoUploader(bool isDark) {
    String? url = _userData?['latest_photo_url'] ?? _userData?['avatar_url'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Row(children: [
        CircleAvatar(radius: 30, backgroundColor: Colors.indigoAccent.withOpacity(0.1), backgroundImage: url != null && url.startsWith('http') ? NetworkImage(url) : null, child: url == null || !url.startsWith('http') ? const Icon(Icons.person_rounded, color: Colors.indigoAccent) : null),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LATEST PHOTO', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
          Text('Required for visual verification.', style: TextStyle(color: Colors.grey, fontSize: 10)),
        ])),
        ElevatedButton(onPressed: _pickAndUploadPhoto, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('UPLOAD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _dossierCard(IconData icon, String title, String url, String field, bool isDark) {
    bool hasFile = url.startsWith('http');
    return Container(
      padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: (isDark?Colors.white:Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark?Colors.white:Colors.black).withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: Colors.indigoAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Icon(hasFile ? Icons.verified_rounded : Icons.pending_outlined, size: 14, color: hasFile ? Colors.greenAccent : Colors.orangeAccent),
        ]),
        const SizedBox(height: 12),
        GestureDetector(onTap: () => _replaceDoc(field, title), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.cloud_upload_outlined, color: Colors.indigoAccent, size: 14), SizedBox(width: 8), Text('UPDATE DOCUMENT', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))]))),
      ]),
    );
  }

  Future<void> _replaceDoc(String field, String title) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file != null) {
      setState(() => _isLoading = true);
      try {
        final uploadedUrl = await StorageUploadService().uploadFile(
          file: File(file.path),
          preferredBucket: 'documents',
          pathPrefix: 'kyc_docs',
        );
        await _client.from('profiles').update({field: uploadedUrl}).eq('id', _client.auth.currentUser!.id);
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title uploaded successfully!'), backgroundColor: Colors.greenAccent));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload $title: $e'), backgroundColor: Colors.redAccent));
        }
      } finally { setState(() => _isLoading = false); }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (file != null) {
       setState(() => _isLoading = true);
       try {
         final uploadedUrl = await StorageUploadService().uploadFile(
           file: File(file.path),
           preferredBucket: 'profiles',
           pathPrefix: 'avatars',
         );
         await _client.from('profiles').update({'latest_photo_url': uploadedUrl}).eq('id', _client.auth.currentUser!.id);
         _fetchData();
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.greenAccent));
         }
       } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: Colors.redAccent));
         }
       } finally { setState(() => _isLoading = false); }
    }
  }
}
