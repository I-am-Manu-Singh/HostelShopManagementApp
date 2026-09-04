import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/database_service.dart';
import '../../services/music_service.dart';

class PomodoroProtocolScreen extends StatefulWidget {
  final String? taskName;
  final String? taskId;
  const PomodoroProtocolScreen({super.key, this.taskName, this.taskId});

  @override
  State<PomodoroProtocolScreen> createState() => _PomodoroProtocolScreenState();
}

class _PomodoroProtocolScreenState extends State<PomodoroProtocolScreen> with TickerProviderStateMixin {
  final _db = DatabaseService();
  final _tts = FlutterTts();
  final _music = MusicService();
  
  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.25);
    await _tts.setSpeechRate(0.55);
  }
  
  int _focusTime = 25 * 60;
  int _breakTime = 5 * 60;
  
  late int _secondsRemaining;
  bool _isActive = false;
  bool _isBreak = false;
  bool _isMuted = false;
  int _currentTrackIndex = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _logs = [];
  bool _isAodMode = false;

  Future<void> _loadLogs() async {
    final logs = await _db.fetchFocusLogs();
    if (mounted) setState(() => _logs = logs);
  }

  void _toggleTimer() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _startTimer();
        _tts.speak(_isBreak ? "Break started. Time to recharge." : "Focus mode on. Let's get to work.");
        _music.playFocusBeats(trackIndex: _currentTrackIndex);
        _db.updateStudyStatus(_isBreak ? 'resting' : 'focusing');
      } else {
        _timer?.cancel();
        _music.player.pause();
        _db.updateStudyStatus('available');
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isActive) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _isActive = false;
            _timer?.cancel();
            _handleCycleComplete();
          }
        });
      }
    });
  }

  void _handleCycleComplete() async {
    if (!_isBreak) {
      _db.incrementPerformanceWithLog(type: 'focus', value: _focusTime, xp: 50);
      _tts.speak("Focus session done. Take a short break.");
      _db.updateStudyStatus('resting');
      _loadLogs();
      
      // Auto-complete task if present
      if (widget.taskId != null) {
        await _db.completeStudentTask(widget.taskId!);
      }

      setState(() {
        _isBreak = true;
        _secondsRemaining = _breakTime;
      });
      _music.playFocusBeats(trackIndex: 1); // Rain for break
    } else {
      _tts.speak("Break over. Ready for the next session?");
      _db.updateStudyStatus('focusing');
      setState(() {
        _isBreak = false;
        _secondsRemaining = _focusTime;
      });
      _music.playFocusBeats(trackIndex: 0); // Lofi for focus
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    int mins = _secondsRemaining ~/ 60;
    int secs = _secondsRemaining % 60;
    double progress = _secondsRemaining / (_isBreak ? _breakTime : _focusTime);
    final themeColor = _isBreak ? Colors.greenAccent : Colors.indigoAccent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isAodMode ? null : AppBar(
        title: Text('FOCUS_PROTOCOL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(_isAodMode ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: themeColor, size: 20),
            onPressed: () => setState(() => _isAodMode = !_isAodMode),
          ),
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: textColor.withOpacity(0.5), size: 20),
            onPressed: () => setState(() {
              _isMuted = !_isMuted;
              _music.player.setVolume(_isMuted ? 0 : 1.0);
            })
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isAodMode) _buildRefractionOrbs(themeColor, isDark),
          if (!_isAodMode) _buildBreathingBg(themeColor),
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            color: _isAodMode ? Colors.black : Colors.transparent,
            child: ListView(
              children: [
                const SizedBox(height: 60),
                if (widget.taskName != null && !_isAodMode) 
                  Center(child: FadeInDown(child: Text(widget.taskName!.toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)))),
                const SizedBox(height: 12),
                Center(child: FadeInDown(child: _statusBadge(themeColor, isDark))),
                const SizedBox(height: 60),
                Hero(
                  tag: 'timer_sphere',
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildTimerRing(progress, themeColor, isDark),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}', style: GoogleFonts.outfit(color: _isAodMode ? themeColor : textColor, fontSize: 68, fontWeight: FontWeight.w900, letterSpacing: -2)),
                            const SizedBox(height: 4),
                            Text(_isActive ? 'BIO-SYNC ACTIVE' : 'PROTOCOL PAUSED', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isAodMode) ...[
                  const SizedBox(height: 60),
                  _buildTimeCustomizer(themeColor, isDark),
                  const SizedBox(height: 48),
                  _buildTrackSelector(themeColor, isDark),
                  const SizedBox(height: 60),
                  Center(child: _buildActionButtons(themeColor, isDark)),
                  const SizedBox(height: 60),
                  _buildLogsSection(themeColor, isDark),
                  const SizedBox(height: 60),
                ] else ...[
                   const SizedBox(height: 100),
                   Center(child: GestureDetector(onTap: () => setState(() => _isAodMode = false), child: Text('EXIT AOD', style: GoogleFonts.outfit(color: themeColor.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)))),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingBg(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.05),
            Colors.transparent,
          ],
          radius: 1.5,
        ),
      ),
    );
  }

  Widget _buildTimeCustomizer(Color color, bool isDark) {
    return Column(
      children: [
        Text(_isBreak ? 'BREAK_DURATION' : 'FOCUS_DURATION', style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _timeBtn(15, color, isDark),
            const SizedBox(width: 12),
            _timeBtn(25, color, isDark),
            const SizedBox(width: 12),
            _timeBtn(45, color, isDark),
            const SizedBox(width: 12),
            _timeBtn(60, color, isDark),
          ],
        ),
      ],
    );
  }

  Widget _timeBtn(int mins, Color color, bool isDark) {
    bool active = (_isBreak ? _breakTime : _focusTime) == mins * 60;
    return GestureDetector(
      onTap: () => setState(() {
        if (_isBreak) _breakTime = mins * 60;
        else _focusTime = mins * 60;
        _secondsRemaining = mins * 60;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.white10 : Colors.transparent),
        ),
        child: Text('$mins', style: GoogleFonts.outfit(color: active ? Colors.black : (isDark ? Colors.white24 : Colors.black26), fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLogsSection(Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PREVIOUS_SESSIONS', style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
                    Icon(Icons.timer_rounded, color: color, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('FOCUS ACHIEVED', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
                    Text('${(log['duration_seconds'] / 60).round()} MINS', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
             )),
        ],
      ),
    );
  }

  Widget _buildTrackSelector(Color color, bool isDark) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _trackBtn(0, 'LOFI', isDark),
        _trackBtn(1, 'TICK', isDark),
        _trackBtn(2, 'WAVES', isDark),
        _trackBtn(3, 'FOREST', isDark),
        _trackBtn(4, 'STUDY', isDark),
        _trackBtn(5, 'ZEN', isDark),
      ],
    );
  }

  Widget _trackBtn(int index, String label, bool isDark) {
    bool active = _currentTrackIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTrackIndex = index);
        if (_isActive) _music.playFocusBeats(trackIndex: index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.indigoAccent.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.indigoAccent.withOpacity(0.3) : Colors.transparent),
        ),
        child: Text(label, style: GoogleFonts.outfit(color: active ? Colors.indigoAccent : (isDark ? Colors.white24 : Colors.black26), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildRefractionOrbs(Color color, bool isDark) {
    return Positioned(top: 100, left: -100, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container(width: 400, height: 400, decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.05 : 0.03), shape: BoxShape.circle))));
  }

  Widget _statusBadge(Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(_isBreak ? 'REST_BREACH' : 'DEEP_STASIS', style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
    );
  }

  Widget _buildTimerRing(double progress, Color color, bool isDark) {
    return Container(
      width: 280, height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 250, height: 250,
            child: CircularProgressIndicator(
              value: 1 - progress,
              strokeWidth: 4,
              backgroundColor: Colors.transparent,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          if (_isActive) 
            Pulse(
              infinite: true,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [color.withOpacity(0.05), Colors.transparent]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color themeColor, bool isDark) {
    return FadeInUp(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pomoActionBtn(
            _isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, 
            _isActive ? 'HALT' : 'INITIATE', 
            _isActive ? Colors.redAccent : themeColor, 
            isDark, 
            onTap: _toggleTimer
          ),
          const SizedBox(width: 24),
          _pomoActionBtn(
            Icons.refresh_rounded, 
            'RESET', 
            isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), 
            isDark, 
            onTap: () {
              setState(() {
                _isActive = false;
                _timer?.cancel();
                _secondsRemaining = _isBreak ? _breakTime : _focusTime;
              });
            }
          ),
        ],
      ),
    );
  }

  Widget _pomoActionBtn(IconData icon, String label, Color color, bool isDark, {VoidCallback? onTap}) {
    bool isPrimary = color == Colors.indigoAccent || color == Colors.greenAccent || color == Colors.redAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80, width: 120,
        decoration: BoxDecoration(
          color: isPrimary ? color : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isPrimary ? Colors.white10 : (isDark ? Colors.white10 : Colors.black12)),
          boxShadow: isPrimary ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.black : (isDark ? Colors.white : Colors.black87), size: 24),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(color: isPrimary ? Colors.black : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
