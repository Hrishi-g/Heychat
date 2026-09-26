import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppConfig stores global configuration constants such as Backend URLs and
/// UI theme colors.
class AppConfig {
  // Compile-time environment variable injected via --dart-define-from-file=.env
  static const String _defaultHost = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const bool enableDeviceLogs = bool.fromEnvironment(
    'ENABLE_DEVICE_LOGS',
    defaultValue: true,
  );

  static String _host = _defaultHost;

  static String get host => _host;

  /// Load persisted host from SharedPreferences on app startup.
  /// If none has been manually saved, keep the compile-time default.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('server_host');
      if (saved != null && saved.trim().isNotEmpty) {
        _host = saved.trim();
      }
    } catch (_) {
      // Retain _defaultHost on error
    }
  }

  /// Update the server host and persist it
  static Future<void> setHost(String newHost) async {
    _host = newHost.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_host', _host);
    } catch (_) {}
  }

  static String get baseUrl {
    final h = _host.trim();
    if (h.startsWith('http://') || h.startsWith('https://')) return h;
    if (h.contains('onrender.com')) {
      return 'https://$h';
    }
    return 'http://$h';
  }

  static String get wsUrl {
    final h = _host.trim();
    if (h.startsWith('ws://') || h.startsWith('wss://')) return h;
    if (h.startsWith('http://')) return h.replaceFirst('http://', 'ws://');
    if (h.startsWith('https://')) return h.replaceFirst('https://', 'wss://');
    if (h.contains('onrender.com')) {
      return 'wss://$h';
    }
    return 'ws://$h';
  }

  // Brand Theme Colors
  static const Color brandLime = Color(0xFFD4F933);
  static const Color brandLimeLight = Color(0xFFF3FDCB);
  static const Color brandLimeDark = Color(0xFF536B00);
  static const Color brandDark = Color(0xFF1A1D20);
  static const Color cardGrey = Color(0xFFF1F3F5);
  static const Color lightBg = Color(0xFFF8F9FA);

  // Modern Light Theme aliases
  static const Color primaryTeal = Color(0xFF1A1D20);
  static const Color darkTeal = Color(0xFF2D3238);
  static const Color lightGreen = Color(0xFFD4F933);
  static const Color chatBackground = Color(0xFFF4F5F7);
  static const Color sentBubbleGreen = Color(0xFFEBFAB6);
  static const Color receivedBubbleWhite = Color(0xFFFFFFFF);
}
