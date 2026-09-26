import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance = NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal();

  Timer? _pollingTimer;
  bool _isOnline = true;
  bool _hasInitialCheck = false;
  OverlaySupportEntry? _currentBanner;

  bool get isOnline => _isOnline;

  void startMonitoring() {
    _checkConnectivity();
    _pollingTimer?.cancel();
    // Poll every 5 seconds for robust cross-platform connectivity detection
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivity();
    });
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
  }

  Future<void> _checkConnectivity() async {
    bool reachable = false;
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 3));
      reachable = (response.statusCode == 204 || response.statusCode == 200);
    } catch (_) {
      reachable = false;
    }

    if (!_hasInitialCheck) {
      _hasInitialCheck = true;
      _isOnline = reachable;
      if (!reachable) {
        _showOfflineBanner();
      }
      return;
    }

    // Transition from Online to Offline
    if (_isOnline && !reachable) {
      _isOnline = false;
      _showOfflineBanner();
    } 
    // Transition from Offline to Online
    else if (!_isOnline && reachable) {
      _isOnline = true;
      _showOnlineBanner();
    }
  }

  void _showOfflineBanner() {
    _currentBanner?.dismiss();
    _currentBanner = showOverlayNotification(
      (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No Internet Connection. Cached data is in effect.',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      duration: const Duration(seconds: 5),
    );
  }

  void _showOnlineBanner() {
    _currentBanner?.dismiss();
    _currentBanner = showOverlayNotification(
      (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Internet Connection Restored. Live sync active.',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      duration: const Duration(seconds: 3),
    );
  }
}
