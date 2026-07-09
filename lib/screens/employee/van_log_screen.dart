import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class VanLogScreen extends StatefulWidget {
  const VanLogScreen({super.key});

  @override
  State<VanLogScreen> createState() => _VanLogScreenState();
}

class _VanLogScreenState extends State<VanLogScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _vans = [];
  String? _selectedVanId;
  double _lastMeter = 0;
  
  final _todayMeterCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  String? _receiptUrl;

  @override
  void initState() {
    super.initState();
    _fetchVans();
  }

  Future<void> _fetchVans() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('vans').select().eq('is_active', true);
      if (mounted) {
        setState(() {
          _vans = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLastMeter(String vanId) async {
    try {
      final res = await _client.from('van_logs').select('latest_meter').eq('van_id', vanId).order('created_at', ascending: false).limit(1).maybeSingle();
      if (mounted) {
        setState(() {
          _lastMeter = (res?['latest_meter'] as num?)?.toDouble() ?? 0;
          _selectedVanId = vanId;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('FLEET LOGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : Stack(
            children: [
              _buildBackgroundOrbs(),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _vanSelector(isDark),
                  if (_selectedVanId != null) ...[
                    const SizedBox(height: 32),
                    _meterAuditSection(isDark),
                    const SizedBox(height: 24),
                    _fuelAuditSection(isDark),
                    const SizedBox(height: 24),
                    _receiptCaptureSection(isDark),
                    const SizedBox(height: 40),
                    _submitAuditButton(),
                  ],
                ],
              ),
            ],
          ),
    );
  }

  Widget _vanSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVanId,
          hint: Text('SELECT VEHICLE', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, fontSize: 11)),
          dropdownColor: isDark ? const Color(0xFF08090A) : Colors.white,
          isExpanded: true,
          items: _vans.map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['van_number'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)))).toList(),
          onChanged: (val) { if (val != null) _fetchLastMeter(val); },
        ),
      ),
    );
  }

  Widget _meterAuditSection(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       _header('METER READING'),
       const SizedBox(height: 16),
       Row(children: [
         Expanded(child: _infoBox('PREVIOUS', _lastMeter.toStringAsFixed(1), isDark)),
         const SizedBox(width: 16),
         Expanded(child: _inputBox('TODAY', _todayMeterCtrl, isDark)),
       ]),
    ]);
  }

  Widget _fuelAuditSection(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       _header('FUEL & LOGS'),
       const SizedBox(height: 16),
       Row(children: [
         Expanded(child: _inputBox('LITERS', _litersCtrl, isDark, icon: Icons.local_gas_station_outlined)),
         const SizedBox(width: 16),
         Expanded(child: _inputBox('AMOUNT', _amountCtrl, isDark, icon: Icons.payments_outlined)),
       ]),
       const SizedBox(height: 16),
       _paymentSegment(isDark),
    ]);
  }

  Widget _paymentSegment(bool isDark) {
    return Row(children: [
       _segmentBtn('Cash', isDark),
       const SizedBox(width: 12),
       _segmentBtn('Card', isDark),
       const SizedBox(width: 12),
       _segmentBtn('Wallet', isDark),
    ]);
  }

  Widget _segmentBtn(String type, bool isDark) {
    bool sel = _paymentMethod == type;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _paymentMethod = type), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? Colors.greenAccent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)), borderRadius: BorderRadius.circular(15), border: Border.all(color: sel ? Colors.greenAccent.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12))), child: Center(child: Text(type.toUpperCase(), style: TextStyle(color: sel ? Colors.black : (isDark ? Colors.white60 : Colors.black54), fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5))))));
  }

  Widget _receiptCaptureSection(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       _header('RECEIPT'),
       const SizedBox(height: 16),
       GestureDetector(
         onTap: _pickReceipt,
         child: Container(
           height: 120, width: double.infinity,
           decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))),
           child: _receiptUrl == null 
             ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_outlined, color: Colors.indigoAccent), SizedBox(height: 8), Text('UPLOAD RECEIPT', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900))])
             : ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(_receiptUrl!, fit: BoxFit.cover)),
         ),
       ),
    ]);
  }

  Widget _submitAuditButton() {
     return ElevatedButton(
       onPressed: _submitLog,
       style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 20)),
       child: const Text('SUBMIT LOG', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
     );
  }

  // Helpers
  Widget _header(String l) => Text(l, style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  Widget _infoBox(String l, String v, bool isDark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8), Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 20))]));
  Widget _inputBox(String l, TextEditingController ctrl, bool isDark, {IconData? icon}) => Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: TextField(controller: ctrl, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16), decoration: InputDecoration(border: InputBorder.none, labelText: l, labelStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900), prefixIcon: icon != null ? Icon(icon, color: Colors.indigoAccent, size: 16) : null)));
  Widget _buildBackgroundOrbs() => Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.05), shape: BoxShape.circle))));

  void _pickReceipt() async {
     final picker = ImagePicker();
     final img = await picker.pickImage(source: ImageSource.gallery);
     if (img != null) {
        setState(() => _receiptUrl = 'https://hostel-mgmt.up.railway.app/fleet/receipts/${img.name}'); // Mocked
     }
  }

  Future<void> _submitLog() async {
    try {
      if (_todayMeterCtrl.text.isEmpty || _litersCtrl.text.isEmpty || _amountCtrl.text.isEmpty) return;
      await _client.from('van_logs').insert({
        'van_id': _selectedVanId,
        'user_id': _client.auth.currentUser!.id,
        'previous_meter': _lastMeter,
        'latest_meter': double.parse(_todayMeterCtrl.text),
        'fuel_liters': double.parse(_litersCtrl.text),
        'amount_paid': double.parse(_amountCtrl.text),
        'payment_method': _paymentMethod,
        'receipt_url': _receiptUrl,
      });
      Navigator.pop(context);
    } catch (_) {}
  }
}
