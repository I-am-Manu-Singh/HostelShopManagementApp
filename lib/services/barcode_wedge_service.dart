import 'package:flutter/services.dart';

typedef BarcodeScanCallback = void Function(String barcode);

/// Hardware Barcode Wedge Listener:
/// Captures rapid keystrokes from USB or Bluetooth Barcode Scanners (HID devices)
/// without requiring an active text field. Scanners typically send ASCII characters
/// terminated by the Enter key.
class BarcodeWedgeService {
  static final BarcodeWedgeService _instance = BarcodeWedgeService._internal();
  factory BarcodeWedgeService() => _instance;
  BarcodeWedgeService._internal() {
    _initGlobalHardwareKeyboardListener();
  }

  final List<BarcodeScanCallback> _listeners = [];
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeystrokeTime;
  // USB dongles, 2.4GHz receivers, and Bluetooth HID scanners often have inter-key latencies up to 150ms
  static const int _maxInterKeyDelayMs = 160;
  bool _isGlobalHookAttached = false;

  void _initGlobalHardwareKeyboardListener() {
    if (_isGlobalHookAttached) return;
    _isGlobalHookAttached = true;
    HardwareKeyboard.instance.addHandler(_onGlobalKeyEvent);
  }

  void addListener(BarcodeScanCallback callback) {
    if (!_listeners.contains(callback)) {
      _listeners.add(callback);
    }
  }

  void removeListener(BarcodeScanCallback callback) {
    _listeners.remove(callback);
  }

  bool _onGlobalKeyEvent(KeyEvent event) {
    return handleKeyEvent(event);
  }

  /// Handles key events from Focus, KeyboardListener, or global HardwareKeyboard
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    if (_lastKeystrokeTime != null &&
        now.difference(_lastKeystrokeTime!).inMilliseconds > _maxInterKeyDelayMs) {
      // Delay exceeded between characters -> clear buffer to start fresh scan
      _buffer.clear();
    }
    _lastKeystrokeTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      if (code.isNotEmpty && code.length >= 2) {
        _dispatchBarcode(code);
        return true; // Handled
      }
      return false;
    }

    // Capture character from event.character or logicalKey label
    String? char = event.character;
    if (char == null || char.isEmpty) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.tab) {
        // Some barcode scanners are configured to send Tab instead of Enter
        final code = _buffer.toString().trim();
        _buffer.clear();
        if (code.isNotEmpty && code.length >= 2) {
          _dispatchBarcode(code);
          return true;
        }
        return false;
      }
      // Check digit keys
      if (key.keyId >= LogicalKeyboardKey.digit0.keyId && key.keyId <= LogicalKeyboardKey.digit9.keyId) {
        char = String.fromCharCode(48 + (key.keyId - LogicalKeyboardKey.digit0.keyId));
      } else if (key.keyId >= LogicalKeyboardKey.numpad0.keyId && key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
        char = String.fromCharCode(48 + (key.keyId - LogicalKeyboardKey.numpad0.keyId));
      }
    }

    if (char != null && char.isNotEmpty && RegExp(r'[a-zA-Z0-9\-_./@#]').hasMatch(char)) {
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

