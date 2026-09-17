import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../utils/platform_ui.dart';
import '../utils/messenger_snackbar.dart';
import '../widgets/chat_app_bar_title.dart';
import 'user_profile_screen.dart';
import '../widgets/chat_composer.dart';
import '../utils/scroll_utils.dart';
import '../widgets/chat_message_tile.dart';
import '../widgets/connection_banner.dart';
import '../widgets/upload_progress_banner.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/app_components.dart';

class _ChatListSnapshot {
  final List<Message> messages;
  final String? meId;
  final int fingerprint;

  const _ChatListSnapshot({
    required this.messages,
    required this.meId,
    required this.fingerprint,
  });

  @override
  bool operator ==(Object other) =>
      other is _ChatListSnapshot &&
      fingerprint == other.fingerprint &&
      meId == other.meId &&
      identical(messages, other.messages);

  @override
  int get hashCode => Object.hash(messages, meId, fingerprint);
}

class ChatScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onClose;

  const ChatScreen({
    super.key,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollCtrl = ScrollController();
  int _trackedCount = 0;
  int _trackedFingerprint = 0;

  /// Message count before the current frame (for enter animations).
  int _previousMessageCount = 0;
  bool _scrollPending = false;

  static const scrollDownThreshold = 72.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _isNearBottom =>
      !scrollShowsDownFab(_scrollCtrl, scrollDownThreshold);

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollCtrl.hasClients) return;
    final positions = _scrollCtrl.positions;
    if (positions.isEmpty || !positions.last.hasContentDimensions) return;
    final target = positions.last.maxScrollExtent;
    if (jump) {
      _scrollCtrl.jumpTo(target);
      return;
    }
    _scrollCtrl.animateTo(
      target,
      duration: AppMotion.base,
      curve: Curves.easeOutCubic,
    );
  }

  void _scheduleScrollIfNeeded(_ChatListSnapshot snap) {
    final count = snap.messages.length;
    final fp = snap.fingerprint;
    if (count == _trackedCount && fp == _trackedFingerprint) {
      _previousMessageCount = count;
      return;
    }

    _previousMessageCount = _trackedCount;
    final grew = count > _trackedCount;
    final firstLoad = _trackedCount == 0 && count > 0;
    _trackedCount = count;
    _trackedFingerprint = fp;

    if (!grew && !firstLoad) return;
    if (_scrollPending) return;
    _scrollPending = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollPending = false;
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (firstLoad || _isNearBottom) {
        _scrollToBottom(jump: firstLoad);
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final state = context.read<AppState>();
    if (!state.chat.isConnected) {
      showMessengerSnackBar(
        context,
        'Connecting… your message will send when ready',
      );
    }
    state.sendMessage(text);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  Future<void> _attachFile() async {
    final state = context.read<AppState>();
    final ok = await state.sendFileAttachment();
    if (!mounted) return;
    if (!ok && state.error != null) {
      showMessengerSnackBar(context, state.error!);
      state.clearError();
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  Future<void> _showMessageActions(Message message, bool isMe) async {
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
    context.read<AppState>().deleteMessage(
          message,
          forEveryone: action == MessageAction.deleteForEveryone,
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final peerId = context.select<AppState, String?>(
      (s) => s.activeChatUserId,
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(context, c, peerId),
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
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Selector<AppState, _ChatListSnapshot>(
                  selector: (_, state) {
                    final messages =
                        state.getMessages(state.activeChatUserId ?? '');
                    return _ChatListSnapshot(
                      messages: messages,
                      meId: state.me?.uuid,
                      fingerprint: chatMessageFingerprint(
                        messages,
                        meId: state.me?.uuid,
                      ),
                    );
                  },
                  builder: (context, snap, _) {
                    _scheduleScrollIfNeeded(snap);

                    if (snap.messages.isEmpty) {
                      final name = peerId != null
                          ? context.read<AppState>().peerDisplayName(peerId)
                          : '';
                      return _emptyState(name);
                    }

                    final maxW = MediaQuery.sizeOf(context).width * 0.78;
                    final meId = snap.meId;

                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        ListView.builder(
                          controller: _scrollCtrl,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          addAutomaticKeepAlives: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
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
                                  firstCreatedAt:
                                      snap.messages[i - 1].createdAt,
                                  secondSenderId: msg.senderId,
                                  secondCreatedAt: msg.createdAt,
                                );
                            final endsSequence =
                                i == snap.messages.length - 1 ||
                                    !messagesFormSequence(
                                      firstSenderId: msg.senderId,
                                      firstCreatedAt: msg.createdAt,
                                      secondSenderId:
                                          snap.messages[i + 1].senderId,
                                      secondCreatedAt:
                                          snap.messages[i + 1].createdAt,
                                    );
                            return ChatMessageTile(
                              key: ValueKey(msg.uuid),
                              message: msg,
                              isMe: isMe,
                              showDate: showDate,
                              startsSequence: startsSequence,
                              endsSequence: endsSequence,
                              animate: shouldAnimateChatMessage(
                                message: msg,
                                index: i,
                                messageCount: snap.messages.length,
                                previousCount: _previousMessageCount,
                              ),
                              colors: c,
                              maxBubbleWidth: maxW,
                              onLongPress: () => _showMessageActions(msg, isMe),
                            );
                          },
                        ),
                        _ScrollDownFab(
                          controller: _scrollCtrl,
                          onPressed: () {
                            messengerHapticLight();
                            _scrollToBottom();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          ChatComposer(onSend: _send, onAttach: _attachFile),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, AppColors c, String? peerId) {
    final state = context.watch<AppState>();
    final id = peerId ?? '';
    final name = id.isNotEmpty ? state.peerDisplayName(id) : 'Chat';
    final profile = id.isNotEmpty ? state.peerProfile(id) : null;
    final initial =
        profile?.initials ?? (name.isNotEmpty ? name[0].toUpperCase() : '?');
    final extras = state.peerExtras(id);
    final online = state.isPeerOnline(id);

    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      toolbarHeight: 66,
      leading: widget.embedded
          ? (widget.onClose != null
              ? IconButton(
                  icon: PhosphorIcon(
                    PhosphorAssets.close,
                    size: 22,
                    color: c.secondary,
                  ),
                  onPressed: () {
                    messengerHapticLight();
                    widget.onClose!();
                  },
                )
              : null)
          : IconButton(
              icon: PhosphorIcon(
                adaptiveBackIcon(context),
                size: adaptiveBackIconSize(context),
                color: c.secondary,
              ),
              onPressed: () {
                messengerHapticLight();
                context.read<AppState>().closeChat();
                Navigator.pop(context);
              },
            ),
      title: ChatAppBarTitle(
        name: name,
        subtitle: online ? 'Online' : '@${state.peerUsername(id)}',
        initial: initial,
        avatarFileId: extras.avatarFileId,
        online: online,
        onTap: id.isEmpty
            ? null
            : () {
                messengerHapticSelection();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(peerId: id),
                  ),
                );
              },
      ),
    );
  }

  Widget _emptyState(String username) {
    return EmptyState(
      icon: PhosphorAssets.handWave,
      title: 'Say hi to $username',
      message: 'Messages are delivered when they come online.',
    );
  }
}

class _ScrollDownFab extends StatelessWidget {
  final ScrollController controller;
  final VoidCallback onPressed;

  const _ScrollDownFab({
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = scrollShowsDownFab(
          controller,
          _ChatScreenState.scrollDownThreshold,
        );

        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: AppMotion.fast,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: c.surface,
                elevation: 2,
                shadowColor: c.primary.withValues(alpha: 0.1),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    child: PhosphorIcon(
                      PhosphorAssets.caretDown,
                      size: 22,
                      color: c.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
