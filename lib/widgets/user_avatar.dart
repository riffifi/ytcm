import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../services/app_state.dart';
import '../theme.dart';
import 'dart:io';

/// Circle avatar from file-service id or initials fallback.
class UserAvatar extends StatefulWidget {
  final String? avatarFileId;
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final ValueChanged<Uint8List>? onImageLoaded;

  const UserAvatar({
    super.key,
    this.avatarFileId,
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.onImageLoaded,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _localPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarFileId != widget.avatarFileId) {
      _localPath = null;
      _load();
    }
  }

  Future<void> _load() async {
    final fileId = widget.avatarFileId;
    if (fileId == null || fileId.isEmpty) return;

    final state = context.read<AppState>();
    var meta = state.fileMetadata(fileId);
    meta ??= await state.ensureFileMetadata(fileId);
    if (!mounted) return;
    if (meta == null) {
      setState(() => _loading = false);
      return;
    }

    final cached = await state.cachedFilePath(fileId, meta.filename);
    if (cached != null && mounted) {
      if (widget.onImageLoaded != null) {
        try {
          final bytes = await File(cached).readAsBytes();
          if (mounted) widget.onImageLoaded!(bytes);
        } catch (_) {
          // Color extraction is optional; avatar rendering can continue.
        }
      }
      if (!mounted) return;
      setState(() {
        _localPath = cached;
        _loading = false;
      });
      return;
    }

    if (_loading) return;
    setState(() => _loading = true);
    try {
      final downloaded = await state.downloadFile(fileId);
      if (!mounted) return;
      widget.onImageLoaded?.call(Uint8List.fromList(downloaded.bytes));
      setState(() {
        _localPath = downloaded.localPath;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final bg = widget.backgroundColor ?? c.accentSoft;
    final path = _localPath;

    if (path != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        child: ClipOval(
          child: Image.file(
            File(path),
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
        ),
      );
    }

    final normalized = widget.initials.trim();
    final words = normalized.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final label = words.isEmpty
        ? '?'
        : words.length > 1
            ? '${words.first[0]}${words.elementAt(1)[0]}'.toUpperCase()
            : normalized
                .substring(0, normalized.length.clamp(1, 2))
                .toUpperCase();

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg,
      child: _loading
          ? SizedBox(
              width: widget.radius,
              height: widget.radius,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.accent,
              ),
            )
          : Text(
              label,
              style: AppTheme.text(c,
                  color: c.accent,
                  fontSize: widget.radius * 0.72,
                  wght: AppFontWeight.semibold),
            ),
    );
  }
}
