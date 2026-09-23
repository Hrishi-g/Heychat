import 'package:flutter/foundation.dart';

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
  static final List<LogEntry> _logs = [];
  static final ValueNotifier<List<LogEntry>> logsNotifier = ValueNotifier([]);
  static const int _maxLogs = 500;

  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static void addLog(String level, String message, [String? details]) {
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

    // Terminal printing silenced to keep console clean (accessible in-app via Logs screen)
    // if (kDebugMode) {
    //   print('[${entry.level}] ${entry.formattedTime} - ${entry.message}');
    //   if (details != null && details.isNotEmpty) {
    //     print('  Details: $details');
    //   }
    // }
  }

  static void info(String message, [String? details]) {
    addLog('INFO', message, details);
  }

  static void error(String message, [dynamic error, dynamic stackTrace]) {
    final details = error != null
        ? 'Error: $error${stackTrace != null ? '\nStack: $stackTrace' : ''}'
        : null;
    addLog('ERROR', message, details);
  }

  static void http(String message, [String? details]) {
    addLog('HTTP', message, details);
  }

  static void ws(String message, [String? details]) {
    addLog('WS', message, details);
  }

  static void clear() {
    _logs.clear();
    logsNotifier.value = [];
  }

  static String exportText() {
    return _logs
        .map((e) =>
            '[${e.formattedTime}] [${e.level}] ${e.message}${e.details != null ? '\n  ${e.details}' : ''}')
        .join('\n');
  }
}
