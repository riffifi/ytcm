/// Matches file-service limits in messenger-main/file-service/config.toml.
class FileLimits {
  static const int imageLimitBytes = 4 * 1024 * 1024; // 4 MB
  static const int fileLimitBytes = 50 * 1024 * 1024; // 50 MB

  static const _imageMimes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static bool isImageMime(String mime) => _imageMimes.contains(mime.toLowerCase());

  static bool looksLikeImage(String filename, String mimeType) {
    if (mimeType.toLowerCase().startsWith('image/')) return true;
    final lower = filename.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  /// Returns a user-facing error, or null if the file may be uploaded.
  static String? validateUpload({
    required int sizeBytes,
    required String filename,
    required String mimeType,
  }) {
    final mime = mimeType.toLowerCase();
    final isImage = looksLikeImage(filename, mime);

    if (isImage) {
      if (!_imageMimes.contains(mime) && mime.startsWith('image/')) {
        return 'Unsupported image type. Use JPEG, PNG, WebP, or GIF.';
      }
      if (sizeBytes > imageLimitBytes) {
        return 'Image is too large (${_formatMb(sizeBytes)}). '
            'Maximum size is ${_formatMb(imageLimitBytes)}.';
      }
      return null;
    }

    if (sizeBytes > fileLimitBytes) {
      return 'File is too large (${_formatMb(sizeBytes)}). '
          'Maximum size is ${_formatMb(fileLimitBytes)}.';
    }
    return null;
  }

  static String _formatMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}
