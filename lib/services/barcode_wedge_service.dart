import 'package:flutter/services.dart';

typedef BarcodeScanCallback = void Function(String barcode);

/// Hardware Barcode Wedge Listener:
/// Captures rapid keystrokes from USB or Bluetooth Barcode Scanners (HID devices)
/// without requiring an active text field. Scanners typically send ASCII characters
/// terminated by the Enter key in <50ms.
class BarcodeWedgeService {
  static final BarcodeWedgeService _instance = BarcodeWedgeService._internal();
  factory BarcodeWedgeService() => _instance;
  BarcodeWedgeService._internal();

  final List<BarcodeScanCallback> _listeners = [];
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeystrokeTime;
  static const int _maxInterKeyDelayMs = 70; // Barcode scanners type very quickly

  void addListener(BarcodeScanCallback callback) {
    if (!_listeners.contains(callback)) {
      _listeners.add(callback);
    }
  }

  void removeListener(BarcodeScanCallback callback) {
    _listeners.remove(callback);
  }

  /// Call this from a Focus / KeyEvent listener on the root POS screen
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    if (_lastKeystrokeTime != null &&
        now.difference(_lastKeystrokeTime!).inMilliseconds > _maxInterKeyDelayMs) {
      // Too slow for a hardware scanner -> clear buffer
      _buffer.clear();
    }
    _lastKeystrokeTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      if (code.isNotEmpty && code.length >= 3) {
        _dispatchBarcode(code);
        return true; // Handled
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && RegExp(r'[a-zA-Z0-9\-_]').hasMatch(char)) {
      _buffer.write(char);
    }
    return false;
  }

  void _dispatchBarcode(String code) {
    for (final listener in List.of(_listeners)) {
      listener(code);
    }
  }

  /// Manually dispatch a code (e.g. from camera scanner fallback or test button)
  void dispatchManual(String code) {
    _dispatchBarcode(code);
  }
}
