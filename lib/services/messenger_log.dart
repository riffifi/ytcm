import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get label => name.toUpperCase();

  int get sortOrder {
    switch (this) {
      case LogLevel.error:
        return 0;
      case LogLevel.warn:
        return 1;
      case LogLevel.info:
        return 2;
      case LogLevel.debug:
        return 3;
    }
  }
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String message;
  final String category;

  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    required this.category,
  });

  String get timeLabel {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// In-app event log (status, errors, connection, uploads). Shown in the conversations header.
class MessengerLog extends ChangeNotifier {
  static const maxEntries = 500;

  final List<LogEntry> _entries = [];
  String? _banner;

  List<LogEntry> get entries => List.unmodifiable(_entries.reversed);
  String? get banner => _banner;
  bool get isEmpty => _entries.isEmpty;
  bool get hasErrors => _entries.any((e) => e.level == LogLevel.error);
  bool get hasWarnings => _entries.any((e) => e.level == LogLevel.warn);

  LogLevel? get bannerLevel {
    if (_entries.isEmpty) return null;
    return _entries.last.level;
  }

  /// Updates the one-line summary without creating a log entry.
  void setBanner(String? text) {
    final trimmed = text?.trim();
    _banner = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
  }

  void debug(String message, {String category = 'app', bool banner = false}) {
    _add(_entry(LogLevel.debug, message, category), showBanner: banner);
  }

  void info(String message, {String category = 'app', bool banner = true}) {
    _add(_entry(LogLevel.info, message, category), showBanner: banner);
  }

  void warn(String message, {String category = 'app', bool banner = true}) {
    _add(_entry(LogLevel.warn, message, category), showBanner: banner);
  }

  void error(String message, {String category = 'app', bool banner = true}) {
    _add(_entry(LogLevel.error, message, category), showBanner: banner);
  }

  LogEntry _entry(LogLevel level, String message, String category) => LogEntry(
        time: DateTime.now(),
        level: level,
        message: message.trim(),
        category: category,
      );

  void _add(LogEntry entry, {bool showBanner = false}) {
    if (entry.message.isEmpty) return;
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    if (showBanner) _banner = entry.message;
    if (kDebugMode) {
      debugPrint('[${entry.timeLabel}] ${entry.level.label} '
          '[${entry.category}] ${entry.message}');
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _banner = null;
    notifyListeners();
  }

  String exportText() {
    final buf = StringBuffer();
    for (final e in _entries) {
      buf.writeln('${e.time.toIso8601String()} ${e.level.label} '
          '[${e.category}] ${e.message}');
    }
    return buf.toString();
  }
}
