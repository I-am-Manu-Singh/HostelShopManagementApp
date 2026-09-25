import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'debtor_profile_detail_screen.dart';

class LendingBookScreen extends StatefulWidget {
  const LendingBookScreen({super.key});

  @override
  State<LendingBookScreen> createState() => _LendingBookScreenState();
}

class _LendingBookScreenState extends State<LendingBookScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _records = [];
  List<dynamic> _dbUsers = [];
  
  // Analytics
  double _totalLent = 0;
  double _totalReturned = 0;
  double _netPosition = 0;
  double _todayLent = 0;
  double _weekLent = 0;
  double _monthLent = 0;
  Map<String, double> _debtorTotals = {};
  String? _topDebtorName;
  double _topDebtorAmount = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  XFile? _selectedImage;
  String? _selectedDbUserId;
  bool _deductFromWallet = true;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
    _fetchDbUsers();
  }

  Future<void> _fetchDbUsers() async {
    try {
      final res = await _client.from('profiles').select('id, full_name, phone_no, balance, role').order('full_name');
      if (mounted) setState(() => _dbUsers = res);
    } catch (_) {}
  }

  Future<void> _fetchRecords() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('lending_book').select().eq('user_id', user.id).order('created_at', ascending: false);
      
      double lent = 0;
      double ret = 0;
      double todayL = 0;
      double weekL = 0;
      double monthL = 0;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      Map<String, double> dTotals = {};

      for (var r in res) {
        double amt = (r['amount'] as num).toDouble();
        final dt = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? now;
        final name = (r['debtor_name'] ?? 'Unknown').toString();

        if (r['type'] == 'return') {
          ret += amt;
          dTotals[name] = (dTotals[name] ?? 0) - amt;
        } else {
          lent += amt;
          dTotals[name] = (dTotals[name] ?? 0) + amt;

          if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
            todayL += amt;
          }
          if (dt.isAfter(weekAgo)) {
            weekL += amt;
          }
          if (dt.isAfter(monthAgo)) {
            monthL += amt;
          }
        }
      }

      // Determine top debtor
      String? topName;
      double maxDue = 0;
      dTotals.forEach((k, v) {
        if (v > maxDue) {
          maxDue = v;
          topName = k;
        }
      });

      if (mounted) {
        setState(() {
          _records = res;
          _totalLent = lent;
          _totalReturned = ret;
          _netPosition = lent - ret;
          _todayLent = todayL;
          _weekLent = weekL;
          _monthLent = monthL;
          _debtorTotals = dTotals;
          _topDebtorName = topName;
          _topDebtorAmount = maxDue;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, List<dynamic>> _getGroupedRecords() {
    Map<String, List<dynamic>> grouped = {};
    for (var r in _records) {
      final key = r['debtor_phone'] ?? r['debtor_name'] ?? 'OTHER';
      if (grouped[key] == null) grouped[key] = [];
      grouped[key]!.add(r);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final grouped = _getGroupedRecords();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('KHATA & UDHAR LEDGER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.amberAccent),
            onPressed: () {
              _fetchRecords();
              _fetchDbUsers();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
        : Stack(
            children: [
              _buildRefractionOrb(isDark),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildStatsHeader(isDark),
                  const SizedBox(height: 24),
                  _buildPeriodicAnalyticsCard(isDark),
                  const SizedBox(height: 32),
                  _buildSectionHeader('DEBTOR PROFILES & ACTIVE DUES'),
                  const SizedBox(height: 16),
                  if (grouped.isEmpty) 
                    _buildEmptyState(isDark)
                  else
                    ...grouped.entries.map((e) => _debtorCard(e.key, e.value, isDark)).toList(),
                  const SizedBox(height: 100),
                ],
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntryModal(context, isDark),
        backgroundColor: Colors.amberAccent,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.black),
        label: const Text('RECORD UDHAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildPeriodicAnalyticsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TEMPORAL LENDING ANALYTICS', style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
              const Icon(Icons.analytics_rounded, color: Colors.amberAccent, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _analyticPill('TODAY', '₹${_todayLent.toInt()}', Colors.orangeAccent, isDark),
              const SizedBox(width: 8),
              _analyticPill('THIS WEEK', '₹${_weekLent.toInt()}', Colors.amberAccent, isDark),
              const SizedBox(width: 8),
              _analyticPill('THIS MONTH', '₹${_monthLent.toInt()}', Colors.purpleAccent, isDark),
            ],
          ),
          if (_topDebtorName != null && _topDebtorAmount > 0) ...[
            const Divider(height: 28, color: Colors.white10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high_rounded, color: Colors.redAccent, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HIGHEST OUTSTANDING DEBTOR', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      Text('${_topDebtorName!.toUpperCase()} (₹${_topDebtorAmount.toInt()})', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _analyticPill(String label, String val, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(val, style: GoogleFonts.outfit(color: c, fontWeight: FontWeight.w900, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _debtorCard(String key, List<dynamic> history, bool isDark) {
    double net = 0;
    String? photoUrl;
    for (var h in history) {
      double amt = (h['amount'] as num).toDouble();
      if (h['type'] == 'return') net -= amt; else net += amt;
      if (photoUrl == null && h['photo_url'] != null && h['photo_url'].toString().isNotEmpty) {
        photoUrl = h['photo_url'];
      }
    }

    final String name = history.isNotEmpty ? (history[0]['debtor_name'] ?? 'UNKNOWN') : 'UNKNOWN';

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: net > 0 ? Colors.amberAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: const EdgeInsets.all(20),
          leading: photoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(photoUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(name, net)),
                )
              : _avatarFallback(name, net),
          title: Text(name.toUpperCase(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(key, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
          trailing: Text('₹${net.toInt()}', style: GoogleFonts.outfit(color: net > 0 ? Colors.amberAccent : Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 18)),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.02), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(
                children: [
                   ...history.map((h) {
                     final isReturn = h['type'] == 'return';
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 12),
                       child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(h['created_at'])), style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9)),
                                if (h['notes'] != null && h['notes'].toString().isNotEmpty)
                                  Text('Note: ${h['notes']}', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10, fontStyle: FontStyle.italic)),
                              ],
                            ),
                            Text(isReturn ? 'RETURNED' : 'UDHAR LENT', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 8, fontWeight: FontWeight.bold)),
                            Text('${isReturn ? '-' : '+'}₹${(h['amount'] as num).toInt()}', style: TextStyle(color: isReturn ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                       ),
                     );
                   }).toList(),
                   const Divider(height: 24, color: Colors.white10),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       onPressed: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => DebtorProfileDetailScreen(
                               debtorName: name,
                               debtorPhone: history.first['debtor_phone']?.toString(),
                               photoUrl: photoUrl,
                               debtorUserId: history.first['debtor_user_id']?.toString(),
                               transactions: history,
                               onDataChanged: _fetchRecords,
                             ),
                           ),
                         );
                       },
                       icon: const Icon(Icons.person_pin_rounded, color: Colors.black, size: 16),
                       label: const Text('OPEN LENDER PROFILE & SETTLEMENT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.amberAccent,
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                     ),
                   ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name, double net) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (net > 0 ? Colors.amberAccent : Colors.greenAccent).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: TextStyle(color: net > 0 ? Colors.amberAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildStatsHeader(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.amberAccent.withOpacity(0.2), Colors.amberAccent.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NET ACTIVE LIQUIDITY OUTSTANDING', style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 12),
              Text('₹${_netPosition.toInt()}', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 40, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Active Udhar Balance in Circulation', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _miniAnalytic('LENT OUT', '₹${_totalLent.toInt()}', Colors.amberAccent, isDark),
            const SizedBox(width: 12),
            _miniAnalytic('RECOVERED', '₹${_totalReturned.toInt()}', Colors.greenAccent, isDark),
            const SizedBox(width: 12),
            _miniAnalytic('DEBTORS', '${_getGroupedRecords().length}', Colors.indigoAccent, isDark),
          ],
        ),
      ],
    );
  }

  Widget _miniAnalytic(String l, String v, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(v, style: GoogleFonts.outfit(color: c, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Row(children: [Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 2)), const Spacer(), Container(height: 1, width: 40, color: Colors.amberAccent.withOpacity(0.1))]);

  Widget _buildEmptyState(bool isDark) => Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [Icon(Icons.collections_bookmark_outlined, size: 48, color: isDark ? Colors.white10 : Colors.black12), const SizedBox(height: 16), Text('LEDGER CLEAR - NO ACTIVE UDHAR', style: TextStyle(color: isDark ? Colors.white12 : Colors.black12, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))])));

  Widget _buildRefractionOrb(bool isDark) => Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), shape: BoxShape.circle))));

  void _addEntryModal(BuildContext context, bool isDark) {
    String entryType = 'lent';
    _selectedImage = null;
    _selectedDbUserId = null;
    _deductFromWallet = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final textColor = isDark ? Colors.white : Colors.black;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LOG KHATA ENTRY', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _typeBtn('LENT (UDHAR)', 'lent', Colors.amberAccent, entryType == 'lent', () => setModalState(() => entryType = 'lent'), isDark),
                      const SizedBox(width: 8),
                      _typeBtn('RETURNED (VASOOLI)', 'return', Colors.greenAccent, entryType == 'return', () => setModalState(() => entryType = 'return'), isDark),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Option: Pick registered user from Database
                  if (_dbUsers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDbUserId,
                          isExpanded: true,
                          hint: Text('SELECT REGISTERED USER / STUDENT (OPTIONAL)', style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
                          dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
                          items: [
                            DropdownMenuItem(value: null, child: Text('NONE / MANUAL INPUT', style: TextStyle(color: textColor, fontSize: 11))),
                            ..._dbUsers.map((u) {
                              final bal = (u['balance'] as num? ?? 0).toDouble();
                              return DropdownMenuItem(
                                value: u['id']?.toString(),
                                child: Text('${u['full_name'] ?? 'User'} (Bal: ₹${bal.toInt()}) • ${u['role'] ?? ""}', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              _selectedDbUserId = val;
                              if (val != null) {
                                final matched = _dbUsers.firstWhere((u) => u['id'] == val, orElse: () => null);
                                if (matched != null) {
                                  _nameCtrl.text = matched['full_name'] ?? '';
                                  _phoneCtrl.text = matched['phone_no'] ?? '';
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _modalInput('DEBTOR NAME', _nameCtrl, isDark, Icons.person_outline),
                  const SizedBox(height: 12),
                  _modalInput('DEBTOR PHONE', _phoneCtrl, isDark, Icons.phone_outlined, isNumeric: true),
                  const SizedBox(height: 12),
                  _modalInput('AMOUNT (₹)', _amtCtrl, isDark, Icons.payments_outlined, isNumeric: true),
                  const SizedBox(height: 12),
                  _modalInput('TRANSACTION NOTES / ITEMS', _notesCtrl, isDark, Icons.notes_outlined),
                  const SizedBox(height: 16),
                  // Photo Capture / Upload Area
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
                            if (img != null) {
                              setModalState(() => _selectedImage = img);
                            }
                          },
                          icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.amberAccent),
                          label: const Text('TAKE PHOTO', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.amberAccent.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
                            if (img != null) {
                              setModalState(() => _selectedImage = img);
                            }
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.indigoAccent),
                          label: const Text('GALLERY', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.indigoAccent.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? const Icon(Icons.image, size: 40, color: Colors.amberAccent)
                              : Image.file(File(_selectedImage!.path), width: 50, height: 50, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        const Text('Photo attached for verification', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 18), onPressed: () => setModalState(() => _selectedImage = null)),
                      ],
                    ),
                  ],
                  if (_selectedDbUserId != null && entryType == 'lent') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _deductFromWallet,
                          activeColor: Colors.amberAccent,
                          onChanged: (v) => setModalState(() => _deductFromWallet = v ?? true),
                        ),
                        Expanded(
                          child: Text(
                            'Allow wallet balance to go negative (-₹) on overdraft lending',
                            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _submitEntry(entryType),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: const Text('AUTHORIZE COMMIT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _typeBtn(String label, String val, Color c, bool selected, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? c : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : (isDark ? Colors.white24 : Colors.black26),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modalInput(String label, TextEditingController ctrl, bool isDark, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, letterSpacing: 1),
        prefixIcon: Icon(icon, color: Colors.amberAccent, size: 18),
        filled: true,
        fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.amberAccent)),
      ),
    );
  }

  Future<void> _submitEntry(String type) async {
    final amt = double.tryParse(_amtCtrl.text);
    if (amt == null || amt <= 0 || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid name and amount.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated. Please log in.'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      String? uploadedPhotoUrl;
      if (_selectedImage != null) {
        try {
          final bytes = await _selectedImage!.readAsBytes();
          final path = 'khata/${DateTime.now().millisecondsSinceEpoch}_${_nameCtrl.text.replaceAll(' ', '_')}.jpg';
          await _client.storage.from('proofs').uploadBinary(path, bytes);
          uploadedPhotoUrl = _client.storage.from('proofs').getPublicUrl(path);
        } catch (_) {}
      }

      await _client.from('lending_book').insert({
        'user_id': user.id,
        'debtor_user_id': _selectedDbUserId,
        'debtor_name': _nameCtrl.text.trim(),
        'debtor_phone': _phoneCtrl.text.trim(),
        'amount': amt,
        'type': type,
        'status': 'pending',
        'notes': _notesCtrl.text.trim(),
        if (uploadedPhotoUrl != null) 'photo_url': uploadedPhotoUrl,
      });

      // If tied to registered user and overdraft lending enabled: update balance going into negative
      if (_selectedDbUserId != null && _deductFromWallet) {
        try {
          final profileRes = await _client.from('profiles').select('balance').eq('id', _selectedDbUserId!).maybeSingle();
          final curBal = (profileRes?['balance'] as num? ?? 0.0).toDouble();
          final updatedBal = type == 'lent' ? (curBal - amt) : (curBal + amt);
          await _client.from('profiles').update({'balance': updatedBal}).eq('id', _selectedDbUserId!);
        } catch (e) {
          debugPrint('Notice updating user wallet: $e');
        }
      }

      _nameCtrl.clear();
      _phoneCtrl.clear();
      _amtCtrl.clear();
      _notesCtrl.clear();
      _selectedImage = null;
      _selectedDbUserId = null;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khata transaction committed & balance synchronized.'), backgroundColor: Colors.greenAccent),
        );
        _fetchRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error committing: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
