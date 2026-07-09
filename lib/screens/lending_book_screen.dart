import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LendingBookScreen extends StatefulWidget {
  const LendingBookScreen({super.key});

  @override
  State<LendingBookScreen> createState() => _LendingBookScreenState();
}

class _LendingBookScreenState extends State<LendingBookScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _records = [];
  double _totalLent = 0;
  double _totalReturned = 0;
  double _netPosition = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('lending_book').select().eq('user_id', user.id).order('created_at', ascending: false);
      
      // Calculate net dues
      double lent = 0;
      double ret = 0;
      for (var r in res) {
        double amt = (r['amount'] as num).toDouble();
        if (r['type'] == 'return') {
          ret += amt;
        } else {
          lent += amt;
        }
      }

      if (mounted) {
        setState(() {
          _records = res;
          _totalLent = lent;
          _totalReturned = ret;
          _netPosition = lent - ret;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Grouped debtors
  Map<String, List<dynamic>> _getGroupedRecords() {
    Map<String, List<dynamic>> grouped = {};
    for (var r in _records) {
      final key = r['debtor_phone'] ?? r['debtor_name'] ?? 'OTHER';
      if (grouped[key] == null) grouped[key] = [];
      grouped[key]!.add(r);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final grouped = _getGroupedRecords();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('ADMIN KHATA', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
        : Stack(
            children: [
              _buildRefractionOrb(isDark),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildStatsHeader(isDark),
                  const SizedBox(height: 32),
                  _buildSectionHeader('DEBTOR PROFILES'),
                  const SizedBox(height: 16),
                  if (grouped.isEmpty) 
                    _buildEmptyState(isDark)
                  else
                    ...grouped.entries.map((e) => _debtorCard(e.key, e.value, isDark)).toList(),
                  const SizedBox(height: 100),
                ],
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntryModal(context, isDark),
        backgroundColor: Colors.amberAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('LOG LENDING', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
      ),
    );
  }

  Widget _debtorCard(String key, List<dynamic> history, bool isDark) {
    double net = 0;
    for (var h in history) {
      double amt = (h['amount'] as num).toDouble();
      if (h['type'] == 'return') net -= amt; else net += amt;
    }

    final String name = history.isNotEmpty ? history[0]['debtor_name'] : 'UNKNOWN';

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.04), borderRadius: BorderRadius.circular(28), border: Border.all(color: net > 0 ? Colors.amberAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2))),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: const EdgeInsets.all(20),
          leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (net > 0 ? Colors.amberAccent : Colors.greenAccent).withOpacity(0.1), shape: BoxShape.circle), child: Icon(net > 0 ? Icons.outbox_rounded : Icons.check_circle_outline_rounded, color: net > 0 ? Colors.amberAccent : Colors.greenAccent, size: 20)),
          title: Text(name.toUpperCase(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(key, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
          trailing: Text('₹${net.toInt()}', style: GoogleFonts.outfit(color: net > 0 ? Colors.amberAccent : Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 18)),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.02), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(
                children: [
                   ...history.map((h) => Padding(
                     padding: const EdgeInsets.only(bottom: 12),
                     child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(h['created_at'])), style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9)),
                          Text(h['type'] == 'return' ? 'DEBIT (RETURNED)' : 'CREDIT (LENT)', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text('${h['type'] == 'return' ? '-' : '+'}₹${(h['amount'] as num).toInt()}', style: TextStyle(color: h['type'] == 'return' ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                     ),
                   )).toList(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _modalInput(String label, TextEditingController ctrl, bool isDark, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, letterSpacing: 1),
        prefixIcon: Icon(icon, color: Colors.amberAccent, size: 18),
        filled: true,
        fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.amberAccent)),
      ),
    );
  }

  String _entryType = 'lent';

Widget _typeBtn(
  String l,
  String v,
  Color c,
  Function(String) onTap,
  bool isDark,
) {
  bool sel = _entryType == v;

  return Expanded(
    child: GestureDetector(
      onTap: () => onTap(v),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel
              ? c
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            l,
            style: TextStyle(
              color: sel
                  ? Colors.black
                  : (isDark ? Colors.white24 : Colors.black26),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStatsHeader(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amberAccent.withOpacity(0.2), Colors.amberAccent.withOpacity(0.05)]), borderRadius: BorderRadius.circular(35), border: Border.all(color: Colors.amberAccent.withOpacity(0.1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LIQUIDITY OUTSTANDING', style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text('₹${_netPosition.toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Active Dues in Circulation', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _miniAnalytic('LENT', '₹${_totalLent.toInt()}', Colors.amberAccent, isDark),
            const SizedBox(width: 12),
            _miniAnalytic('RETURNED', '₹${_totalReturned.toInt()}', Colors.greenAccent, isDark),
            const SizedBox(width: 12),
            _miniAnalytic('DEBTORS', '${_getGroupedRecords().length}', Colors.indigoAccent, isDark),
          ],
        ),
      ],
    );
  }

  Widget _miniAnalytic(String l, String v, Color c, bool isDark) {
    return Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 4), Text(v, style: GoogleFonts.outfit(color: c, fontSize: 16, fontWeight: FontWeight.w900))])));
  }

  Widget _buildSectionHeader(String title) => Row(children: [Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 2)), const Spacer(), Container(height: 1, width: 40, color: Colors.amberAccent.withOpacity(0.1))]);

  Widget _buildEmptyState(bool isDark) => Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [Icon(Icons.collections_bookmark_outlined, size: 48, color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 16), Text('LEDGER CLEAR', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))])));

  Widget _buildRefractionOrb(bool isDark) => Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), shape: BoxShape.circle))));

  void _addEntryModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LOG TRANSACTION', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 24),
              StatefulBuilder(builder: (c, setST) => Row(children: [
               _typeBtn('LENT', 'lent', Colors.amberAccent, (v) {
  setST(() => _entryType = v);
}, isDark),

_typeBtn('RETURNED', 'return', Colors.greenAccent, (v) {
  setST(() => _entryType = v);
}, isDark),
              ])),
              const SizedBox(height: 32),
              _modalInput('DEBTOR NAME', _nameCtrl, isDark, Icons.person_outline),
              const SizedBox(height: 16),
              _modalInput('DEBTOR PHONE', _phoneCtrl, isDark, Icons.phone_outlined, isNumeric: true),
              const SizedBox(height: 16),
              _modalInput('AMOUNT (₹)', _amtCtrl, isDark, Icons.payments_outlined, isNumeric: true),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _submitEntry(_entryType),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('AUTHORIZE COMMIT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEntry(String type) async {
    final amt = double.tryParse(_amtCtrl.text);
    if (amt == null || amt <= 0 || _nameCtrl.text.isEmpty) return;

    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('lending_book').insert({
        'user_id': user.id,
        'debtor_name': _nameCtrl.text,
        'debtor_phone': _phoneCtrl.text,
        'amount': amt,
        'type': type,
        'status': 'pending',
      });

      _nameCtrl.clear();
      _phoneCtrl.clear();
      _amtCtrl.clear();
      Navigator.pop(context);
      _fetchRecords();
    } catch (_) {}
  }
}
