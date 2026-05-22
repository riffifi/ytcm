class MessengerFileInfo {
  final String fileId;
  final String filename;
  final int originalSize;
  final int storedSize;
  final bool isCompressed;
  final String? mimeType;

  const MessengerFileInfo({
    required this.fileId,
    required this.filename,
    required this.originalSize,
    required this.storedSize,
    required this.isCompressed,
    this.mimeType,
  });

  factory MessengerFileInfo.fromJson(Map<String, dynamic> json) =>
      MessengerFileInfo(
        fileId: json['file_id'] as String,
        filename: json['filename'] as String,
        originalSize: (json['original_size'] as num).toInt(),
        storedSize: (json['stored_size'] as num).toInt(),
        isCompressed: json['is_compressed'] as bool? ?? false,
        mimeType: json['mime_type'] as String?,
      );

  bool get isImage {
    final mime = mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) return true;
    final lower = filename.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Map<String, dynamic> toJson() => {
        'file_id': fileId,
        'filename': filename,
        'original_size': originalSize,
        'stored_size': storedSize,
        'is_compressed': isCompressed,
        'mime_type': mimeType,
      };
}

class DownloadedFile {
  final String fileId;
  final String filename;
  final String? mimeType;
  final List<int> bytes;
  final String localPath;

  const DownloadedFile({
    required this.fileId,
    required this.filename,
    this.mimeType,
    required this.bytes,
    required this.localPath,
  });

  bool get isImage {
    final mime = mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) return true;
    final lower = filename.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}
