import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/locale_controller.dart';
import '../models/models.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _hasText = false;
  bool _uploading = false;
  Uint8List? _pendingBytes;
  String? _pendingFilename;
  String? _pendingMime;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      setState(() => _hasText = _textCtrl.text.trim().isNotEmpty);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      final id = state.activeChatUserId;
      if (id != null) state.refreshPresence(id);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAndSend({required bool image}) async {
    final state = context.read<AppState>();
    if (_uploading || (state.activeChatUserId == null && state.activeGroupId == null)) return;
    // just pick and store pending attachment; actual upload+send will happen on _send
    try {
      Uint8List? bytes;
      String name = 'file';
      String mime = 'application/octet-stream';
      if (image) {
        final x = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (x == null) return;
        bytes = await x.readAsBytes();
        name = x.name;
        mime = 'image/jpeg';
      } else {
        final r = await FilePicker.platform.pickFiles(withData: true);
        if (r == null || r.files.isEmpty) return;
        final f = r.files.first;
        bytes = f.bytes;
        name = f.name;
        mime = 'application/octet-stream';
      }
      if (bytes == null) return;
      setState(() {
        _pendingBytes = bytes;
        _pendingFilename = name;
        _pendingMime = mime;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {}
  }

  void _send() {
    final state = context.read<AppState>();
    final text = _textCtrl.text.trim();
    // If there is a pending attachment, upload it first and send together
    if (_pendingBytes != null) {
      if (!chatReady(state)) return;
      setState(() => _uploading = true);
      final bytes = _pendingBytes!;
      final name = _pendingFilename ?? 'file';
      final mime = _pendingMime ?? 'application/octet-stream';
      _pendingBytes = null;
      _pendingFilename = null;
      _pendingMime = null;
      () async {
        try {
          if (state.activeChatUserId != null) {
            await state.sendActiveDmFile(
              bytes: bytes,
              filename: name,
              mimeType: mime,
              caption: text.isEmpty ? null : text,
            );
          } else if (state.activeGroupId != null) {
            await state.sendActiveGroupFile(
              bytes: bytes,
              filename: name,
              mimeType: mime,
              caption: text.isEmpty ? null : text,
            );
          }
        } finally {
          if (mounted) setState(() => _uploading = false);
          if (mounted) setState(() => _textCtrl.clear());
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      }();
      return;
    }

    if (text.isEmpty) return;
    state.sendMessage(text);
    _textCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  bool chatReady(AppState state) => state.chat.isConnected;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final messages = state.getMessages(state.activeChatUserId ?? '');
    final me = state.me;
    final peerId = state.activeChatUserId;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final sub = peerId == null
        ? ''
        : state.presenceSubtitle(
            peerId,
            onlineLabel: context.str('presence.online'),
            lastSeenTemplate: context.str('presence.last_seen'),
            unknownLabel: context.str('presence.unknown'),
          );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(context, state, sub),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _emptyState(context, state.activeChatUsername ?? '')
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == me?.uuid;
                      final showDate = i == 0 ||
                          !_sameDay(messages[i - 1].createdAt, msg.createdAt);
                      return Column(
                        children: [
                          if (showDate)
                            _DateDivider(
                              screenContext: context,
                              date: msg.createdAt,
                            ),
                          _MessageBubble(
                            screenContext: context,
                            message: msg,
                            isMe: isMe,
                            state: state,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputBar(context, state),
        ],
      ),
    );
  }

    PreferredSizeWidget _buildAppBar(
      BuildContext context, AppState state, String subtitle) {
    final c = context.mc;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18),
        onPressed: () {
          state.closeChat();
          Navigator.pop(context);
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    (state.activeChatUsername ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                        color: c.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.activeChatUsername ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: TextStyle(
                color: c.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String username) {
    final c = context.mc;
    final t = context.str('chat.say_hi').replaceAll('{name}', username);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.waving_hand_outlined,
              color: c.secondary, size: 32),
          const SizedBox(height: 12),
          Text(t,
              style: TextStyle(
                  color: c.secondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, AppState state) {
    final c = context.mc;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(8, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.attach_file, color: c.secondary),
                onPressed: _uploading ? null : () => _pickAndSend(image: false),
              ),
              IconButton(
                icon: Icon(Icons.image_outlined, color: c.secondary),
                onPressed: _uploading ? null : () => _pickAndSend(image: true),
              ),
            ],
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingBytes != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file, size: 18, color: c.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pendingFilename ?? 'attachment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.primary),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: c.tertiary),
                            onPressed: () => setState(() {
                              _pendingBytes = null;
                              _pendingFilename = null;
                              _pendingMime = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: c.primary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: context.str('chat.hint_message'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_uploading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _hasText ? c.accent : c.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: (_hasText || _pendingBytes != null) ? Colors.white : c.secondary,
                  size: 18,
                ),
                onPressed: (_hasText || _pendingBytes != null) ? _send : null,
              ),
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MessageBubble extends StatelessWidget {
  final BuildContext screenContext;
  final Message message;
  final bool isMe;
  final AppState state;

  const _MessageBubble({
    required this.screenContext,
    required this.message,
    required this.isMe,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final c = screenContext.mc;
    final progress = state.getUploadProgress(message.uuid);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onLongPress: () => _onLongPress(context),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isMe ? c.bubbleOut : c.bubbleIn,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: Border.all(
                color: isMe ? c.bubbleOutBorder : c.bubbleInBorder,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.text != null && message.text!.trim().isNotEmpty)
                  Text(
                    message.text!,
                    style: TextStyle(
                        color: c.primary, fontSize: 15, height: 1.4),
                  ),
                if (message.fileId != null && message.fileId!.isNotEmpty)
                  _DmFileThumb(fileId: message.fileId!, state: state),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 160,
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: progress, color: c.accent, backgroundColor: c.surfaceHigh),
                    ),
                  ),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(
                          color: c.tertiary, fontSize: 10),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(
                        screenContext: screenContext,
                        status: message.status,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.forward),
              title: Text(screenContext.str('common.ok') == 'OK' ? 'Forward' : 'Forward'),
              onTap: () {
                Navigator.pop(ctx);
                _showForwardModal(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showForwardModal(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var starting = false;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (context, setState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: InputDecoration(hintText: 'Username'),
                    autofocus: true,
                    onSubmitted: (_) async {
                      if (starting) return;
                      setState(() => starting = true);
                      final state = context.read<AppState>();
                      final resolved = await state.resolvePeer(ctrl.text.trim());
                      if (resolved == null) {
                        setState(() => starting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not found')));
                        return;
                      }
                      await state.forwardMessage(message: message, toUserId: resolved.peerId);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(context.str('common.cancel')))),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton(onPressed: () async {
                      if (starting) return;
                      setState(() => starting = true);
                      final state = context.read<AppState>();
                      final resolved = await state.resolvePeer(ctrl.text.trim());
                      if (resolved == null) {
                        setState(() => starting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not found')));
                        return;
                      }
                      await state.forwardMessage(message: message, toUserId: resolved.peerId);
                      Navigator.pop(ctx);
                    }, child: Text('Forward'))),
                  ])
                ],
              ),
            ),
          )),
        );
      }
    );
  }
}

class _DmFileThumb extends StatelessWidget {
  final String fileId;
  final AppState state;

  const _DmFileThumb({required this.fileId, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FutureBuilder<Uint8List?>(
        future: state.downloadFileBytes(fileId),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null || (snap.data is Uint8List && (snap.data as Uint8List).isEmpty)) {
            return Row(
              children: [
                Icon(Icons.insert_drive_file, color: c.secondary, size: 28),
                const SizedBox(width: 6),
                Text(context.str('chat.attachment'),
                    style: TextStyle(color: c.secondary, fontSize: 13)),
              ],
            );
          }
          final data = snap.data!;
          // improved image type detection (jpg/png/gif/webp/svg/bmp)
          bool isImage = false;
          String ext = 'bin';
          if (data.length >= 12) {
            // JPEG
            if (data[0] == 0xFF && data[1] == 0xD8) {
              isImage = true;
              ext = 'jpg';
            }
            // PNG
            else if (data[0] == 0x89 && data[1] == 0x50) {
              isImage = true;
              ext = 'png';
            }
            // GIF
            else if (data[0] == 0x47 && data[1] == 0x49) {
              isImage = true;
              ext = 'gif';
            }
            // WebP: "RIFF....WEBP"
            else if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 && data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50) {
              isImage = true;
              ext = 'webp';
            }
            // BMP 'BM'
            else if (data[0] == 0x42 && data[1] == 0x4D) {
              isImage = true;
              ext = 'bmp';
            }
          }
          // SVG detection: text-based starting with '<' and containing 'svg'
          if (!isImage) {
            final s = String.fromCharCodes(data.take(256));
            if (s.trimLeft().startsWith('<') && s.contains('<svg')) {
              isImage = true;
              ext = 'svg';
            }
          }

          if (isImage) {
            return GestureDetector(
              onTap: () async {
                // open full screen preview with download
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) {
                  return Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () async {
                            final name = 'image_$fileId.' + ext;
                            final saved = await state.saveBytesToDevice(data, name);
                            final messenger = ScaffoldMessenger.of(context);
                            if (saved != null) {
                              messenger.showSnackBar(SnackBar(content: Text('Saved to: $saved')));
                            } else {
                              messenger.showSnackBar(SnackBar(content: Text('Save failed')));
                            }
                          },
                        ),
                      ],
                    ),
                    body: Center(
                      child: InteractiveViewer(
                        child: Image.memory(data, fit: BoxFit.contain),
                      ),
                    ),
                  );
                }));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  data,
                  fit: BoxFit.cover,
                  height: 240,
                  width: MediaQuery.of(context).size.width * 0.72,
                ),
              ),
            );
          }

          // non-image file: show file tile with download
          return Row(
            children: [
              Icon(Icons.insert_drive_file, color: c.secondary, size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fileId, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.primary)),
              ),
              IconButton(
                icon: Icon(Icons.download, color: c.accent),
                onPressed: () async {
                  final name = 'file_$fileId.' + ext;
                  final saved = await state.saveBytesToDevice(data, name);
                  final messenger = ScaffoldMessenger.of(context);
                  if (saved != null) {
                    messenger.showSnackBar(SnackBar(content: Text('Saved to: $saved')));
                  } else {
                    messenger.showSnackBar(SnackBar(content: Text('Save failed')));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final BuildContext screenContext;
  final int status;
  const _StatusIcon({required this.screenContext, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = screenContext.mc;
    if (status == 2) {
      return Icon(Icons.done_all, size: 12, color: c.accent);
    } else if (status == 1) {
      return Icon(Icons.done_all, size: 12, color: c.tertiary);
    } else {
      return Icon(Icons.access_time, size: 10, color: c.tertiary);
    }
  }
}

class _DateDivider extends StatelessWidget {
  final BuildContext screenContext;
  final DateTime date;
  const _DateDivider({required this.screenContext, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = screenContext.mc;
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = screenContext.str('common.today');
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = screenContext.str('common.yesterday');
    } else {
      label = DateFormat('MMMM d').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(
                    color: c.tertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: c.border)),
        ],
      ),
    );
  }
}
