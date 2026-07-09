import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class AddBlogScreen extends StatefulWidget {
  const AddBlogScreen({super.key});

  @override
  State<AddBlogScreen> createState() => _AddBlogScreenState();
}

class _AddBlogScreenState extends State<AddBlogScreen> {
  final _client = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _readTimeCtrl = TextEditingController(text: '5 min');
  final _contentCtrl = TextEditingController();
  final List<String> _imageUrls = [];
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  bool _isSaving = false;

  final List<String> _suggestedTags = ['Event', 'Complaint', 'Review', 'Dining', 'Safety', 'Lost & Found', 'Sports', 'Academic'];

  Future<void> _saveBlog() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final user = _client.auth.currentUser;

    if (title.isEmpty || content.isEmpty || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PLEASE ENSURE TITLE AND CONTENT ARE POPULATED.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _client.from('blogs').insert({
        'author_id': user.id,
        'title': title,
        'content': content,
        'image_url': _coverCtrl.text.trim(),
        'read_time': _readTimeCtrl.text.trim(),
        'gallery': _imageUrls.where((u) => u.isNotEmpty).toList(),
        'tags': _tags,
        'category': _tags.isNotEmpty ? _tags.first : 'Trekking',
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STORY BROADCASTED TO CAMPUS FEED.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DATABASE ERROR: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAMPUS BROADCAST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF08090A),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PUBLISH A POST', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 8),
              Text('Share updates with the hostel community.', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
              const SizedBox(height: 32),
              _iconicInput(Icons.text_fields_outlined, _titleCtrl, label: 'Dispatch Title'),
              const SizedBox(height: 16),
              _iconicInput(Icons.image_outlined, _coverCtrl, label: 'Asset URI (Cover Image)'),
              const SizedBox(height: 16),
              _iconicInput(Icons.timer_outlined, _readTimeCtrl, label: 'Read Duration'),
              const SizedBox(height: 32),
              Text('TAGS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigoAccent.withOpacity(0.3))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tag.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _tags.remove(tag)),
                          child: const Icon(Icons.close, color: Colors.white24, size: 14),
                        ),
                      ],
                    ),
                  )),
                  GestureDetector(
                    onTap: _showTagPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: const Icon(Icons.add, color: Colors.white24, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('DETAILS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              _largeInput(_contentCtrl),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 65,
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Colors.indigoAccent, Color(0xFF6366F1)]), boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveBlog,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('PUBLISH', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(color: Color(0xFF16181A), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TAGS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _suggestedTags.map((tag) => ChoiceChip(
                label: Text(tag.toUpperCase(), style: GoogleFonts.outfit(color: _tags.contains(tag) ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                selected: _tags.contains(tag),
                selectedColor: Colors.indigoAccent,
                backgroundColor: Colors.white.withOpacity(0.05),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (!_tags.contains(tag)) _tags.add(tag);
                      } else {
                        _tags.remove(tag);
                      }
                    });
                  },
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            Text('CUSTOM TAG', style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Custom field tag...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(15)),
                  child: IconButton(
                    onPressed: () {
                      final customTag = _tagCtrl.text.trim();
                      if (customTag.isNotEmpty && !_tags.contains(customTag)) {
                        setState(() {
                          _tags.add(customTag);
                          _tagCtrl.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconicInput(IconData icon, TextEditingController ctrl, {String? label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.indigoAccent),
              const SizedBox(width: 16),
              Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(border: InputBorder.none), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _removableUrl(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade50)),
      child: Row(
        children: [
          Expanded(child: TextField(
            onChanged: (val) => _imageUrls[index] = val,
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Asset URL...'),
            style: const TextStyle(fontSize: 14),
          )),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _imageUrls.removeAt(index))),
        ],
      ),
    );
  }

  Widget _largeInput(TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TextField(controller: ctrl, maxLines: 20, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Compose your intel narrative...'), style: GoogleFonts.outfit(fontSize: 14, color: Colors.white, height: 1.6)),
    );
  }

  Widget _addLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2E7B32), size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF2E7B32), fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
