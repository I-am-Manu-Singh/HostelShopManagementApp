import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';

class ZenProtocolScreen extends StatefulWidget {
  const ZenProtocolScreen({super.key});

  @override
  State<ZenProtocolScreen> createState() => _ZenProtocolScreenState();
}

class _ZenProtocolScreenState extends State<ZenProtocolScreen> with TickerProviderStateMixin {
  final _db = DatabaseService();
  final _tts = FlutterTts();
  late AnimationController _breathingController;
  int _minutes = 5;
  int _secondsRemaining = 5 * 60;
  bool _isActive = false;
  String _status = 'CALIBRATING';
  List<Map<String, dynamic>> _logs = [];
  bool _isAodMode = false;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _initTts();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _db.fetchMeditationLogs();
    if (mounted) setState(() => _logs = logs);
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.3);
    await _tts.setSpeechRate(0.42);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  void _toggleSession() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _breathingController.repeat(reverse: true);
        _startTimer();
        _db.updateStudyStatus('meditating');
      } else {
        _breathingController.stop();
        _db.updateStudyStatus('available');
      }
    });
  }

  void _startTimer() async {
    _tts.speak("Initiating Zen sequence. Focus on the core.");
    while (_isActive && _secondsRemaining > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isActive) {
        setState(() {
          _secondsRemaining--;
          int cyclePos = (_minutes * 60 - _secondsRemaining) % 19;
          if (cyclePos < 4) {
            _status = 'INHALE';
            if (cyclePos == 0) _tts.speak("Inhale.");
          } else if (cyclePos < 11) {
            _status = 'RETAIN';
            if (cyclePos == 4) _tts.speak("Hold.");
          } else {
            _status = 'EXHALE';
            if (cyclePos == 11) _tts.speak("Exhale.");
          }

          if (_secondsRemaining == 0) {
            _isActive = false;
            _breathingController.stop();
            _tts.speak("Protocol complete. Clarity achieved.");
            _db.incrementPerformanceWithLog(type: 'meditation', value: _minutes, xp: _minutes * 20);
            _db.updateStudyStatus('available');
            _loadLogs();
            _showCompletionDialog();
          }
        });
      }
    }
  }

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text('ZEN_SYNCHRONIZED', style: GoogleFonts.outfit(color: Colors.tealAccent, fontWeight: FontWeight.w900, letterSpacing: 2)),
          content: Text('Cognitive load reset complete. Minutes logged: $_minutes.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.bold)),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent), child: const Text('ACKNOWLEDGE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    int mins = _secondsRemaining ~/ 60;
    int secs = _secondsRemaining % 60;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isAodMode ? null : AppBar(
        title: Text('ZEN_PROTOCOL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(_isAodMode ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.tealAccent, size: 20),
            onPressed: () => setState(() => _isAodMode = !_isAodMode),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isAodMode) _buildRefractionOrb(isDark),
          if (!_isAodMode) _buildBreathingBg(isDark),
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            color: _isAodMode ? Colors.black : Colors.transparent,
            child: ListView(
              children: [
                const SizedBox(height: 60),
                Center(child: _buildBreathingSphere(mins, secs, _isAodMode ? Colors.tealAccent : textColor)),
                const SizedBox(height: 60),
                Center(child: FadeInUp(child: Text(_status, style: GoogleFonts.outfit(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 5)))),
                if (!_isAodMode) ...[
                  const SizedBox(height: 80),
                  _buildDurationPicker(isDark),
                  const SizedBox(height: 48),
                  Center(child: _buildMainAction(isDark)),
                  const SizedBox(height: 60),
                  _buildLogsSection(isDark),
                  const SizedBox(height: 60),
                ] else ...[
                   const SizedBox(height: 100),
                   Center(child: GestureDetector(onTap: () => setState(() => _isAodMode = false), child: Text('EXIT AOD', style: GoogleFonts.outfit(color: Colors.tealAccent.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)))),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingBg(bool isDark) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.tealAccent.withOpacity(0.05 * _breathingController.value),
              Colors.transparent,
            ],
            radius: 1.5 * _breathingController.value,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PREVIOUS_SESSIONS', style: GoogleFonts.outfit(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 20),
          if (_logs.isEmpty) 
             Text('NO DATA_LOGGED', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, fontWeight: FontWeight.bold))
          else 
             ..._logs.take(5).map((log) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.spa_rounded, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('LOGGED SESSION', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
                    Text('${log['duration_minutes']} MINS', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
             )),
        ],
      ),
    );
  }

  Widget _buildRefractionOrb(bool isDark) {
    return Positioned(bottom: -150, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 150, sigmaY: 150), child: Container(width: 400, height: 400, decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(isDark ? 0.05 : 0.02), shape: BoxShape.circle))));
  }

  Widget _buildBreathingSphere(int mins, int secs, Color textColor) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) => Container(
        width: 220 + (60 * _breathingController.value),
        height: 220 + (60 * _breathingController.value),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.tealAccent.withOpacity(0.02 + (0.05 * _breathingController.value)),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.1 + (0.2 * _breathingController.value)), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.tealAccent.withOpacity(0.05 * _breathingController.value), blurRadius: 60, spreadRadius: 10),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}', style: GoogleFonts.outfit(color: textColor, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2)),
            const SizedBox(height: 4),
            Text('NEURAL_MODE', style: GoogleFonts.outfit(color: Colors.tealAccent.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPicker(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        _settingCircle(5, _minutes == 5, (v) => setState((){_minutes = v; _secondsRemaining = v * 60;}), isDark),
        const SizedBox(width: 20),
        _settingCircle(10, _minutes == 10, (v) => setState((){_minutes = v; _secondsRemaining = v * 60;}), isDark),
        const SizedBox(width: 20),
        _settingCircle(20, _minutes == 20, (v) => setState((){_minutes = v; _secondsRemaining = v * 60;}), isDark),
      ],
    );
  }

  Widget _buildMainAction(bool isDark) {
    return GestureDetector(
      onTap: _toggleSession,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 22),
        decoration: BoxDecoration(
          color: _isActive ? Colors.redAccent.withOpacity(0.1) : Colors.tealAccent, 
          borderRadius: BorderRadius.circular(28), 
          border: _isActive ? Border.all(color: Colors.redAccent.withOpacity(0.3)) : null,
          boxShadow: !_isActive ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))] : [],
        ),
        child: Text(_isActive ? 'TERMINATE' : 'INITIATE ZEN', style: GoogleFonts.outfit(color: _isActive ? Colors.redAccent : Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
      ),
    );
  }

  Widget _settingCircle(int val, bool active, Function(int) onTap, bool isDark) {
    return GestureDetector(
      onTap: () => onTap(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), 
        width: 60, height: 60, 
        decoration: BoxDecoration(
          color: active ? Colors.tealAccent : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)), 
          shape: BoxShape.circle,
          border: Border.all(color: active ? Colors.white10 : (isDark ? Colors.white10 : Colors.black12)),
        ), 
        alignment: Alignment.center, 
        child: Text('$val', style: GoogleFonts.outfit(color: active ? Colors.black : (isDark ? Colors.white24 : Colors.black26), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
