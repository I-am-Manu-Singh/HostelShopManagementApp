import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class EditUnitScreen extends StatefulWidget {
  final Map<String, dynamic>? room;
  const EditUnitScreen({super.key, this.room});

  @override
  State<EditUnitScreen> createState() => _EditUnitScreenState();
}

class _EditUnitScreenState extends State<EditUnitScreen> {
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool get isNew => widget.room == null;

  late TextEditingController _nameCtrl;
  late TextEditingController _blockCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _depositCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _imgCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.room?['room_number'] ?? '');
    _blockCtrl = TextEditingController(text: widget.room?['block_name'] ?? '');
    _capacityCtrl = TextEditingController(text: (widget.room?['capacity'] ?? '2').toString());
    _priceCtrl = TextEditingController(text: (widget.room?['base_price'] ?? '5000').toString());
    _depositCtrl = TextEditingController(text: '2000');
    _descCtrl = TextEditingController(text: widget.room?['description'] ?? '');
    _imgCtrl = TextEditingController(text: widget.room?['image_url'] ?? '');
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'room_number': _nameCtrl.text.trim(),
        'block_name': _blockCtrl.text.trim(),
        'capacity': int.tryParse(_capacityCtrl.text) ?? 2,
        'base_price': double.tryParse(_priceCtrl.text) ?? 5000,
        'description': _descCtrl.text.trim(),
        'image_url': _imgCtrl.text.trim(),
        'status': 'available',
      };

      if (isNew) {
        await _client.from('hostel_rooms').insert(data);
      } else {
        await _client.from('hostel_rooms').update(data).eq('id', widget.room!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isNew ? 'UNIT DEPLOYED SUCCESSFULLY' : 'UNIT CONFIGURATION UPDATED'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TERMINAL ERROR: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(isNew ? 'LAUNCH NEW UNIT' : 'UNIT CONFIGURATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigoAccent))
          else IconButton(icon: const Icon(Icons.rocket_launch_rounded, color: Colors.indigoAccent), onPressed: _saveUnit),
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundGlow(),
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader('CORE UNIT INTEL'),
                _buildInput('ROOM NUMBER / ID', _nameCtrl, Icons.room_rounded),
                _buildInput('BLOCK / SECTOR', _blockCtrl, Icons.business_rounded),
                Row(children: [
                  Expanded(child: _buildInput('SLOT CAPACITY', _capacityCtrl, Icons.group_rounded, type: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('PRICE (INR)', _priceCtrl, Icons.payments_rounded, type: TextInputType.number)),
                ]),
                _buildInput('IMAGE URL', _imgCtrl, Icons.image_rounded),
                const SizedBox(height: 32),
                _buildSectionHeader('SPECIFICATIONS'),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
                  child: TextField(controller: _descCtrl, maxLines: 6, style: const TextStyle(color: Colors.white70, fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter unit specifications (Amenities, view, etc.)', hintStyle: TextStyle(color: Colors.white10))),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(bottom: -100, left: -100, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 16, top: 24), child: Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)));
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {TextInputType type = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(icon: Icon(icon, color: Colors.indigoAccent, size: 18), labelText: label, labelStyle: const TextStyle(color: Colors.white24, fontSize: 11), border: InputBorder.none),
      ),
    );
  }
}
