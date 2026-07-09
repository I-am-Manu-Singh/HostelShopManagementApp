import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/database_service.dart';
import 'attendance_calendar_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final String type;
  const AttendanceScreen({super.key, required this.type});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  final DatabaseService _db = DatabaseService();
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLoading = false;
  String? _selectedMeal = 'Breakfast';
  int _presentDays = 0;
  int _skippedDays = 0;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _db.fetchBiometricStats(); 
    // I will add fetchBiometricStats to DatabaseService
    if (mounted) {
      setState(() {
        _presentDays = stats['present'] ?? 0;
        _skippedDays = stats['skipped'] ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _markAttendance() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
         _showError('Biometric verification not supported on this device');
         return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please verify identity to mark attendance',
      );

      if (!didAuthenticate) return;

      setState(() => _isLoading = true);
      final success = await _db.markAttendance(
        type: widget.type,
        mealType: widget.type == 'mess' ? _selectedMeal : null,
      );
      setState(() => _isLoading = false);

      if (success) {
        _showSuccessDialog();
      } else {
        _showError('Failed to save attendance record.');
      }
    } catch (e) {
      _showError('Authentication error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (c) => Center(
        child: FadeInDown(
          child: Container(
            padding: const EdgeInsets.all(30),
            margin: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: const Color(0xFF16181A), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 60),
                const SizedBox(height: 20),
                Text('VERIFIED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text('Presence logged at ${DateFormat('HH:mm').format(DateTime.now())}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 30),
                ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent), child: const Text('DISMISS')),
              ],
            ),
          ),
        ),
      ),
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
        title: Text('${widget.type.toUpperCase()} ATTENDANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 20), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceCalendarScreen(type: widget.type)))
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildRadarBackground(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildTimeHeader(textColor),
                const Spacer(),
                if (widget.type == 'mess') ...[
                  Text('SELECT MEAL', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  _buildMealSelector(isDark),
                  const SizedBox(height: 48),
                ],
                _buildScannerButton(isDark),
                const Spacer(),
                _buildHistoryFooter(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeHeader(Color textColor) {
    return Column(
      children: [
        Text(DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(), style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(DateFormat('HH:mm').format(DateTime.now()), style: GoogleFonts.outfit(color: textColor, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -2)),
      ],
    );
  }

  Widget _buildRadarBackground() {
    return Center(
      child: AnimatedBuilder(
        animation: _radarController,
        builder: (context, child) => Container(
          width: 300 * _radarController.value,
          height: 300 * _radarController.value,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.indigoAccent.withOpacity(1 - _radarController.value))),
        ),
      ),
    );
  }

  Widget _buildMealSelector(bool isDark) {
    final meals = ['Breakfast', 'Lunch', 'Tea', 'Dinner'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: meals.map((meal) {
        bool selected = _selectedMeal == meal;
        return GestureDetector(
          onTap: () => setState(() => _selectedMeal = meal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)), 
              borderRadius: BorderRadius.circular(15), 
              border: Border.all(color: selected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))
            ),
            child: Text(meal.toUpperCase(), style: GoogleFonts.outfit(color: selected ? Colors.white : (isDark ? Colors.white24 : Colors.black26), fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScannerButton(bool isDark) {
    return GestureDetector(
      onTap: _isLoading ? null : _markAttendance,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.indigoAccent.withOpacity(0.05), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)))),
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Colors.indigoAccent, Color(0xFF6366F1)]),
              boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
            ),
            child: Center(
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 40),
                    const SizedBox(height: 8),
                    Text('VERIFY', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _footStat('$_presentDays', 'PRESENT', isDark),
          Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.black12),
          _footStat('$_skippedDays', 'SKIPPED', isDark, color: Colors.orangeAccent),
          Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.black12),
          _footStat('${((_presentDays / 30) * 100).toInt()}%', 'RATIO', isDark),
        ],
      ),
    );
  }
Widget _footStat(
  String value,
  String label,
  bool isDark, {
  Color? color,
}) {
  return Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color ?? (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    ],
  );
}
  
}
