import "dart:ui";
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _broadcasts = [];
  String _targetFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _broadcasts = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateModal(bool isDark, {Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title']);
    final contentCtrl = TextEditingController(text: existing?['content']);
    bool isUrgent = existing?['is_urgent'] ?? false;
    String target = existing?['target_audience'] ?? 'ALL';
    final bool isEdit = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(36))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'EDIT ANNOUNCEMENT' : 'NEW ANNOUNCEMENT', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
              const SizedBox(height: 24),
              _modalInput(titleCtrl, 'Headline...', 1, isDark),
              const SizedBox(height: 16),
              _modalInput(contentCtrl, 'Announcement details...', 4, isDark),
              const SizedBox(height: 24),
              Text('TARGET AUDIENCE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ['ALL', 'HOSTEL', 'MESS', 'STAFF'].map((t) {
                 bool isSel = target == t;
                 return ChoiceChip(
                   label: Text(t, style: TextStyle(color: isSel ? Colors.white : (isDark ? Colors.white24 : Colors.black38), fontSize: 10, fontWeight: FontWeight.bold)),
                   selected: isSel,
                   onSelected: (v) => setModalState(() => target = t),
                   selectedColor: Colors.indigoAccent,
                   backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                 );
              }).toList()),
              const SizedBox(height: 20),
              SwitchListTile(
                title: Text('MARK AS URGENT', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text('Broadcast with alert markers', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10)),
                value: isUrgent,
                activeColor: Colors.redAccent,
                onChanged: (v) => setModalState(() => isUrgent = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) return;
                    final data = {
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'is_urgent': isUrgent,
                      'target_audience': target,
                      'sender_name': 'ADMIN',
                    };
                    if (isEdit) {
                      await _client.from('global_announcements').update(data).eq('id', existing['id']);
                    } else {
                      data['created_at'] = DateTime.now().toIso8601String();
                      await _client.from('global_announcements').insert(data);
                    }
                    if (mounted) Navigator.pop(ctx);
                    _loadBroadcasts();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: isUrgent ? Colors.redAccent : Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(isEdit ? 'UPDATE ANNOUNCEMENT' : 'SEND ANNOUNCEMENT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, int lines, bool isDark) {
    return TextField(
      controller: ctrl, maxLines: lines, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('COMMAND BROADCAST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildBackgroundGlow(),
              Column(
                children: [
                  _buildAnalyticsBar(isDark),
                  _buildTargetFilter(isDark),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      itemCount: _filteredBroadcasts().length,
                      itemBuilder: (context, index) {
                        final b = _filteredBroadcasts()[index];
                        return _buildBroadcastItem(b, isDark, () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
                              title: const Text('DELETE INTEL?'),
                              content: const Text('This action will redact the broadcast from all user terminals.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _client.from('global_announcements').delete().eq('id', b['id']);
                            _loadBroadcasts();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateModal(isDark), backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
        label: Text('NEW INTEL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(bottom: -50, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.04), shape: BoxShape.circle))));
  }

  List<dynamic> _filteredBroadcasts() {
    if (_targetFilter == 'ALL') return _broadcasts;
    return _broadcasts.where((b) => b['target_audience'] == _targetFilter || b['target_audience'] == 'ALL').toList();
  }

  Widget _buildAnalyticsBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statMini('TOTAL', _broadcasts.length.toString(), isDark ? Colors.white : Colors.black, isDark),
          _statMini('URGENT', _broadcasts.where((b) => b['is_urgent'] == true).length.toString(), Colors.redAccent, isDark),
        ],
      ),
    );
  }

  Widget _statMini(String label, String val, Color c, bool isDark) {
    return Column(children: [Text(val, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 20)), Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1))]);
  }

  Widget _buildTargetFilter(bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.only(top: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['ALL', 'HOSTEL', 'MESS', 'STAFF'].map((t) {
          bool isSel = _targetFilter == t;
          return GestureDetector(
            onTap: () => setState(() => _targetFilter = t),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: isSel ? Colors.indigoAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))),
              alignment: Alignment.center,
              child: Text(t, style: TextStyle(color: isSel ? Colors.indigoAccent : (isDark ? Colors.white24 : Colors.black38), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBroadcastItem(dynamic b, bool isDark, VoidCallback onDelete) {
    final bool isUrgent = b['is_urgent'] ?? false;
    // Format timestamp
    String date = 'Just now';
    try {
      if (b['created_at'] != null) {
        date = DateFormat('MMM dd, HH:mm').format(DateTime.parse(b['created_at']));
      }
    } catch (_) {}

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUrgent 
              ? Colors.redAccent.withOpacity(0.2) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUrgent 
                  ? Colors.redAccent.withOpacity(0.05) 
                  : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isUrgent ? Icons.warning_amber_rounded : Icons.cell_tower_rounded,
                        color: isUrgent ? Colors.redAccent : Colors.indigoAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        b['target_audience']?.toString().toUpperCase() ?? 'ALL',
                        style: TextStyle(
                          color: isUrgent ? Colors.redAccent : Colors.indigoAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showCreateModal(isDark, existing: b),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: isDark ? Colors.white30 : Colors.black26,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: isDark ? Colors.white30 : Colors.black26,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b['title'] ?? 'NO SUBJECT',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    b['content'] ?? '',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    date,
                    style: TextStyle(
                      color: isDark ? Colors.white12 : Colors.black12,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
