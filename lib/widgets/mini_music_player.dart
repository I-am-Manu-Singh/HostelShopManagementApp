import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/music_service.dart';
import 'package:animate_do/animate_do.dart';

class MiniMusicPlayer extends StatefulWidget {
  const MiniMusicPlayer({super.key});

  @override
  State<MiniMusicPlayer> createState() => _MiniMusicPlayerState();
}

class _MiniMusicPlayerState extends State<MiniMusicPlayer> {
  final _musicService = MusicService();
  bool _isPlayerVisible = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await _musicService.requestPermission();
    if (mounted) setState(() => _isPlayerVisible = hasPermission);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerVisible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF16181A) : Colors.white;

    return StreamBuilder<PositionData>(
      stream: _musicService.player.positionStream.map(
        (position) => PositionData(
          position,
          _musicService.player.bufferedPosition,
          _musicService.player.duration ?? Duration.zero,
        ),
      ),
      builder: (context, positionSnapshot) {
        final positionData = positionSnapshot.data ??
            PositionData(Duration.zero, Duration.zero, Duration.zero);

        return StreamBuilder<PlayerState>(
          stream: _musicService.player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing ?? false;

            return FadeInUp(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10)),
                  ],
                  border: Border.all(color: Colors.indigoAccent.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _buildArtwork(isDark),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitle(isDark),
                              _buildSubtitle(isDark),
                            ],
                          ),
                        ),
                        _buildControls(playing, processingState),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildProgressBar(positionData, isDark),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArtwork(bool isDark) {
    return StreamBuilder<SequenceState?>(
      stream: _musicService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state?.currentSource == null) {
          return _defaultArtwork(isDark);
        }

        final metadata = state!.currentSource!.tag as MediaItem;
        // Focus beat tracks use asset sources — show a styled icon
        if (metadata.artUri == null) {
          return Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.indigoAccent, Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 22),
          );
        }

        return QueryArtworkWidget(
          id: int.tryParse(metadata.id) ?? 0,
          type: ArtworkType.AUDIO,
          artworkBorder: BorderRadius.circular(12),
          artworkWidth: 45,
          artworkHeight: 45,
          nullArtworkWidget: _defaultArtwork(isDark),
        );
      },
    );
  }

  Widget _defaultArtwork(bool isDark) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
          color: Colors.indigoAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.music_note_rounded, color: Colors.indigoAccent),
    );
  }

  Widget _buildProgressBar(PositionData data, bool isDark) {
    final maxMs = data.duration.inMilliseconds.toDouble();
    final curMs = data.position.inMilliseconds
        .toDouble()
        .clamp(0, maxMs > 0 ? maxMs : 1);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        activeTrackColor: Colors.indigoAccent,
        inactiveTrackColor:
            isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
        thumbColor: Colors.indigoAccent,
      ),
      child: Column(
        children: [
          Slider(
            min: 0,
            max: maxMs > 0 ? maxMs : 1,
            value: curMs.toDouble(),
            onChanged: maxMs > 0
                ? (v) => _musicService.player
                    .seek(Duration(milliseconds: v.toInt()))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(data.position),
                    style: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
                Text(_fmt(data.duration),
                    style: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  Widget _buildTitle(bool isDark) {
    return StreamBuilder<SequenceState?>(
      stream: _musicService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final metadata = snapshot.data?.currentSource?.tag as MediaItem?;
        return Text(
          metadata?.title ?? 'NOT PLAYING',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(bool isDark) {
    return StreamBuilder<SequenceState?>(
      stream: _musicService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final metadata = snapshot.data?.currentSource?.tag as MediaItem?;
        return Text(
          metadata?.artist ?? 'Select a track to start',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 11,
          ),
        );
      },
    );
  }

  Widget _buildControls(bool playing, ProcessingState? processingState) {
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return const SizedBox(
        width: 32,
        height: 32,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: Colors.indigoAccent),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.indigoAccent,
            size: 32,
          ),
          onPressed: () {
            if (playing) {
              _musicService.player.pause();
            } else {
              _musicService.player.play();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.indigoAccent),
          onPressed: () => _showLibraryModal(context),
        ),
      ],
    );
  }

  // ── Full Library Modal ─────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> _focusTracks = [
    {'index': 0, 'title': 'Lofi Study Sync',     'subtitle': 'Chill Beats',       'icon': Icons.self_improvement_rounded,  'color': Colors.indigoAccent},
    {'index': 1, 'title': 'Metronome Tick',       'subtitle': 'Rhythm Focus',      'icon': Icons.timer_rounded,             'color': Colors.tealAccent},
    {'index': 2, 'title': 'Ocean Waves',          'subtitle': 'Ambient Sounds',    'icon': Icons.waves_rounded,             'color': Colors.blueAccent},
    {'index': 3, 'title': 'Forest Atmosphere',    'subtitle': 'Nature Immersion',  'icon': Icons.park_rounded,              'color': Colors.greenAccent},
    {'index': 4, 'title': 'Deep Dive Classical',  'subtitle': 'Concentration',     'icon': Icons.music_note_rounded,        'color': Colors.purpleAccent},
    {'index': 5, 'title': 'Binaural Zen Flow',    'subtitle': 'Theta Waves',       'icon': Icons.spa_rounded,               'color': Colors.orangeAccent},
  ];

  void _showLibraryModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LibrarySheet(
        isDark: isDark,
        musicService: _musicService,
        focusTracks: _focusTracks,
      ),
    );
  }
}

// ── Library Bottom Sheet ────────────────────────────────────────────────────

class _LibrarySheet extends StatefulWidget {
  final bool isDark;
  final MusicService musicService;
  final List<Map<String, dynamic>> focusTracks;

  const _LibrarySheet({
    required this.isDark,
    required this.musicService,
    required this.focusTracks,
  });

  @override
  State<_LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends State<_LibrarySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<SongModel> _songs = [];
  bool _loading = true;
  String? _selectedArtist;
  int? _playingIndex; // focus track index currently playing

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadSongs();
    _listenToPlayer();
  }

  void _listenToPlayer() {
    widget.musicService.player.sequenceStateStream.listen((state) {
      if (!mounted) return;
      final meta = state?.currentSource?.tag as MediaItem?;
      if (meta != null) {
        final idx = int.tryParse(meta.id.replaceAll(RegExp(r'[^0-9]'), ''));
        setState(() => _playingIndex = idx);
      }
    });
  }

  Future<void> _loadSongs() async {
    final songs = await widget.musicService.fetchLocalSongs();
    if (mounted) setState(() { _songs = songs; _loading = false; });
  }

  List<String> get _artists {
    final set = <String>{};
    for (final s in _songs) {
      set.add(s.artist ?? 'Unknown Artist');
    }
    return set.toList()..sort();
  }

  List<SongModel> get _filteredSongs => _selectedArtist == null
      ? _songs
      : _songs.where((s) => s.artist == _selectedArtist).toList();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF16181A) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.library_music_rounded,
                      color: Colors.indigoAccent, size: 22),
                  const SizedBox(width: 12),
                  Text('MUSIC LIBRARY',
                      style: GoogleFonts.outfit(
                          color: Colors.indigoAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 2)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tab,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.indigoAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                labelColor: Colors.white,
                unselectedLabelColor:
                    widget.isDark ? Colors.white38 : Colors.black38,
                labelStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                tabs: const [
                  Tab(text: 'FOCUS BEATS'),
                  Tab(text: 'LOCAL MUSIC'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildFocusSection(textColor),
                  _buildLocalSection(scrollController, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Focus Beats Section ───────────────────────────────────────────────────

  Widget _buildFocusSection(Color textColor) {
    return StreamBuilder<PlayerState>(
      stream: widget.musicService.player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: widget.focusTracks.length,
          itemBuilder: (ctx, i) {
            final track = widget.focusTracks[i];
            final isActive = _playingIndex == track['index'];
            final color = track['color'] as Color;

            return FadeInUp(
              delay: Duration(milliseconds: 60 * i),
              child: GestureDetector(
                onTap: () {
                  widget.musicService.playFocusBeats(
                      trackIndex: track['index'] as int);
                  setState(() => _playingIndex = track['index'] as int);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withOpacity(0.12)
                        : (widget.isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: isActive
                            ? color.withOpacity(0.4)
                            : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(track['icon'] as IconData,
                            color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track['title'] as String,
                                style: GoogleFonts.outfit(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text(track['subtitle'] as String,
                                style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      if (isActive)
                        GestureDetector(
                          onTap: () {
                            if (playing) {
                              widget.musicService.player.pause();
                            } else {
                              widget.musicService.player.play();
                            }
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                        )
                      else
                        Icon(Icons.play_circle_outline_rounded,
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.black26,
                            size: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Local Music Section ───────────────────────────────────────────────────

  Widget _buildLocalSection(ScrollController scrollCtrl, Color textColor) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.indigoAccent));
    }
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_rounded,
                color: Colors.white12, size: 56),
            const SizedBox(height: 12),
            Text('No local songs found',
                style: GoogleFonts.outfit(
                    color: widget.isDark ? Colors.white24 : Colors.black26,
                    fontSize: 14)),
          ],
        ),
      );
    }

    final artists = _artists;

    return Column(
      children: [
        // Artist filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _artistChip('All', null),
              ...artists.map((a) => _artistChip(a, a)),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Songs list
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: _filteredSongs.length,
            itemBuilder: (ctx, i) {
              final song = _filteredSongs[i];
              return FadeInUp(
                delay: Duration(milliseconds: 40 * i),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkBorder: BorderRadius.circular(10),
                    artworkWidth: 46,
                    artworkHeight: 46,
                    nullArtworkWidget: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: Colors.indigoAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.music_note_rounded,
                          color: Colors.indigoAccent, size: 20),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  subtitle: Text(
                    song.artist ?? 'Unknown Artist',
                    style: TextStyle(
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                        fontSize: 11),
                  ),
                  trailing: Icon(Icons.play_circle_outline_rounded,
                      color: Colors.indigoAccent.withOpacity(0.5), size: 28),
                  onTap: () {
                    widget.musicService.playSong(song);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _artistChip(String label, String? artist) {
    final active = _selectedArtist == artist;
    return GestureDetector(
      onTap: () => setState(() => _selectedArtist = artist),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.indigoAccent
              : (widget.isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.length > 18 ? '${label.substring(0, 16)}…' : label,
          style: GoogleFonts.outfit(
              color: active
                  ? Colors.white
                  : (widget.isDark ? Colors.white54 : Colors.black54),
              fontWeight: FontWeight.w700,
              fontSize: 10),
        ),
      ),
    );
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}
