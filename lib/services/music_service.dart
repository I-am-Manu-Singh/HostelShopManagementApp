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
    if (await Permission.audio.request().isGranted || await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
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
      // Use song.data (file path) or valid URI
      final String? source = song.data ?? song.uri;
      if (source == null) return;

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(source),
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? "Storage",
            title: song.title,
            artist: song.artist ?? "Local Track",
            artUri: null, // We use QueryArtworkWidget in UI
          ),
        ),
      );
      _player.play();
    } catch (e) {
      log("Error playing local song: $e");
    }
  }

  final List<Map<String, String>> _focusLibrary = [
    {'id': 'lofi_1', 'title': 'Lofi Study Sync', 'url': 'https://lumen-assets.s3.amazonaws.com/lofi.mp3'},
    {'id': 'tick_1', 'title': 'Metronome Tick', 'url': 'https://lumen-assets.s3.amazonaws.com/tick.mp3'}, 
    {'id': 'waves_1', 'title': 'Ocean Waves Crush', 'url': 'https://lumen-assets.s3.amazonaws.com/waves.mp3'},
    {'id': 'forest_1', 'title': 'Forest Atmosphere', 'url': 'https://lumen-assets.s3.amazonaws.com/forest.mp3'},
    {'id': 'study_1', 'title': 'Deep Dive Classical', 'url': 'https://lumen-assets.s3.amazonaws.com/study.mp3'},
    {'id': 'zen_1', 'title': 'Binaural Zen Flow', 'url': 'https://lumen-assets.s3.amazonaws.com/zen.mp3'},
  ];

  Future<void> playFocusBeats({required int trackIndex}) async {
    if (trackIndex >= _focusLibrary.length) return;
    
    final track = _focusLibrary[trackIndex];
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(track['url']!),
          tag: MediaItem(
            id: track['id']!,
            album: "Focus Ecosystem",
            title: track['title']!,
            artist: "Hostel Synergy",
          ),
        ),
      );
      _player.play();
    } catch (e) {
      log("Error playing focus beats: $e");
    }
  }

  void dispose() {
    _player.dispose();
  }
}
