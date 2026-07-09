import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminFeePackageScreen extends StatefulWidget {
  const AdminFeePackageScreen({super.key});

  @override
  State<AdminFeePackageScreen> createState() => _AdminFeePackageScreenState();
}

class _AdminFeePackageScreenState extends State<AdminFeePackageScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _fees = [];

  @override
  void initState() {
    super.initState();
    _fetchFees();
  }

  Future<void> _fetchFees() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('fee_structure').select().order('category', ascending: true);
      if (mounted) setState(() { _fees = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    final grouped = <String, List<dynamic>>{};
    for (var f in _fees) {
       final cat = f['category'] ?? 'MISC';
       if (!grouped.containsKey(cat)) grouped[cat] = [];
       grouped[cat]!.add(f);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('FEE PACKAGES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent), onPressed: () => _showAddFeeModal(isDark)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : _fees.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.inventory_2_outlined, color: isDark ? Colors.white10 : Colors.black12, size: 80),
                   const SizedBox(height: 20),
                   Text('NO ACTIVE PLANS', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 2)),
                   Text('CLICK + TO ESTABLISH HQ RATES', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 10)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchFees,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                children: grouped.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     _buildSectionHeader('${entry.key.toUpperCase()} PLANS', isDark),
                     const SizedBox(height: 16),
                     ...entry.value.map((fee) => _buildFeeCard(fee, isDark)).toList(),
                     const SizedBox(height: 32),
                  ],
                )).toList(),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2));
  }

  Widget _buildFeeCard(dynamic fee, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(_getIcon(fee['category']), color: Colors.indigoAccent, size: 20)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fee['service_name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(fee['description'] ?? 'Standard rates applicable.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
             Text('₹${fee['price']}', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
             Row(children: [
               IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.indigoAccent, size: 20), onPressed: () => _showAddFeeModal(isDark, existing: fee)),
               IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _deleteFee(fee['id'])),
             ]),
          ]),
        ],
      ),
    );
  }

  Future<void> _deleteFee(String id) async {
    await _client.from('fee_structure').delete().eq('id', id);
    _fetchFees();
  }

  void _showAddFeeModal(bool isDark, {dynamic existing}) {
    final nameCtrl = TextEditingController(text: existing?['service_name']);
    final priceCtrl = TextEditingController(text: existing?['price']?.toString());
    String cat = existing?['category'] ?? 'Hostel';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(builder: (c, setModalState) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(c).viewInsets.bottom + 32),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'ADD NEW PLAN' : 'EDIT PLAN', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 24),
            TextField(controller: nameCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(hintText: 'Plan Name...', filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(hintText: 'Price...', filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Hostel', 'Van', 'Mess', 'Power'].map((t) => GestureDetector(
                onTap: () => setModalState(() => cat = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: cat == t ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(12)),
                  child: Text(t, style: TextStyle(color: cat == t ? Colors.white : (isDark ? Colors.white38 : Colors.black38), fontWeight: FontWeight.bold, fontSize: 9)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () async {
               if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
               final data = {
                 'service_name': nameCtrl.text,
                 'price': double.tryParse(priceCtrl.text) ?? 0.0,
                 'category': cat,
                 'unit': 'Month',
               };
               try {
                 if (existing == null) {
                   await _client.from('fee_structure').insert(data);
                 } else {
                   await _client.from('fee_structure').update(data).eq('id', existing['id']);
                 }
                 if (mounted) {
                   Navigator.pop(c);
                   _fetchFees();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PLAN SYNCED WITH HQ.'), backgroundColor: Colors.green));
                 }
               } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('FAILED TO SYNC PLAN: $e'), backgroundColor: Colors.redAccent));
               }
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text(existing == null ? 'SAVE PLAN' : 'UPDATE PLAN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      )),
    );
  }

  IconData _getIcon(String? cat) {
    switch (cat?.toUpperCase()) {
      case 'HOSTEL': return Icons.apartment_rounded;
      case 'VAN': return Icons.directions_bus_rounded;
      case 'MESS': return Icons.restaurant_rounded;
      default: return Icons.settings_rounded;
    }
  }
}
