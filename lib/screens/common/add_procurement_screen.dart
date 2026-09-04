import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class AddProcurementScreen extends StatefulWidget {
  const AddProcurementScreen({super.key});

  @override
  State<AddProcurementScreen> createState() => _AddProcurementScreenState();
}

class _AddProcurementScreenState extends State<AddProcurementScreen> {
  final _client = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'Medium';
  bool _isLoading = false;

  Future<void> _submitRequest() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('procurements').insert({
        'item_name': _nameCtrl.text,
        'description': _descCtrl.text,
        'priority': _priority, // 'Low', 'Medium', 'High', 'Urgent'
        'requester_id': user.id,
        'status': 'Requested'
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('NEW PURCHASE REQUEST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _modalField(_nameCtrl, 'ITEM_NAME', isDark),
             const SizedBox(height: 16),
             _modalField(_descCtrl, 'DESCRIPTION_DETAILS', isDark, lines: 4),
             const SizedBox(height: 32),
             Text('PRIORITY_LEVEL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
             const SizedBox(height: 12),
             _priorityPicker(_priority, (v) => setState(() => _priority = v), isDark),
             const SizedBox(height: 60),
             SizedBox(width: double.infinity, height: 65, child: ElevatedButton(onPressed: _isLoading ? null : _submitRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('INITIALIZE_REQUEST', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)))),
          ],
        ),
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String hint, bool isDark, {int lines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 14, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
    );
  }

  Widget _priorityPicker(String selected, Function(String) onSelect, bool isDark) {
    final ps = ['Low', 'Medium', 'High', 'Urgent'];
    return Row(children: ps.map((p) => Expanded(child: GestureDetector(onTap: () => onSelect(p), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: selected == p ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(p.toUpperCase(), style: TextStyle(color: selected == p ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 8, fontWeight: FontWeight.w900))))))).toList());
  }
}
