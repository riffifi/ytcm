import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
import '../widgets/connection_banner.dart';
import '../widgets/upload_progress_banner.dart';
import '../widgets/user_avatar.dart';
import '../widgets/chat_message_tile.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/app_components.dart';
import 'group_details_screen.dart';

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
          title: Text('Add member', style: AppTheme.appBarTitle(c)),
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
    final action = await showMessageActionSheet(
      context,
      canCopy: message.text?.trim().isNotEmpty == true,
      canDeleteForMe: !message.uuid.startsWith('local-'),
      canDeleteForEveryone: isMe && !message.uuid.startsWith('local-'),
    );
    if (!mounted || action == null) return;
    if (action == MessageAction.copy) {
      await Clipboard.setData(ClipboardData(text: message.text!.trim()));
      if (mounted) showMessengerSnackBar(context, 'Message copied');
      return;
    }
    context.read<AppState>().deleteGroupMessage(
          message,
          forEveryone: action == MessageAction.deleteForEveryone,
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final name = context.select<AppState, String?>((s) => s.activeGroupName);
    final group = context.select<AppState, ChatGroup?>((s) {
      final id = s.activeGroupId;
      for (final item in s.groups) {
        if (item.uuid == id) return item;
      }
      return null;
    });

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 4,
        title: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GroupDetailsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  avatarFileId: group?.avatarId,
                  initials: name ?? 'G',
                  radius: 19,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Group',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.appBarTitle(c),
                      ),
                      Text(
                        group?.isChannel == true ? 'Channel' : 'Group',
                        style: AppTheme.text(
                          c,
                          color: c.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
                  return EmptyState(
                    icon: group?.isChannel == true
                        ? PhosphorAssets.megaphone
                        : PhosphorAssets.groups,
                    title: 'Start the conversation',
                    message:
                        'Messages shared here reach everyone in the ${group?.isChannel == true ? 'channel' : 'group'}.',
                  );
                }

                final maxW = MediaQuery.sizeOf(context).width * 0.78;
                final meId = snap.meId;

                return ListView.builder(
                  controller: _scrollCtrl,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  addAutomaticKeepAlives: false,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  itemCount: snap.messages.length,
                  itemBuilder: (context, i) {
                    final msg = snap.messages[i];
                    final isMe = msg.senderId == meId;
                    final showDate = i == 0 ||
                        !sameChatDay(
                          snap.messages[i - 1].createdAt,
                          msg.createdAt,
                        );
                    final startsSequence = i == 0 ||
                        !messagesFormSequence(
                          firstSenderId: snap.messages[i - 1].senderId,
                          firstCreatedAt: snap.messages[i - 1].createdAt,
                          secondSenderId: msg.senderId,
                          secondCreatedAt: msg.createdAt,
                        );
                    final endsSequence = i == snap.messages.length - 1 ||
                        !messagesFormSequence(
                          firstSenderId: msg.senderId,
                          firstCreatedAt: msg.createdAt,
                          secondSenderId: snap.messages[i + 1].senderId,
                          secondCreatedAt: snap.messages[i + 1].createdAt,
                        );
                    return GroupChatMessageTile(
                      key: ValueKey(msg.uuid),
                      message: msg,
                      isMe: isMe,
                      showDate: showDate,
                      startsSequence: startsSequence,
                      endsSequence: endsSequence,
                      animate: msg.uuid.startsWith('local-') ||
                          (i >= snap.messages.length - 4 &&
                              DateTime.now()
                                      .difference(msg.createdAt)
                                      .inSeconds <
                                  3),
                      colors: c,
                      maxBubbleWidth: maxW,
                      senderLabel: isMe
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
