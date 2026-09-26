import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  
  AudioPlayer get player => _player;
  OnAudioQuery get audioQuery => _audioQuery;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _player.setVolume(1.0);
    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    try {
      // On Android, request audio/storage permission for local music queries
      if (await Permission.audio.request().isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;
      // On iOS, check mediaLibrary
      if (await Permission.mediaLibrary.isGranted) return true;
      await Permission.mediaLibrary.request();
    } catch (_) {}
    // Always return true — focus beats (assets) work without permission
    return true;
  }

  Future<List<SongModel>> fetchLocalSongs() async {
    try {
      return await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
    } catch (e) {
      log("Error fetching songs: $e");
      return [];
    }
  }

  Future<void> playSong(SongModel song) async {
    try {
      final String source = song.data;

      final Uri uri = (source.startsWith('http') || source.startsWith('content'))
          ? Uri.parse(source)
          : Uri.file(source);

      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? "Storage",
            title: song.title,
            artist: song.artist ?? "Local Track",
            artUri: null,
          ),
        ),
      );
      _player.play();
    } catch (e) {
      log("Error playing local song: $e");
    }
  }

  final List<Map<String, String>> _focusLibrary = [
    {'id': 'lofi_1', 'title': 'Lofi Study Sync', 'url': 'assets/audio/lofi.mp3'},
    {'id': 'tick_1', 'title': 'Metronome Tick', 'url': 'assets/audio/tick.mp3'}, 
    {'id': 'waves_1', 'title': 'Ocean Waves Crush', 'url': 'assets/audio/waves.mp3'},
    {'id': 'forest_1', 'title': 'Forest Atmosphere', 'url': 'assets/audio/forest.mp3'},
    {'id': 'study_1', 'title': 'Deep Dive Classical', 'url': 'assets/audio/study.mp3'},
    {'id': 'zen_1', 'title': 'Binaural Zen Flow', 'url': 'assets/audio/zen.mp3'},
  ];

  Future<void> playFocusBeats({required int trackIndex}) async {
    if (trackIndex >= _focusLibrary.length) return;
    
    final track = _focusLibrary[trackIndex];
    final path = track['url']!;
    try {
      await _player.setLoopMode(LoopMode.all);
      try {
        await _player.setAudioSource(
          AudioSource.asset(
            path,
            tag: MediaItem(
              id: track['id']!,
              album: "Focus Ecosystem",
              title: track['title']!,
              artist: "Hostel Synergy",
            ),
          ),
        );
      } catch (_) {
        // Fallback to direct setAsset
        await _player.setAsset(path);
      }
      await _player.setVolume(1.0);
      await _player.play();
    } catch (e) {
      log("Error playing focus beats: $e");
    }
  }

  void dispose() {
    _player.dispose();
  }
}
