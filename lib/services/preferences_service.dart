import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _savedItemsKey = 'saved_items';
  
  // Event Bus for Read Receipts
  final _readStreamController = StreamController<String>.broadcast();
  Stream<String> get readStream => _readStreamController.stream;

  Future<List<String>> getSavedItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedItemsKey) ?? [];
  }

  Future<void> toggleSavedItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedItems = prefs.getStringList(_savedItemsKey) ?? [];
    
    if (savedItems.contains(itemId)) {
      savedItems.remove(itemId);
    } else {
      savedItems.add(itemId);
    }
    
    await prefs.setStringList(_savedItemsKey, savedItems);
  }

  Future<bool> isItemSaved(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedItems = prefs.getStringList(_savedItemsKey) ?? [];
    return savedItems.contains(itemId);
  }

  Future<void> setLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('last_read_$roomId', now);
    // Broadcast update to all tactical listen nodes
    _readStreamController.add(roomId);
  }

  Future<DateTime> getLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('last_read_$roomId');
    return val != null ? DateTime.parse(val) : DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', isDark);
  }

  Future<bool> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_dark') ?? false;
  }

  Future<void> setNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<bool> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setLocationSharing(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_enabled', enabled);
  }

  Future<bool> getLocationSharing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_sharing_enabled') ?? false;
  }

  // --- Offline & Resume Profile Cache ---
  Future<void> saveCachedProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = Uri.encodeComponent(
        profile.entries.map((e) => '${e.key}=${e.value}').join('&'),
      );
      await prefs.setString('cached_user_profile_raw', encoded);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_user_profile_raw');
      if (raw == null || raw.isEmpty) return null;
      final decoded = Uri.decodeComponent(raw);
      final Map<String, dynamic> map = {};
      for (final pair in decoded.split('&')) {
        final idx = pair.indexOf('=');
        if (idx != -1) {
          map[pair.substring(0, idx)] = pair.substring(idx + 1);
        }
      }
      return map.isNotEmpty ? map : null;
    } catch (_) {
      return null;
    }
  }
}

