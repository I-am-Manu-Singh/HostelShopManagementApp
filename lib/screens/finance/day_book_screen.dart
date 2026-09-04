import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DayBookScreen extends StatefulWidget {
  const DayBookScreen({super.key});

  @override
  State<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends State<DayBookScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _entries = [];
  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    setState(() => _isLoading = true);
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      // 1. Fetch manual entries
      final manualRes = await _client.from('day_book_entries').select('*, profiles(*)').eq('transaction_date', dateStr).order('created_at', ascending: false);
      
      // 2. Fetch Automated Streams (Collections for that day)
      // Actually, for a pure "Day Book", usually we'd want everything.
      
      if (mounted) {
        setState(() {
          _entries = manualRes;
          _totalIncome = 0;
          _totalExpense = 0;
          for (var e in manualRes) {
             if (e['entry_type'] == 'Income') _totalIncome += (e['amount'] as num).toDouble();
             else _totalExpense += (e['amount'] as num).toDouble();
          }
          _isLoading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        title: Text('CAMPUS DAY BOOK', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add_box_rounded, color: Colors.indigoAccent), onPressed: _showEntryDialog),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                   _buildDateSelector(),
                   const SizedBox(height: 24),
                   _buildDailySummary(),
                   const SizedBox(height: 32),
                   _sectionHeader('DAILY TRANSACTION LOGS'),
                   const SizedBox(height: 16),
                   if (_entries.isEmpty) 
                      _emptyState()
                   else
                      ..._entries.map((e) => _buildEntryTile(e)).toList(),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
             const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 20),
             const SizedBox(width: 16),
             Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate).toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
          ]),
          IconButton(icon: const Icon(Icons.tune_rounded, color: Colors.white38, size: 20), onPressed: _pickDate),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
     return Row(children: [
       _summaryBox('DAILY INCOME', '₹${_totalIncome.toInt()}', Colors.greenAccent),
       const SizedBox(width: 16),
       _summaryBox('DAILY EXPENSE', '₹${_totalExpense.toInt()}', Colors.redAccent),
     ]);
  }

  Widget _summaryBox(String l, String v, Color c) => Expanded(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8), Text(v, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 24))])));

  Widget _buildEntryTile(dynamic e) {
     bool isIncome = e['entry_type'] == 'Income';
     return FadeInRight(
       child: Container(
         margin: const EdgeInsets.only(bottom: 12),
         padding: const EdgeInsets.all(20),
         decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(children: [
               Icon(isIncome ? Icons.arrow_outward_rounded : Icons.south_west_rounded, color: isIncome ? Colors.greenAccent : Colors.redAccent, size: 20),
               const SizedBox(width: 16),
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['category'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(e['payment_method'] ?? 'CASH', style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
               ])),
               Text('${isIncome ? "+" : "-"}₹${(e['amount'] as num).toInt()}', style: GoogleFonts.outfit(color: isIncome ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 18)),
             ]),
             if (e['remark'] != null && e['remark'].isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Text('\"${e['remark']}\"', style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
             ],
           ],
         ),
       ),
     );
  }

  void _showEntryDialog() {
    final amtCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    String typeSelection = 'Expense';
    String methodSelection = 'Cash';
    String categorySelection = 'Maintenance';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: AlertDialog(
        backgroundColor: const Color(0xFF08090A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text('INGEST TRANSACTION', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _modalSegment(['Income', 'Expense'], typeSelection, (v) => setModalState(() => typeSelection = v)),
            const SizedBox(height: 16),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'AMOUNT (₹)')),
            TextField(controller: remarkCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'REMARK (OPTIONAL)')),
            const SizedBox(height: 16),
            _modalSegment(['Cash', 'UPI', 'Wallet'], methodSelection, (v) => setModalState(() => methodSelection = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => _submitEntry(amtCtrl.text, typeSelection, methodSelection, categorySelection, remarkCtrl.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: const Text('AUTHORIZE ENTRY')),
        ],
      )),
    ));
  }

  Widget _modalSegment(List<String> options, String selected, Function(String) onSel) {
     return Row(children: options.map((o) {
        bool sel = selected == o;
        return Expanded(child: GestureDetector(onTap: () => onSel(o), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: sel ? Colors.indigoAccent : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(o.toUpperCase(), style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 8, fontWeight: FontWeight.w900))))));
     }).toList());
  }

  Future<void> _submitEntry(String amt, String type, String method, String cat, String rem) async {
     try {
       await _client.from('day_book_entries').insert({
         'entry_type': type,
         'amount': double.parse(amt),
         'payment_method': method,
         'category': cat,
         'remark': rem,
         'user_id': _client.auth.currentUser!.id,
         'transaction_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
       });
       Navigator.pop(context);
       _loadDailyData();
     } catch (_) {}
  }

  void _pickDate() async {
     final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now());
     if (picked != null) { setState(() => _selectedDate = picked); _loadDailyData(); }
  }

  Widget _sectionHeader(String label) => Text(label, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  Widget _emptyState() => Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)), child: const Center(child: Text('NO TRANSACTIONS LOGGED FOR THIS PERIOD', style: TextStyle(color: Colors.white10, fontSize: 10, fontWeight: FontWeight.bold))));
  Widget _buildRefractionOrbs() => Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), shape: BoxShape.circle))));
}
