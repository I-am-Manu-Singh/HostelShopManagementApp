import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  final List<Map<String, dynamic>> _allowedApps = [
    {'name': 'Notes', 'icon': Icons.notes_rounded, 'color': Colors.amberAccent},
    {'name': 'Calculator', 'icon': Icons.calculate_rounded, 'color': Colors.blueAccent},
    {'name': 'Calendar', 'icon': Icons.calendar_month_rounded, 'color': Colors.redAccent},
    {'name': 'Camera', 'icon': Icons.camera_alt_rounded, 'color': Colors.grey},
    {'name': 'Clock', 'icon': Icons.access_time_filled_rounded, 'color': Colors.indigoAccent},
    {'name': 'Books', 'icon': Icons.menu_book_rounded, 'color': Colors.orangeAccent},
  ];

  bool _isStrictMode = false;
  String _exitPin = '1111'; // Loaded from Supabase profile metadata
  List<String> _selectedAppNames = ['Notes', 'Calculator', 'Clock'];

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('metadata')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        final meta = profile['metadata'];
        if (meta is Map && meta['focus_pin'] != null) {
          setState(() => _exitPin = meta['focus_pin'].toString());
        }
      }
    } catch (_) {} // silently keep default
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: !_isStrictMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isStrictMode) {
          _showPinModal();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF08090A) : const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            _buildShellBackground(isDark),
            SafeArea(
              child: Column(
                children: [
                  _buildShellHeader(isDark),
                  const SizedBox(height: 48),
                  _buildAppDrawer(isDark),
                  const Spacer(),
                  _buildLockStatus(isDark),
                  const SizedBox(height: 32),
                  _buildExitButton(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShellBackground(bool isDark) {
    return Positioned.fill(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigoAccent.withOpacity(0.05),
                Colors.purpleAccent.withOpacity(0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShellHeader(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: GoogleFonts.outfit(fontSize: 64, fontWeight: FontWeight.bold, color: textColor, letterSpacing: -2),
          ),
          Text(
            DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildAppDrawer(bool isDark) {
    final filteredApps = _allowedApps.where((a) => _selectedAppNames.contains(a['name'])).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      height: 300,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AUTHORIZED ECOSYSTEM', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              GestureDetector(
                onTap: () => _showAppSelectionModal(isDark),
                child: Text('MANAGE APPS', style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 32, crossAxisSpacing: 32),
              itemCount: filteredApps.length,
              itemBuilder: (context, i) {
                final app = filteredApps[i];
                return FadeInUp(
                  delay: Duration(milliseconds: i * 100),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive(app['name']) ? Colors.indigoAccent : Colors.transparent),
                        ),
                        child: Icon(app['icon'], color: app['color'], size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(app['name'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool isActive(String name) => _selectedAppNames.contains(name);

  void _showAppSelectionModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _allowedApps.map((app) => CheckboxListTile(
              title: Text(app['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              value: _selectedAppNames.contains(app['name']),
              activeColor: Colors.indigoAccent,
              onChanged: (v) {
                setModalState(() {
                  if (v!) _selectedAppNames.add(app['name']);
                  else _selectedAppNames.remove(app['name']);
                });
                setState(() {});
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLockStatus(bool isDark) {
    return FadeIn(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _isStrictMode ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isStrictMode ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(_isStrictMode ? Icons.lock_rounded : Icons.lock_open_rounded, color: _isStrictMode ? Colors.redAccent : Colors.greenAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isStrictMode ? 'STRICT MODE ACTIVE' : 'STANDARD FOCUS', style: GoogleFonts.outfit(color: _isStrictMode ? Colors.redAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text(_isStrictMode ? 'Exit requires security PIN' : 'Tap to engage strict lock', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: _isStrictMode,
              onChanged: (v) => setState(() => _isStrictMode = v),
              activeColor: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: _handleExit,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text('TERMINATE SESSION', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  void _handleExit() {
    if (!_isStrictMode) {
      Navigator.pop(context);
      return;
    }

    _showPinModal();
  }

  void _showPinModal() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(ctx).viewInsets.bottom + 32),
        decoration: const BoxDecoration(color: Color(0xFF08090A), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 24),
            Text('RESTRICTED ACCESS', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter security PIN to override strict mode.', style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 32),
            TextField(
              controller: ctrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '****',
                hintStyle: const TextStyle(color: Colors.white12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (ctrl.text == _exitPin) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('INVALID PIN'), backgroundColor: Colors.redAccent));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('OVERRIDE LOCK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
