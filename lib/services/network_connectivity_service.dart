import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance =
      NetworkConnectivityService._internal();
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Professional charcoal/slate background
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFF87171),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No internet connection. Cached data is in effect.',
                  style: TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      position: NotificationPosition.bottom,
      duration: const Duration(seconds: 5),
    );
  }

  void _showOnlineBanner() {
    _currentBanner?.dismiss();
    _currentBanner = showOverlayNotification(
      (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Professional slate/charcoal background
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  color: Color(0xFF34D399),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Connection restored. Live sync active.',
                  style: TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      position: NotificationPosition.bottom,
      duration: const Duration(seconds: 3),
    );
  }
}