import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class AlarmRingingScreen extends StatefulWidget {
  final String title;
  final String? soundAsset;
  final String category;
  final String time;

  const AlarmRingingScreen({
    super.key,
    required this.title,
    this.soundAsset,
    this.category = 'Focus',
    this.time = 'Now',
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> with SingleTickerProviderStateMixin {
  late AudioPlayer _player;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _autoStopTimer;

  final List<Map<String, String>> _availableSounds = [
    {'name': 'Zen Bells', 'asset': 'assets/audio/zen.mp3'},
    {'name': 'Study Bell', 'asset': 'assets/audio/study.mp3'},
    {'name': 'Forest Calm', 'asset': 'assets/audio/forest.mp3'},
    {'name': 'Ocean Waves', 'asset': 'assets/audio/waves.mp3'},
    {'name': 'Lofi Beats', 'asset': 'assets/audio/lofi.mp3'},
    {'name': 'Clock Tick', 'asset': 'assets/audio/tick.mp3'},
  ];

  late String _activeSound;

  @override
  void initState() {
    super.initState();
    _activeSound = widget.soundAsset ?? 'assets/audio/zen.mp3';
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudioAndWakelock();

    // Prevent screen from timing out while ringing
    WakelockPlus.enable();

    // Stop after 5 minutes if unhandled
    _autoStopTimer = Timer(const Duration(minutes: 5), () {
      _stopAndDismiss();
    });
  }

  Future<void> _initAudioAndWakelock() async {
    _player = AudioPlayer();
    try {
      await _player.setAsset(_activeSound);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Alarm audio playback notice: $e');
    }
  }

  Future<void> _switchSound(String soundPath) async {
    try {
      _activeSound = soundPath;
      await _player.stop();
      await _player.setAsset(soundPath);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error switching alarm sound: $e');
    }
  }

  Future<void> _stopAndDismiss() async {
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    WakelockPlus.disable();
    if (mounted) {
      Navigator.of(context).pop({'action': 'dismissed'});
    }
  }

  Future<void> _snooze(int minutes) async {
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    WakelockPlus.disable();
    if (mounted) {
      Navigator.of(context).pop({'action': 'snoozed', 'minutes': minutes});
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoStopTimer?.cancel();
    _player.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0E15),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                const Color(0xFF312E81).withOpacity(0.5),
                const Color(0xFF0F172A),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('RINGING PERSISTENT ALARM', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.music_note_rounded, color: Colors.white70),
                        tooltip: 'Change Alarm Sound',
                        onPressed: _showSoundPicker,
                      ),
                    ],
                  ),

                  // Center Alarm Display with Pulse Animation
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.alarm_on_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        widget.time,
                        style: GoogleFonts.outfit(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.category.toUpperCase(),
                          style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Controls: Snooze & Dismiss Buttons
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _snooze(5),
                              icon: const Icon(Icons.snooze_rounded, color: Colors.orangeAccent),
                              label: Text('SNOOZE 5M', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                side: BorderSide(color: Colors.orangeAccent.withOpacity(0.4), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _snooze(10),
                              icon: const Icon(Icons.snooze_rounded, color: Colors.amberAccent),
                              label: Text('SNOOZE 10M', style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                side: BorderSide(color: Colors.amberAccent.withOpacity(0.4), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: _stopAndDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            elevation: 8,
                            shadowColor: Colors.redAccent.withOpacity(0.6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 26),
                              const SizedBox(width: 12),
                              Text(
                                'STOP ALARM',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSoundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161824),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CHOOSE ALARM SOUND', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 16),
            ..._availableSounds.map((snd) {
              final isSelected = snd['asset'] == _activeSound;
              return ListTile(
                leading: Icon(Icons.music_note_rounded, color: isSelected ? Colors.pinkAccent : Colors.white38),
                title: Text(snd['name']!, style: GoogleFonts.outfit(color: isSelected ? Colors.pinkAccent : Colors.white, fontWeight: FontWeight.bold)),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.pinkAccent) : null,
                onTap: () {
                  _switchSound(snd['asset']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
