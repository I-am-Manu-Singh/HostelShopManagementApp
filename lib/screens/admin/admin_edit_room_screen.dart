import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../../models/hostel.dart';

class AdminEditRoomScreen extends StatefulWidget {
  final HostelRoom room;
  const AdminEditRoomScreen({super.key, required this.room});

  @override
  State<AdminEditRoomScreen> createState() => _AdminEditRoomScreenState();
}

class _AdminEditRoomScreenState extends State<AdminEditRoomScreen> {
  final _client = Supabase.instance.client;
  late TextEditingController _numberCtrl;
  late TextEditingController _blockCtrl;
  late TextEditingController _floorCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _imageCtrl;
  String _selectedType = 'Standard';
  bool _isSaving = false;

  final List<String> _roomTypes = ['Standard', 'Premium', 'Elite', 'Ensuite', 'Dormitory'];

  @override
  void initState() {
    super.initState();
    _numberCtrl = TextEditingController(text: widget.room.roomNumber);
    _blockCtrl = TextEditingController(text: widget.room.buildingName);
    _floorCtrl = TextEditingController(text: widget.room.floor.toString());
    _priceCtrl = TextEditingController(text: widget.room.basePrice.toString());
    _capacityCtrl = TextEditingController(text: widget.room.capacity.toString());
    _imageCtrl = TextEditingController(text: widget.room.imageUrl);
    _selectedType = widget.room.roomType ?? 'Standard';
    if (!_roomTypes.contains(_selectedType)) {
      _roomTypes.add(_selectedType);
    }
  }

  Future<void> _saveRoom() async {
    setState(() => _isSaving = true);
    try {
      await _client.from('hostel_rooms').update({
        'room_number': _numberCtrl.text,
        'building_name': _blockCtrl.text,
        'floor': int.tryParse(_floorCtrl.text) ?? 0,
        'base_price': double.tryParse(_priceCtrl.text) ?? 6500,
        'capacity': int.tryParse(_capacityCtrl.text) ?? 2,
        'room_type': _selectedType,
        'image_url': _imageCtrl.text.trim(),
      }).eq('id', widget.room.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STRUCTURAL UNIT UPDATED'), backgroundColor: Colors.indigoAccent));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPLOYMENT ERROR: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('EDIT STRUCTURAL UNIT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.check_rounded, color: Colors.indigoAccent), onPressed: _isSaving ? null : _saveRoom),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(32)),
                child: Column(
                  children: [
                    _buildInput('ROOM NUMBER', _numberCtrl, isDark),
                    const SizedBox(height: 16),
                    _buildInput('BUILDING / BLOCK', _blockCtrl, isDark),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildInput('LEVEL (FLOOR)', _floorCtrl, isDark, numerical: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInput('CAPACITY', _capacityCtrl, isDark, numerical: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(32)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ARCHETYPE & COST_LOG', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 16),
                    DropdownButton<String>(
                      value: _selectedType, isExpanded: true,
                      style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                      items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                    const SizedBox(height: 16),
                    _buildInput('BASE MONTHLY PRICE (₹)', _priceCtrl, isDark, numerical: true),
                    const SizedBox(height: 16),
                    _buildInput('IMAGE URL', _imageCtrl, isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveRoom,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('CONFIRM STRUCTURAL UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, bool isDark, {bool numerical = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.indigoAccent, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: numerical ? TextInputType.number : null,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
