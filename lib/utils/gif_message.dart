/// Wire format for GIFs over text-only chat: `@gif <direct_url>`.
/// Other YTC clients can match this prefix and render the URL as media.
class GifMessage {
  GifMessage._();

  static final _encoded = RegExp(
    r'^@gif\s+(https?://\S+)\s*$',
    caseSensitive: false,
  );

  static final _bareGifUrl = RegExp(
    r'^https?://\S+\.(?:gif|webp|webm)(?:\?[^\s]*)?$',
    caseSensitive: false,
  );

  static final _knownCdn = RegExp(
    r'^https?://(?:'
    r'media\.tenor\.com|'
    r'c\.tenor\.com|'
    r'(?:media\d*\.)?giphy\.com|'
    r'i\.giphy\.com|'
    r'i\.gifer\.com|'
    r'uc\.gifer\.com'
    r')/\S+$',
    caseSensitive: false,
  );

  static String encode(String mediaUrl) => '@gif $mediaUrl';

  static bool isGifMessage(String? text) {
    final t = text?.trim();
    if (t == null || t.isEmpty) return false;
    if (_encoded.hasMatch(t)) return true;
    if (_bareGifUrl.hasMatch(t)) return true;
    return _knownCdn.hasMatch(t);
  }

  static String? mediaUrl(String? text) {
    final t = text?.trim();
    if (t == null || t.isEmpty) return null;
    final encoded = _encoded.firstMatch(t);
    if (encoded != null) return encoded.group(1);
    if (_bareGifUrl.hasMatch(t) || _knownCdn.hasMatch(t)) return t;
    return null;
  }

  static const previewLabel = 'GIF';

  /// Active `@gif query` at the cursor for inline search.
  static ({int start, String query})? atGifTrigger(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    final before = text.substring(0, cursor);
    final match = RegExp(r'@gif\s*(\S*)$').firstMatch(before);
    if (match == null) return null;
    return (start: match.start, query: match.group(1) ?? '');
  }
}
