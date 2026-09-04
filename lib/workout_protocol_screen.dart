import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';

class WorkoutProtocolScreen extends StatefulWidget {
  const WorkoutProtocolScreen({super.key});

  @override
  State<WorkoutProtocolScreen> createState() => _WorkoutProtocolScreenState();
}

class _WorkoutProtocolScreenState extends State<WorkoutProtocolScreen> with TickerProviderStateMixin {
  final _db = DatabaseService();
  final _tts = FlutterTts();
  int _secondsRemaining = 0;
  bool _isActive = false;
  int _currentExerciseIndex = 0;
  int _totalMinsLogged = 0;
  List<Map<String, dynamic>> _logs = [];
  bool _isAodMode = false;

  final List<Map<String, dynamic>> _exercises = [
    {'name': 'PUSH-UPS', 'duration': 60, 'icon': Icons.fitness_center_rounded, 'desc': 'Chest & Triceps'},
    {'name': 'PLANK', 'duration': 45, 'icon': Icons.timer_rounded, 'desc': 'Core Stability'},
    {'name': 'SQUATS', 'duration': 60, 'icon': Icons.accessibility_new_rounded, 'desc': 'Lower Body Strength'},
    {'name': 'MOUNTAIN CLIMBERS', 'duration': 30, 'icon': Icons.run_circle_outlined, 'desc': 'Full Body Cardio'},
    {'name': 'BURPEES', 'duration': 45, 'icon': Icons.bolt_rounded, 'desc': 'Full Body Explosive'},
    {'name': 'JUMPING JACKS', 'duration': 60, 'icon': Icons.directions_run_rounded, 'desc': 'Cardio Warmup'},
    {'name': 'LUNGES', 'duration': 45, 'icon': Icons.accessibility_new_rounded, 'desc': 'Leg Strength'},
    {'name': 'DIPS', 'duration': 40, 'icon': Icons.fitness_center_rounded, 'desc': 'Triceps'},
  ];

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _exercises[0]['duration'];
    _initTts();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _db.fetchWorkoutLogs();
    if (mounted) setState(() => _logs = logs);
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.2);
    await _tts.setSpeechRate(0.55);
  }

  void _toggleSession() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _startWorkout();
        _db.updateStudyStatus('training');
      } else {
        _db.updateStudyStatus('available');
      }
    });
  }

  void _startWorkout() async {
    _tts.speak("Workout started. Begin ${_exercises[_currentExerciseIndex]['name']}.");
    while (_isActive && _secondsRemaining > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isActive) {
        setState(() {
          _secondsRemaining--;
          if (_secondsRemaining == 10) _tts.speak("Ten seconds left.");
          if (_secondsRemaining == 3) _tts.speak("3.");
          if (_secondsRemaining == 2) _tts.speak("2.");
          if (_secondsRemaining == 1) _tts.speak("1.");
          if (_secondsRemaining == 0) {
            _handleExerciseComplete();
          }
        });
      }
    }
  }

  void _handleExerciseComplete() {
    _totalMinsLogged++;
    if (_currentExerciseIndex < _exercises.length - 1) {
      _currentExerciseIndex++;
      _secondsRemaining = _exercises[_currentExerciseIndex]['duration'];
      _isActive = false;
      _tts.speak("${_exercises[_currentExerciseIndex - 1]['name']} completed. Preparing ${_exercises[_currentExerciseIndex]['name']}.");
    } else {
      _isActive = false;
      _tts.speak("Workout complete. Well done!");
      _db.incrementPerformanceWithLog(type: 'workout', value: _totalMinsLogged, xp: _totalMinsLogged * 50);
      _db.updateStudyStatus('available');
      _loadLogs();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text('Workout Complete', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontWeight: FontWeight.w900, letterSpacing: 2)),
          content: Text('Total active time: $_totalMinsLogged mins.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.bold)),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), child: const Text('DONE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final currentExercise = _exercises[_currentExerciseIndex];
    double progress = _secondsRemaining / currentExercise['duration'];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isAodMode ? null : AppBar(
        title: Text('WORKOUT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0, 
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(_isAodMode ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.orangeAccent, size: 20),
            onPressed: () => setState(() => _isAodMode = !_isAodMode),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isAodMode) _buildRefractionOrb(isDark),
          if (!_isAodMode) _buildBreathingBg(),
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            color: _isAodMode ? Colors.black : Colors.transparent,
            child: ListView(
              children: [
                const SizedBox(height: 60),
                if (!_isAodMode) _buildExerciseInfo(currentExercise, textColor, isDark),
                const SizedBox(height: 60),
                Hero(
                  tag: 'workout_sphere',
                  child: _buildMainDisplay(progress, currentExercise, _isAodMode ? Colors.orangeAccent : textColor, isDark),
                ),
                if (!_isAodMode) ...[
                  const SizedBox(height: 32),
                  _buildExerciseList(isDark),
                  const Spacer(),
                  _buildFooterControls(isDark),
                  const SizedBox(height: 48),
                  _buildLogsSection(isDark),
                  const SizedBox(height: 60),
                ] else ...[
                   const SizedBox(height: 100),
                   Center(child: GestureDetector(onTap: () => setState(() => _isAodMode = false), child: Text('EXIT AOD', style: GoogleFonts.outfit(color: Colors.orangeAccent.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)))),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingBg() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Colors.orangeAccent.withOpacity(0.05),
            Colors.transparent,
          ],
          radius: 1.5,
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
          Text('PREVIOUS SESSIONS', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
                    Icon(Icons.fitness_center_rounded, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('LOGGED WORKOUT', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
                    Text('${log['duration_minutes']} MINS', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
             )),
        ],
      ),
    );
  }

  Widget _buildRefractionOrb(bool isDark) {
    return Positioned(top: -100, right: -100, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 150, sigmaY: 150), child: Container(width: 400, height: 400, decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(isDark ? 0.05 : 0.02), shape: BoxShape.circle))));
  }

  Widget _buildExerciseInfo(Map<String, dynamic> exercise, Color textColor, bool isDark) {
    return FadeInDown(
      child: Column(
        children: [
          Text(exercise['name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 8),
          Text(exercise['desc'], style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildMainDisplay(double progress, Map<String, dynamic> exercise, Color textColor, bool isDark) {
    return Hero(
      tag: 'workout_sphere',
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 280, height: 280,
            child: CircularProgressIndicator(
              value: progress, 
              strokeWidth: 4, 
              backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), 
              color: Colors.orangeAccent, 
              strokeCap: StrokeCap.round
            ),
          ),
          if (_isActive) 
            Pulse(
              infinite: true,
              child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.orangeAccent.withOpacity(0.05), Colors.transparent]))),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(exercise['icon'] as IconData, color: Colors.orangeAccent, size: 42),
              const SizedBox(height: 16),
              Text('${_secondsRemaining}S', style: GoogleFonts.outfit(color: textColor, fontSize: 68, fontWeight: FontWeight.w900, height: 1, letterSpacing: -2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterControls(bool isDark) {
    return FadeInUp(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _kineticActionBtn(
            _isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, 
            _isActive ? 'HOLD' : 'PULSE', 
            Colors.orangeAccent, 
            isDark, 
            onTap: _toggleSession
          ),
          const SizedBox(width: 24),
          _kineticActionBtn(
            Icons.skip_next_rounded, 
            'SKIP', 
            isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), 
            isDark, 
            onTap: () {
              setState(() {
                if (_currentExerciseIndex < _exercises.length - 1) {
                   _currentExerciseIndex++;
                   _secondsRemaining = _exercises[_currentExerciseIndex]['duration'];
                   _isActive = false;
                }
              });
            }
          ),
        ],
      ),
    );
  }

  Widget _kineticActionBtn(IconData icon, String label, Color color, bool isDark, {VoidCallback? onTap}) {
    bool isPrimary = color == Colors.orangeAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85, width: 130,
        decoration: BoxDecoration(
          color: isPrimary ? color : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isPrimary ? Colors.white24 : (isDark ? Colors.white12 : Colors.black12)),
          boxShadow: isPrimary ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 10))] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.black : (isDark ? Colors.white : Colors.black), size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(color: isPrimary ? Colors.black : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ROUTINE_QUEUE', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              IconButton(onPressed: () => _showAddExerciseModal(isDark), icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.orangeAccent, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _exercises.removeAt(oldIndex);
                  _exercises.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _exercises.length; i++)
                  _exerciseChip(_exercises[i], i, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseChip(Map<String, dynamic> ex, int index, bool isDark) {
    bool active = _currentExerciseIndex == index;
    return Container(
      key: ValueKey(ex['name'] + index.toString()),
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onLongPress: () => setState(() => _exercises.removeAt(index)),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? Colors.orangeAccent : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? Colors.white24 : Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ex['name'].toString().toUpperCase(), style: GoogleFonts.outfit(color: active ? Colors.black : (isDark ? Colors.white70 : Colors.black87), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${ex['duration']}S', style: TextStyle(color: active ? Colors.black54 : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddExerciseModal(bool isDark) {
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '60');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(c).viewInsets.bottom + 32),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF16181A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADD_NEW_KINETIC_BLOCK', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 24),
            TextField(controller: nameCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputDeco('Exercise Name (e.g. Lunges)', isDark)),
            const SizedBox(height: 20),
            TextField(controller: timeCtrl, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputDeco('Duration in Seconds', isDark)),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _exercises.add({
                    'name': nameCtrl.text.toUpperCase(),
                    'duration': int.tryParse(timeCtrl.text) ?? 60,
                    'icon': Icons.bolt_rounded,
                    'desc': 'Custom Protocol Block',
                  });
                });
                Navigator.pop(c);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('ENGAGE ROUTINE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String h, bool isDark) => InputDecoration(hintText: h, hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(20));
}
