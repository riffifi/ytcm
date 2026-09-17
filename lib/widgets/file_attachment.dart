import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../models/messenger_file.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'phosphor_icon.dart';
import '../utils/chat_image.dart';
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
  String? _error;
  String? _localPath;
  MessengerFileInfo? _meta;
  bool _cacheLookupDone = false;

  @override
  void initState() {
    super.initState();
    _meta = context.read<AppState>().fileMetadata(widget.fileId);
    _loadCachedPath();
  }

  Future<void> _loadCachedPath() async {
    final state = context.read<AppState>();
    final meta = _meta ?? state.fileMetadata(widget.fileId);
    if (meta == null) {
      state.prefetchFileMetadata(widget.fileId);
      if (mounted) setState(() => _cacheLookupDone = true);
      return;
    }
    _meta ??= meta;
    final path = await state.cachedFilePath(widget.fileId, meta.filename);
    if (!mounted) return;
    setState(() {
      _localPath = path;
      _cacheLookupDone = true;
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
        _localPath = file.localPath;
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
    if (_localPath == null) {
      await _download();
      if (_localPath == null) return;
    }
    final result = await OpenFilex.open(_localPath!);
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
    final meta = _meta;
    final filename = meta?.filename ?? 'Attachment';
    final isImage =
        _localPath != null && (meta?.isImage ?? _looksLikeImage(filename));

    if (isImage && _localPath != null) {
      return GestureDetector(
        onTap: _open,
        child: ChatImage.file(_localPath!, c),
      );
    }

    return GestureDetector(
      onTap: _localPath != null ? _open : _download,
      child: _fileTile(c, filename),
    );
  }

  bool _looksLikeImage(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Widget _fileTile(AppColors c, String filename) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            widget.isMe ? Colors.white.withValues(alpha: 0.08) : c.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: widget.isMe ? c.bubbleOutBorder : c.borderSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            _loading ? PhosphorAssets.hourglass : PhosphorAssets.file,
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
                  style: AppTheme.listTitle(c).copyWith(
                      color: widget.isMe ? Colors.white : c.primary,
                      fontSize: 14),
                ),
                Text(
                  _loading
                      ? 'Downloading…'
                      : _localPath != null
                          ? 'Tap to open'
                          : _cacheLookupDone
                              ? 'Tap to download'
                              : 'Loading…',
                  style: AppTheme.timestamp(c,
                      color: widget.isMe ? Colors.white60 : c.secondary),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.timestamp(c, color: c.error),
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
