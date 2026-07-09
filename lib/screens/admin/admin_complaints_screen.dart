import "dart:ui";
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../services/database_service.dart';
import '../../models/hostel.dart';
import 'package:intl/intl.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  List<Complaint> _complaints = [];
  String _filterStatus = 'All';
  String _searchQuery = '';
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    final list = await _db.fetchAllComplaints();
    if (mounted) {
      setState(() {
        _complaints = list.map((json) => Complaint.fromJson(json)).toList();
        _isLoading = false;
      });
    }
  }

  void _updateStatus(String id, String status) async {
    await _db.updateComplaintStatus(id, status);
    _fetchComplaints();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    final filtered = _complaints.where((c) {
      bool statusMatches = (_filterStatus == 'All') || (_filterStatus == 'Active' ? c.status != 'Resolved' : c.status == _filterStatus);
      bool searchMatches = (c.userName ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) || c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      bool dateMatches = _filterDate == null || (c.createdAt.year == _filterDate!.year && c.createdAt.month == _filterDate!.month && c.createdAt.day == _filterDate!.day);
      return statusMatches && searchMatches && dateMatches;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('CONTROL_SUPPORT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black, letterSpacing: 2.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.calendar_month_rounded, color: _filterDate!=null?Colors.indigoAccent: (isDark?Colors.white24:Colors.black26), size: 18), onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime.now());
            if (d!=null) setState(() => _filterDate = d);
          }),
          if (_filterDate != null) IconButton(icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18), onPressed: () => setState(() => _filterDate = null)),
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundGlow(isDark),
          Column(
            children: [
              _buildAnalyticsHeader(isDark),
              _buildSearchHeader(isDark),
              _buildStatusFilter(isDark),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                  : filtered.isEmpty 
                    ? _emptyState(isDark)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                          if (crossCount > 1) {
                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return FadeInUp(
                                  delay: Duration(milliseconds: 50 * index),
                                  child: _buildComplaintCard(filtered[index], cardColor, borderColor, isDark),
                                );
                              },
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return FadeInUp(
                                delay: Duration(milliseconds: 50 * index),
                                child: _buildComplaintCard(filtered[index], cardColor, borderColor, isDark),
                              );
                            },
                          );
                        }
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(top: -100, right: -100, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildAnalyticsHeader(bool isDark) {
    int active = _complaints.where((c) => c.status != 'Resolved').length;
    int resolved = _complaints.where((c) => c.status == 'Resolved').length;
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statMini('PENDING', '$active', Colors.redAccent, isDark),
          _statMini('YIELD', '$resolved', Colors.greenAccent, isDark),
          _statMini('TOTAL', '${_complaints.length}', isDark ? Colors.white : Colors.black, isDark),
        ],
      ),
    );
  }

  Widget _statMini(String label, String val, Color c, bool isDark) {
    return Column(children: [Text(val, style: GoogleFonts.outfit(color: c, fontSize: 24, fontWeight: FontWeight.bold)), Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))]);
  }

  Widget _buildStatusFilter(bool isDark) {
    final statuses = ['Active', 'Pending', 'In-Progress', 'Resolved', 'All'];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final s = statuses[index];
          final isSelected = _filterStatus == s;
          return GestureDetector(
            onTap: () => setState(() => _filterStatus = s),
            child: Container(
              margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(s, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white38 : Colors.black45), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: 'FILTER_BY_STUDENT...', hintStyle: TextStyle(color: isDark?Colors.white10:Colors.black12, fontWeight: FontWeight.bold), prefixIcon: const Icon(Icons.manage_search_rounded, color: Colors.indigoAccent, size: 20), filled: true, fillColor: isDark?Colors.white.withOpacity(0.04):Colors.black.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildComplaintCard(Complaint c, Color cardColor, Color borderColor, bool isDark) {
    final statusColor = _getStatusColor(c.status);
    final responseCtrl = TextEditingController(text: c.adminResponse);
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.02), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(c.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    Text(DateFormat('MMM dd, HH:mm').format(c.createdAt), style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(c.title.toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(c.description, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 12, backgroundColor: Colors.indigoAccent.withOpacity(0.1), child: Text((c.userName ?? 'A')[0].toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Text(c.userName ?? 'ANONYMOUS_UNIT', style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _categoryChip(c.category ?? 'GEN'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('OFFICIAL RESPONSE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 12),
                TextField(
                  controller: responseCtrl,
                  maxLines: 3,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Transmit response protocol...',
                    hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                           await _db.updateComplaintResponse(c.id, responseCtrl.text);
                           _fetchComplaints();
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response Synchronized')));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), minimumSize: const Size(0, 50)),
                        child: const Text('SYNC RESPONSE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (c.status != 'Resolved')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateStatus(c.id, 'Resolved'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), minimumSize: const Size(0, 50)),
                        child: const Text('RESOLVE CASE', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String cat) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(cat.toUpperCase(), style: const TextStyle(color: Colors.pinkAccent, fontSize: 8, fontWeight: FontWeight.w900)));
  }

  Widget _emptyState(bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 60, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)), const SizedBox(height: 16), Text('ALL CLEAR. NO PENDING CASES.', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))]));
  }

  Color _getStatusColor(String s) {
    if (s == 'Resolved') return Colors.greenAccent;
    if (s == 'In-Progress') return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
