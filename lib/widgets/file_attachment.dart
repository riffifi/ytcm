import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../models/messenger_file.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/messenger_snackbar.dart';

class FileAttachment extends StatefulWidget {
  final String fileId;
  final bool isMe;

  const FileAttachment({
    super.key,
    required this.fileId,
    required this.isMe,
  });

  @override
  State<FileAttachment> createState() => _FileAttachmentState();
}

class _FileAttachmentState extends State<FileAttachment> {
  bool _loading = false;
  bool _initialized = false;
  String? _error;
  DownloadedFile? _downloaded;
  MessengerFileInfo? _meta;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _meta = context.read<AppState>().fileMetadata(widget.fileId);
    _tryLoadCached();
    context.read<AppState>().prefetchFileMetadata(widget.fileId);
  }

  Future<void> _tryLoadCached() async {
    final state = context.read<AppState>();
    final meta = _meta ?? state.fileMetadata(widget.fileId);
    if (meta == null) return;
    final path = await state.cachedFilePath(widget.fileId, meta.filename);
    if (!mounted || path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _downloaded = DownloadedFile(
        fileId: widget.fileId,
        filename: meta.filename,
        mimeType: meta.mimeType,
        bytes: bytes,
        localPath: path,
      );
    });
  }

  Future<void> _download() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      final file = await state.downloadFile(widget.fileId);
      if (!mounted) return;
      setState(() {
        _downloaded = file;
        _meta = state.fileMetadata(widget.fileId) ?? _meta;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _open() async {
    final path = _downloaded?.localPath;
    if (path == null) {
      await _download();
      if (_downloaded?.localPath == null) return;
    }
    final result = await OpenFilex.open(_downloaded!.localPath);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      showMessengerSnackBar(
        context,
        result.message.isNotEmpty ? result.message : 'Could not open file',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final meta = _meta ?? context.read<AppState>().fileMetadata(widget.fileId);
    final filename = meta?.filename ?? 'Attachment';
    final isImage = _downloaded?.isImage == true || (meta?.isImage ?? false);

    if (_downloaded != null && isImage) {
      return GestureDetector(
        onTap: _open,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 220),
            child: Image.file(
              File(_downloaded!.localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fileTile(c, filename),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _downloaded != null ? _open : _download,
      child: _fileTile(c, filename),
    );
  }

  Widget _fileTile(AppColors c, String filename) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.08)
            : c.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe ? c.bubbleOutBorder : c.borderSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _loading ? Icons.hourglass_top : Icons.insert_drive_file_outlined,
            color: widget.isMe ? Colors.white70 : c.accent,
            size: 28,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : c.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _loading
                      ? 'Downloading…'
                      : _downloaded != null
                          ? 'Tap to open'
                          : 'Tap to download',
                  style: TextStyle(
                    color: widget.isMe ? Colors.white60 : c.secondary,
                    fontSize: 11,
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.error, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.isMe ? Colors.white70 : c.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
