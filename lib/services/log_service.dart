import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class LogEntry {
  final DateTime timestamp;
  final String level; // INFO, ERROR, HTTP, WS, DEBUG
  final String message;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

class LogService {
  /// Toggle controlled compile-time via ENABLE_DEVICE_LOGS in .env
  static bool get isEnabled => AppConfig.enableDeviceLogs;

  static final List<LogEntry> _logs = [];
  static final ValueNotifier<List<LogEntry>> logsNotifier = ValueNotifier([]);
  static const int _maxLogs = 500;

  /// NO READ when disabled in production
  static List<LogEntry> get logs =>
      isEnabled ? List.unmodifiable(_logs) : const [];

  /// NO WRITE when disabled in production
  static void addLog(String level, String message, [String? details]) {
    if (!isEnabled) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level.toUpperCase(),
      message: message,
      details: details,
    );

    _logs.insert(0, entry); // Newest first
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }

    logsNotifier.value = List.unmodifiable(_logs);
  }

  static void info(String message, [String? details]) {
    if (!isEnabled) return;
    addLog('INFO', message, details);
  }

  static void error(String message, [dynamic error, dynamic stackTrace]) {
    if (!isEnabled) return;
    final details = error != null
        ? 'Error: $error${stackTrace != null ? '\nStack: $stackTrace' : ''}'
        : null;
    addLog('ERROR', message, details);
  }

  static void http(String message, [String? details]) {
    if (!isEnabled) return;
    addLog('HTTP', message, details);
  }

  static void ws(String message, [String? details]) {
    if (!isEnabled) return;
    addLog('WS', message, details);
  }

  static void clear() {
    _logs.clear();
    logsNotifier.value = [];
  }

  /// NO READ when disabled in production
  static String exportText() {
    if (!isEnabled) return '';
    return _logs
        .map((e) =>
            '[${e.formattedTime}] [${e.level}] ${e.message}${e.details != null ? '\n  ${e.details}' : ''}')
        .join('\n');
  }
}
