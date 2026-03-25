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
    if (hasPermission) {
      if (mounted) setState(() => _isPlayerVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerVisible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return StreamBuilder<PositionData>(
      stream: _musicService.player.positionStream.map(
        (position) => PositionData(
          position,
          _musicService.player.bufferedPosition,
          _musicService.player.duration ?? Duration.zero,
        ),
      ),
      builder: (context, positionSnapshot) {
        final positionData = positionSnapshot.data ?? PositionData(Duration.zero, Duration.zero, Duration.zero);

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
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
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
                    const SizedBox(height: 8),
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
          return Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.music_note_rounded, color: Colors.indigoAccent),
          );
        }

        final metadata = state!.currentSource!.tag as MediaItem;
        if (metadata.id.startsWith('lofi') || metadata.id.startsWith('rain') || metadata.id.startsWith('zen')) {
           return Container(
            width: 45, height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(image: NetworkImage("https://cdn-icons-png.flaticon.com/512/1384/1384061.png"), fit: BoxFit.cover),
            ),
          );
        }

        return QueryArtworkWidget(
          id: int.tryParse(metadata.id) ?? 0,
          type: ArtworkType.AUDIO,
          artworkBorder: BorderRadius.circular(12),
          artworkWidth: 45,
          artworkHeight: 45,
          nullArtworkWidget: Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.music_note_rounded, color: Colors.indigoAccent),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(PositionData data, bool isDark) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        activeTrackColor: Colors.indigoAccent,
        inactiveTrackColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
        thumbColor: Colors.indigoAccent,
      ),
      child: Column(
        children: [
          Slider(
            min: 0,
            max: data.duration.inMilliseconds.toDouble(),
            value: data.position.inMilliseconds.toDouble().clamp(0, data.duration.inMilliseconds.toDouble()),
            onChanged: (v) => _musicService.player.seek(Duration(milliseconds: v.toInt())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(data.position), style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
                Text(_formatDuration(data.duration), style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildTitle(bool isDark) {
    return StreamBuilder<SequenceState?>(
      stream: _musicService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final metadata = state?.currentSource?.tag as MediaItem?;
        return Text(
          metadata?.title ?? "NOT PLAYING",
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
        final state = snapshot.data;
        final metadata = state?.currentSource?.tag as MediaItem?;
        return Text(
          metadata?.artist ?? "Select a track to start",
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
    if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigoAccent),
      );
    }

    return Row(
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
          icon: const Icon(Icons.playlist_play_rounded, color: Colors.indigoAccent),
          onPressed: () => _showPlaylistModal(context),
        ),
      ],
    );
  }

  void _showPlaylistModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MUSIC LIBRARY',
                  style: GoogleFonts.outfit(
                    color: Colors.indigoAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _musicService.playFocusBeats(trackIndex: 0),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('LO-FI FOCUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<SongModel>>(
                future: _musicService.fetchLocalSongs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final songs = snapshot.data ?? [];
                  if (songs.isEmpty) {
                    return Center(
                      child: Text(
                        'NO LOCAL SONGS FOUND',
                        style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return ListTile(
                        leading: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          nullArtworkWidget: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.music_note_rounded, color: Colors.indigoAccent),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          song.artist ?? "Unknown Artist",
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                        ),
                        onTap: () {
                          _musicService.playSong(song);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
