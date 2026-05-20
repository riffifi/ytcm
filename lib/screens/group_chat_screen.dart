import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../services/app_state.dart';
import '../services/locale_controller.dart';
import '../theme.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _hasText = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      setState(() => _hasText = _textCtrl.text.trim().isNotEmpty);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      final gid = state.activeGroupId;
      if (gid != null) state.requestGroupInfo(gid);
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
    if (_uploading || state.activeGroupId == null) return;
    setState(() => _uploading = true);
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
      await state.sendActiveGroupFile(
        bytes: bytes,
        filename: name,
        mimeType: mime,
        caption: _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim(),
      );
      _textCtrl.clear();
    } finally {
      if (mounted) setState(() => _uploading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _send() {
    final state = context.read<AppState>();
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    state.sendGroupText(text);
    _textCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final gid = state.activeGroupId ?? '';
    final messages = state.getGroupMessages(gid);
    final me = state.me;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () {
            state.closeGroupChat();
            Navigator.pop(context);
          },
        ),
        title: Text(state.activeGroupName ?? context.str('groups.title')),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(context.str('chat.no_messages'),
                        style: TextStyle(color: c.secondary)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == me?.uuid;
                      final showDate = i == 0 ||
                          !_sameDay(
                              messages[i - 1].createdAt, msg.createdAt);
                      return Column(
                        children: [
                          if (showDate)
                            _DateDivider(date: msg.createdAt),
                          _GroupBubble(
                            message: msg,
                            isMe: isMe,
                            meId: me?.uuid ?? '',
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _inputBar(context, state),
        ],
      ),
    );
  }

  Widget _inputBar(BuildContext context, AppState state) {
    final c = context.mc;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          8, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: c.secondary),
            onPressed: _uploading ? null : () => _pickAndSend(image: false),
          ),
          IconButton(
            icon: Icon(Icons.image_outlined, color: c.secondary),
            onPressed: _uploading ? null : () => _pickAndSend(image: true),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                style: TextStyle(color: c.primary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: context.str('chat.hint_message'),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
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
                  color: _hasText ? Colors.white : c.secondary,
                  size: 18,
                ),
                onPressed: _hasText ? _send : null,
              ),
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _GroupBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;
  final String meId;

  const _GroupBubble({
    required this.message,
    required this.isMe,
    required this.meId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? c.bubbleOut : c.bubbleIn,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMe ? c.bubbleOutBorder : c.bubbleInBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    message.senderId.length > 8
                        ? '${message.senderId.substring(0, 8)}…'
                        : message.senderId,
                    style: TextStyle(
                        color: c.accent, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                if (message.text != null && message.text!.trim().isNotEmpty)
                  Text(
                    message.text!,
                    style: TextStyle(color: c.primary, fontSize: 15),
                  ),
                if (message.fileId != null && message.fileId!.isNotEmpty)
                  _FileThumb(
                    fileId: message.fileId!,
                    state: context.read<AppState>(),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(color: c.tertiary, fontSize: 10),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.whoRead.length > 1
                            ? Icons.done_all
                            : Icons.done,
                        size: 11,
                        color: c.tertiary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileThumb extends StatelessWidget {
  final String fileId;
  final AppState state;

  const _FileThumb({required this.fileId, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FutureBuilder<Uint8List?>(
        future: state.downloadFileBytes(fileId),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return Row(
              children: [
                Icon(Icons.insert_drive_file, color: c.secondary, size: 28),
                const SizedBox(width: 6),
                Text(context.str('chat.attachment'),
                    style: TextStyle(color: c.secondary, fontSize: 13)),
              ],
            );
          }
          final bytes = snap.data!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, fit: BoxFit.cover, height: 120),
          );
        },
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = context.str('common.today');
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = context.str('common.yesterday');
    } else {
      label = DateFormat('MMMM d').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
