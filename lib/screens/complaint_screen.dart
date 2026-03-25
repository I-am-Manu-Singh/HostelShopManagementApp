import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Electrical';
  bool _isSubmitting = false;

  List<dynamic> _userComplaints = [];
  bool _isLoadingComplaints = true;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final res = await Supabase.instance.client
          .from('complaints')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _userComplaints = res;
          _isLoadingComplaints = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComplaints = false);
    }
  }

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Electrical', 'icon': Icons.flash_on_rounded, 'color': Colors.amberAccent},
    {'name': 'Plumbing', 'icon': Icons.water_drop_rounded, 'color': Colors.blueAccent},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services_rounded, 'color': Colors.tealAccent},
    {'name': 'Internet', 'icon': Icons.wifi_rounded, 'color': Colors.indigoAccent},
    {'name': 'Food', 'icon': Icons.restaurant_rounded, 'color': Colors.orangeAccent},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Colors.white38},
  ];

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final success = await DatabaseService().submitComplaint(_titleController.text, _descController.text, _selectedCategory);
    setState(() => _isSubmitting = false);
    if (success) {
      _titleController.clear();
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('REPORT SUBMITTED'), backgroundColor: Colors.greenAccent));
      _fetchComplaints();
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
        title: Text('SUPPORT CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlow(isDark),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(child: Text('GET HELP', style: GoogleFonts.outfit(color: textColor, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5))),
                  const SizedBox(height: 8),
                  Text('Staff support is available 24/7.', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13)),
                  const SizedBox(height: 40),
                  _buildSectionHeader('CHOOSE CATEGORY', isDark),
                  const SizedBox(height: 20),
                  _buildCategoryGrid(isDark),
                  const SizedBox(height: 32),
                  _buildSectionHeader('ISSUE DETAILS', isDark),
                  const SizedBox(height: 20),
                  _buildTextField(_titleController, 'SUMMARY', Icons.title_rounded, isDark),
                  const SizedBox(height: 20),
                  _buildTextField(_descController, 'DESCRIPTION', Icons.description_rounded, isDark, maxLines: 5),
                  const SizedBox(height: 40),
                  _buildSubmitButton(isDark),
                  const SizedBox(height: 40),
                  _buildSectionHeader('ACTIVE REQUESTS', isDark),
                  const SizedBox(height: 20),
                  _buildRecentTicketsList(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(top: -100, left: -100, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(title, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5));
  }

  Widget _buildCategoryGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1),
      itemCount: _categories.length,
      itemBuilder: (context, i) {
        final c = _categories[i];
        final selected = _selectedCategory == c['name'];
        final iconColor = isDark ? Colors.white24 : Colors.black26;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = c['name']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(color: selected ? c['color'].withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)), borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? c['color'].withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(c['icon'] as IconData, color: selected ? c['color'] as Color : iconColor, size: 28),
              const SizedBox(height: 8),
              Text(c['name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: selected ? (isDark ? Colors.white : Colors.black) : iconColor, fontSize: 9, fontWeight: FontWeight.w900)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark, {int maxLines = 1}) {
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.white24 : Colors.black26;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: hintColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: textColor, fontSize: 14),
          validator: (val) => val == null || val.isEmpty ? 'REQUIRED' : null,
          decoration: InputDecoration(prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 20), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)), contentPadding: const EdgeInsets.all(20)),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Colors.redAccent, Color(0xFFFB7185)]), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, minimumSize: const Size(double.infinity, 65), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text('SUBMIT REQUEST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
      ),
    );
  }

  Widget _buildRecentTicketsList(bool isDark) {
    if (_isLoadingComplaints) return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    if (_userComplaints.isEmpty) return Center(child: Text('NO ACTIVE REQUESTS', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        children: List.generate(_userComplaints.length, (i) {
          final c = _userComplaints[i];
          final title = c['title']?.toString().toUpperCase() ?? 'UNTITLED';
          final status = c['status']?.toString().toUpperCase() ?? 'PENDING';
          final color = status == 'RESOLVED' ? Colors.greenAccent : (status == 'PENDING' ? Colors.orangeAccent : Colors.redAccent);
          
          return Column(
            children: [
              _ticketItem(title, status, color, isDark),
              if (i != _userComplaints.length - 1) Divider(height: 32, color: isDark ? Colors.white10 : Colors.black12),
            ],
          );
        }),
      ),
    );
  }

  Widget _ticketItem(String title, String status, Color c, bool isDark) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
        Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 8)),
      ],
    );
  }
}
