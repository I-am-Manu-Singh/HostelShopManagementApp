import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentStoreRequestScreen extends StatefulWidget {
  const StudentStoreRequestScreen({super.key});

  @override
  State<StudentStoreRequestScreen> createState() => _StudentStoreRequestScreenState();
}

class _StudentStoreRequestScreenState extends State<StudentStoreRequestScreen> {
  final _itemController = TextEditingController();
  final _descController = TextEditingController();
  String _priority = 'Standard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('SPECIAL PROCUREMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildRefractionOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader('REQUEST EXTERNAL ITEM'),
                const SizedBox(height: 12),
                const Text('Items not available in the campus shop can be requested for external procurement.', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                _buildInput('ITEM_IDENTIFIER', 'What do you need?', _itemController, Icons.shopping_bag_rounded),
                const SizedBox(height: 20),
                _buildPrioritySelector(),
                const SizedBox(height: 20),
                _buildLargeInput('SPECIFICATIONS / QUANTITY', 'Details...', _descController),
                const SizedBox(height: 48),
                _buildSubmitButton(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildHeader(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2));
  }

  Widget _buildInput(String label, String hint, TextEditingController c, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: TextField(controller: c, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(icon: Icon(icon, color: Colors.indigoAccent, size: 18), hintText: hint, hintStyle: const TextStyle(color: Colors.white12), border: InputBorder.none)),
      ),
    ]);
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: ['Standard', 'Urgent', 'Emergency'].map((p) {
         bool isSel = _priority == p;
         return Expanded(
           child: GestureDetector(
             onTap: () => setState(() => _priority = p),
             child: Container(
               margin: const EdgeInsets.symmetric(horizontal: 4),
               padding: const EdgeInsets.symmetric(vertical: 12),
               decoration: BoxDecoration(color: isSel ? Colors.indigoAccent : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
               alignment: Alignment.center,
               child: Text(p.toUpperCase(), style: TextStyle(color: isSel ? Colors.black : Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
             ),
           ),
         );
      }).toList(),
    );
  }

  Widget _buildLargeInput(String label, String hint, TextEditingController c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: TextField(controller: c, maxLines: 6, style: const TextStyle(color: Colors.white70, fontSize: 14), decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(color: Colors.white10))),
      ),
    ]);
  }

  bool _isSubmitting = false;

  Future<void> _submitRequest() async {
    final item = _itemController.text.trim();
    final desc = _descController.text.trim();
    if (item.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('procurements').insert({
        'requester_id': user.id,
        'item_name': item,
        'description': desc,
        'priority': _priority,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PROCUREMENT TICKET GENERATED. STAFF NOTIFIED.'), backgroundColor: Colors.indigoAccent));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TRANSMISSION ERROR: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _buildSubmitButton() {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity, height: 60,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRequest,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          child: _isSubmitting 
            ? const CircularProgressIndicator(color: Colors.black)
            : Text('TRANSMIT REQUEST', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        ),
      ),
    );
  }
}
