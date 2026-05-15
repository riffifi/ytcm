/// Parses timestamps from the Rust/Postgres messenger backend.
DateTime parseServerTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }

  var s = value.toString().trim();
  if (s.isEmpty) return DateTime.now();

  // "2024-05-15 10:30:45.123+00" → ISO-like form for DateTime.parse
  if (RegExp(r'^\d{4}-\d{2}-\d{2} \d').hasMatch(s)) {
    s = s.replaceFirst(' ', 'T');
  }

  // "+00" / "-05" at end → "+00:00"
  if (RegExp(r'[+-]\d{2}$').hasMatch(s)) {
    s = '$s:00';
  }

  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    // Strip fractional seconds and retry
    final simplified = s.replaceFirst(RegExp(r'\.\d+'), '');
    try {
      return DateTime.parse(simplified).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}
