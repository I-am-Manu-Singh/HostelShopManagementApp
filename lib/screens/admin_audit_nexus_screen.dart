import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminAuditNexusScreen extends StatefulWidget {
  const AdminAuditNexusScreen({super.key});

  @override
  State<AdminAuditNexusScreen> createState() => _AdminAuditNexusScreenState();
}

class _AdminAuditNexusScreenState extends State<AdminAuditNexusScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  
  Map<String, dynamic>? _totalBill;
  double _collectedAmt = 0;
  List<dynamic> _ghostUnits = [];

  @override
  void initState() {
    super.initState();
    _loadAuditData();
  }

  Future<void> _loadAuditData() async {
    setState(() => _isLoading = true);
    String monthStr = DateFormat('yyyy-MM-01').format(_selectedMonth);
    try {
      final billRes = await _client.from('hostel_utility_bills').select().eq('month_period', monthStr).maybeSingle();
      
      final collectionsRes = await _client.from('fiscal_collections').select('amount').eq('collection_type', 'Electricity Bill').gte('created_at', monthStr);
      _collectedAmt = (collectionsRes as List).fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());

      final activeEnrollments = await _client.from('hostel_enrollments').select('room_id').eq('status', 'Active');
      Set<String> activeRoomIds = (activeEnrollments as List).map((e) => e['room_id'].toString()).toSet();
      
      final ghostRes = await _client.from('meter_readings').select('*, hostel_rooms(*)').eq('month_period', monthStr);
      _ghostUnits = (ghostRes as List).where((r) => !activeRoomIds.contains(r['room_id'].toString()) && (r['units_consumed'] as num) > 0).toList();

      if (mounted) {
        setState(() {
          _totalBill = billRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    double billAmt = (_totalBill?['total_bill_amount'] ?? 0).toDouble();
    double collectedAmt = _collectedAmt;
    double loss = billAmt - collectedAmt;
    double lossPercent = billAmt > 0 ? (loss / billAmt) * 100 : 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ELECTRICITY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.add_chart_rounded, color: Colors.indigoAccent), onPressed: () => _showBillInput(isDark)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildBackgroundOrbs(),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildPeriodSelector(isDark),
                  const SizedBox(height: 24),
                  _buildComparisonNexus(billAmt, collectedAmt, lossPercent, isDark),
                  const SizedBox(height: 32),
                  _buildSectionHeader('UNOCCUPIED USAGE'),
                  const SizedBox(height: 16),
                  if (_ghostUnits.isEmpty) 
                     _emptyState('NO UNUSUAL USAGE DETECTED', isDark)
                  else
                     ..._ghostUnits.map((g) => _buildGhostTile(g, isDark)).toList(),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 16),
            Text(DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase(), style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
          ]),
          IconButton(icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20), onPressed: _pickMonth),
        ],
      ),
    );
  }

  Widget _buildComparisonNexus(double bill, double collected, double percent, bool isDark) {
    return Column(children: [
      Row(children: [
        _nexusBox('BILLED', '₹${bill.toInt()}', isDark ? Colors.white38 : Colors.black45, isDark),
        const SizedBox(width: 16),
        _nexusBox('COLLECTED', '₹${collected.toInt()}', Colors.greenAccent, isDark),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: (percent > 10 ? Colors.redAccent : Colors.indigoAccent).withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: (percent > 10 ? Colors.redAccent : Colors.indigoAccent).withOpacity(0.2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text('LOSS', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
             Text('₹${(bill - collected).toInt()}', style: GoogleFonts.outfit(color: percent > 10 ? Colors.redAccent : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.w900, fontSize: 32)),
          ]),
          _circularProgress(percent / 100, percent.toInt().toString(), isDark),
        ]),
      ),
    ]);
  }

  Widget _buildGhostTile(dynamic g, bool isDark) {
     final room = g['hostel_rooms'];
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.redAccent.withOpacity(0.1))),
       child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text('ROOM ${room['room_number']} (VACANT)', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
             Text('Usage: ${g['units_consumed']} units', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
          ])),
          Text('₹${(g['units_consumed'] * 12).toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
       ]),
     );
  }

  Widget _circularProgress(double val, String label, bool isDark) => SizedBox(height: 60, width: 60, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: val, strokeWidth: 8, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), color: val > 0.1 ? Colors.redAccent : Colors.greenAccent), Text('$label%', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.w900))]));
  
  Widget _nexusBox(String l, String v, Color c, bool isDark) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8), Text(v, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 18))])));
  
  Widget _buildSectionHeader(String label) => Text(label, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  
  Widget _emptyState(String msg, bool isDark) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.greenAccent.withOpacity(0.05))), child: Center(child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold))));
  
  Widget _buildBackgroundOrbs() => Positioned(bottom: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), shape: BoxShape.circle))));

  void _showBillInput(bool isDark) {
    final amtCtrl = TextEditingController();
    final unitsCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: AlertDialog(backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), title: Text('UPDATE TOTAL BILL', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.w900)), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'AMOUNT')), TextField(controller: unitsCtrl, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: 'TOTAL UNITS'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), ElevatedButton(onPressed: () => _submitBill(amtCtrl.text, unitsCtrl.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: const Text('UPDATE'))])));
  }

  Future<void> _submitBill(String amt, String units) async {
    try {
      await _client.from('hostel_utility_bills').upsert({
        'month_period': DateFormat('yyyy-MM-01').format(_selectedMonth),
        'total_bill_amount': double.parse(amt),
        'total_units_consumed': double.parse(units),
      }, onConflict: 'month_period');
      Navigator.pop(context);
      _loadAuditData();
    } catch (_) {}
  }

  void _pickMonth() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedMonth, firstDate: DateTime(2023), lastDate: DateTime(2030), initialDatePickerMode: DatePickerMode.year);
    if (picked != null) { setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1)); _loadAuditData(); }
  }
}
