import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../utils/messenger_snackbar.dart';
import '../widgets/chat_composer.dart';
import '../widgets/file_attachment.dart';
import '../widgets/message_body.dart';
import '../widgets/connection_banner.dart';
import '../widgets/upload_progress_banner.dart';

class _GroupListSnapshot {
  final List<GroupMessage> messages;
  final String? meId;
  final int fingerprint;

  const _GroupListSnapshot({
    required this.messages,
    required this.meId,
    required this.fingerprint,
  });

  @override
  bool operator ==(Object other) =>
      other is _GroupListSnapshot &&
      fingerprint == other.fingerprint &&
      meId == other.meId &&
      identical(messages, other.messages);

  @override
  int get hashCode => Object.hash(messages, meId, fingerprint);
}

int _groupFingerprint(List<GroupMessage> messages) {
  var h = messages.length;
  final start = messages.length > 8 ? messages.length - 8 : 0;
  for (var i = start; i < messages.length; i++) {
    final m = messages[i];
    h = Object.hash(h, m.uuid, m.text, m.fileId);
  }
  return h;
}

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _scrollCtrl = ScrollController();
  int _trackedCount = 0;
  int _trackedFingerprint = 0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  void _scheduleScroll(_GroupListSnapshot snap) {
    final count = snap.messages.length;
    final fp = snap.fingerprint;
    if (count == _trackedCount && fp == _trackedFingerprint) return;
    final grew = count > _trackedCount;
    final first = _trackedCount == 0 && count > 0;
    _trackedCount = count;
    _trackedFingerprint = fp;
    if (!grew && !first) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  void _send(String text) {
    context.read<AppState>().sendGroupMessage(text);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  Future<void> _showAddMember(BuildContext context) async {
    final usernameCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.mc;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Add member', style: TextStyle(color: c.primary)),
          content: TextField(
            controller: usernameCtrl,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Exact username from their profile',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    final username = usernameCtrl.text;
    usernameCtrl.dispose();
    if (added != true || !context.mounted) return;

    final state = context.read<AppState>();
    final error = await state.addGroupMemberByUsername(username);
    if (!context.mounted) return;
    if (error != null) {
      showMessengerSnackBar(context, error);
    } else {
      showMessengerSnackBar(context, 'Member added');
    }
  }

  Future<void> _attachFile() async {
    final state = context.read<AppState>();
    final ok = await state.sendGroupFileAttachment();
    if (!mounted) return;
    if (!ok && state.error != null) {
      showMessengerSnackBar(context, state.error!);
      state.clearError();
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  Future<void> _showMessageActions(GroupMessage message, bool isMe) async {
    messengerHapticSelection();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.text?.trim().isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
            if (!message.uuid.startsWith('local-'))
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () => Navigator.pop(sheetContext, 'delete_me'),
              ),
            if (isMe && !message.uuid.startsWith('local-'))
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.pop(sheetContext, 'delete_everyone'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text!.trim()));
      if (mounted) showMessengerSnackBar(context, 'Message copied');
      return;
    }
    context.read<AppState>().deleteGroupMessage(
          message,
          forEveryone: action == 'delete_everyone',
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final name = context.select<AppState, String?>((s) => s.activeGroupName);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(name ?? 'Group'),
        leading: IconButton(
          icon: PhosphorIcon(
            adaptiveBackIcon(context),
            size: adaptiveBackIconSize(context),
          ),
          onPressed: () {
            messengerHapticLight();
            context.read<AppState>().closeGroupChat();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorAssets.userAdd),
            tooltip: 'Add member',
            onPressed: () => _showAddMember(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'leave') return;
              final leave = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Leave group?'),
                  content: const Text(
                    'You will stop receiving messages from this group.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
              if (leave != true || !context.mounted) return;
              context.read<AppState>().leaveActiveGroup();
              Navigator.pop(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'leave', child: Text('Leave group')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Selector<AppState, ({bool connected, String? status})>(
            selector: (_, state) => (
              connected: state.chat.isConnected,
              status: state.chatStatus,
            ),
            builder: (_, connection, __) => ConnectionBanner(
              connected: connection.connected,
              message: connection.status,
            ),
          ),
          Selector<AppState, double?>(
            selector: (_, state) => state.uploadProgress,
            builder: (_, progress, __) =>
                UploadProgressBanner(progress: progress),
          ),
          Expanded(
            child: Selector<AppState, _GroupListSnapshot>(
              selector: (_, s) {
                final messages = s.getGroupMessages(s.activeGroupId ?? '');
                return _GroupListSnapshot(
                  messages: messages,
                  meId: s.me?.uuid,
                  fingerprint: _groupFingerprint(messages),
                );
              },
              builder: (context, snap, _) {
                _scheduleScroll(snap);
                if (snap.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No messages yet — say hello',
                        textAlign: TextAlign.center,
                        style:
                            AppTheme.text(c, color: c.secondary, fontSize: 14),
                      ),
                    ),
                  );
                }

                final maxW = MediaQuery.sizeOf(context).width * 0.78;
                final meId = snap.meId;

                return ListView.builder(
                  controller: _scrollCtrl,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  addAutomaticKeepAlives: false,
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.messages.length,
                  itemBuilder: (context, i) {
                    final msg = snap.messages[i];
                    final isMe = msg.senderId == meId;
                    return _GroupBubble(
                      key: ValueKey(msg.uuid),
                      message: msg,
                      isMe: isMe,
                      colors: c,
                      maxBubbleWidth: maxW,
                      senderName: isMe
                          ? null
                          : context
                              .read<AppState>()
                              .peerDisplayName(msg.senderId),
                      onLongPress: () => _showMessageActions(msg, isMe),
                    );
                  },
                );
              },
            ),
          ),
          ChatComposer(onSend: _send, onAttach: _attachFile),
        ],
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;
  final AppColors colors;
  final double maxBubbleWidth;
  final String? senderName;
  final VoidCallback? onLongPress;

  const _GroupBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.colors,
    required this.maxBubbleWidth,
    this.senderName,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? colors.bubbleOut : colors.bubbleIn,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 18),
                  ),
                  border: Border.all(
                    color:
                        isMe ? colors.bubbleOutBorder : colors.bubbleInBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName ??
                              (message.senderId.length > 8
                                  ? message.senderId.substring(0, 8)
                                  : message.senderId),
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (message.fileId != null && message.fileId!.isNotEmpty)
                      FileAttachment(
                        key: ValueKey('file-${message.fileId}'),
                        fileId: message.fileId!,
                        isMe: isMe,
                      ),
                    if (message.text != null && message.text!.trim().isNotEmpty)
                      MessageBody(
                        text: message.text,
                        colors: colors,
                        textStyle: TextStyle(
                          color: colors.primary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(color: colors.tertiary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
