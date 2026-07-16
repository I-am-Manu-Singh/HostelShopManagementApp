import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

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

  // ── CSV Export ─────────────────────────────────────────────────────────────

  Future<void> _exportBroadcastsToCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Global Announcements',
      isImport: false,
    );
    if (range == null) return;

    try {
      final buffer = StringBuffer();
      final headers = ['ID', 'Title', 'Content', 'Urgent', 'Date'];
      buffer.writeln(headers.join(','));

      final filtered = _broadcasts.where((b) {
        if (b['created_at'] != null) {
          final dt = DateTime.tryParse(b['created_at'].toString());
          if (dt != null) {
            return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
          }
        }
        return true;
      }).toList();

      for (var b in filtered) {
        final List<String> row = [
          b['id']?.toString() ?? '',
          '"${(b['title'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          '"${(b['content'] ?? 'N/A').toString().replaceAll('"', '""')}"',
          (b['is_urgent'] ?? false).toString(),
          b['created_at']?.toString() ?? '',
        ];
        buffer.writeln(row.join(','));
      }

      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = 'announcements_$dateLabel.csv';

      if (kIsWeb) {
        downloadCsvFile(buffer.toString(), filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(buffer.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Announcements CSV');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importBroadcastsFromCSV() async {
    final range = await showCsvRangeDialog(
      context: context,
      title: 'Global Announcements',
      isImport: true,
    );
    if (range == null) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null) return;

      List<String> lines;
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes == null) return;
        lines = utf8.decode(bytes).split('\n');
      } else {
        if (result.files.single.path == null) return;
        lines = await File(result.files.single.path!).readAsLines();
      }

      if (lines.length < 2) return;

      int successCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cells = line.split(',');
        if (cells.length < 3) continue;

        final title = cells[1].replaceAll('"', '').trim();
        final content = cells[2].replaceAll('"', '').trim();

        if (title.isNotEmpty) {
          await _client.from('global_announcements').insert({
            'title': title,
            'content': content,
            'is_urgent': false,
          });
          successCount++;
        }
      }

      _loadBroadcasts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $successCount announcements successfully.'), backgroundColor: Colors.greenAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
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
              Row(
                children: [
                  _choiceChip('ALL', target == 'ALL', isDark, () => setModalState(() => target = 'ALL')),
                  const SizedBox(width: 8),
                  _choiceChip('STUDENTS', target == 'STUDENTS', isDark, () => setModalState(() => target = 'STUDENTS')),
                  const SizedBox(width: 8),
                  _choiceChip('STAFF', target == 'STAFF', isDark, () => setModalState(() => target = 'STAFF')),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('HIGH PRIORITY / CRITICAL', style: GoogleFonts.outfit(color: isDark ? Colors.white30 : Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Switch.adaptive(
                    value: isUrgent,
                    activeColor: Colors.pinkAccent,
                    onChanged: (val) => setModalState(() => isUrgent = val),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) return;
                    final data = {
                      'title': titleCtrl.text,
                      'content': contentCtrl.text,
                      'is_urgent': isUrgent,
                      'target_audience': target,
                    };
                    if (isEdit) {
                      await _client.from('global_announcements').update(data).eq('id', existing['id']);
                    } else {
                      await _client.from('global_announcements').insert(data);
                    }
                    Navigator.pop(ctx);
                    _loadBroadcasts();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text(isEdit ? 'UPDATE ANNOUNCEMENT' : 'SEND BROADCAST', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String l, bool active, bool isDark, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(l, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: active ? Colors.white : (isDark ? Colors.white24 : Colors.black26))),
      selected: active,
      selectedColor: Colors.indigoAccent,
      backgroundColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
      onSelected: (_) => onTap(),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, int lines, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: TextField(
        controller: ctrl,
        maxLines: lines,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26), border: InputBorder.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF08090A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final filtered = _broadcasts.where((b) {
      if (_targetFilter == 'ALL') return true;
      return (b['target_audience'] ?? 'ALL') == _targetFilter;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('BROADCASTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_rounded, color: Colors.blueAccent), onPressed: _importBroadcastsFromCSV, tooltip: 'Import CSV'),
          IconButton(icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent), onPressed: _exportBroadcastsToCSV, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent, size: 24), onPressed: () => _showCreateModal(isDark)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : Stack(
              children: [
                Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle)))),
                Column(
                  children: [
                    _buildAudienceFilters(isDark),
                    Expanded(
                      child: filtered.isEmpty
                          ? _emptyState(isDark)
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) => _broadcastCard(filtered[idx], isDark),
                            ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildAudienceFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          _audienceChip('ALL', isDark),
          const SizedBox(width: 8),
          _audienceChip('STUDENTS', isDark),
          const SizedBox(width: 8),
          _audienceChip('STAFF', isDark),
        ],
      ),
    );
  }

  Widget _audienceChip(String label, bool isDark) {
    final active = _targetFilter == label;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: active ? Colors.white : (isDark ? Colors.white30 : Colors.black45))),
      selected: active,
      selectedColor: Colors.indigoAccent,
      backgroundColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
      onSelected: (sel) {
        if (sel) setState(() => _targetFilter = label);
      },
    );
  }

  Widget _broadcastCard(dynamic b, bool isDark) {
    final title = b['title'] ?? 'Announcement';
    final content = b['content'] ?? '';
    final bool urgent = b['is_urgent'] ?? false;
    final String timeStr = b['created_at'] != null
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(b['created_at']))
        : 'Recently';

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: urgent ? Colors.pinkAccent.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.black12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title.toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))),
                if (urgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Text('CRITICAL', style: TextStyle(color: Colors.pinkAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.4)),
            const Divider(height: 32, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeStr.toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(icon: Icon(Icons.edit_rounded, color: isDark ? Colors.white30 : Colors.black38, size: 16), onPressed: () => _showCreateModal(isDark, existing: b)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                      onPressed: () async {
                        await _client.from('global_announcements').delete().eq('id', b['id']);
                        _loadBroadcasts();
                      },
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: isDark ? Colors.white10 : Colors.black12),
            const SizedBox(height: 12),
            Text('NO ACTIVE ANNOUNCEMENTS', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
