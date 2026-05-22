import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/messenger_haptics.dart';
import '../widgets/chat_app_bar_title.dart';
import '../widgets/chat_composer.dart';
import '../widgets/file_attachment.dart';
import '../widgets/message_body.dart';
import '../utils/messenger_snackbar.dart';

class _ChatViewData {
  final List<Message> messages;
  final UserInfo? me;
  final String? peerId;
  final String? peerName;

  const _ChatViewData({
    required this.messages,
    required this.me,
    required this.peerId,
    required this.peerName,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollCtrl = ScrollController();
  bool _showScrollDown = false;
  int _lastMessageCount = 0;

  static const _scrollDownThreshold = 72.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset <
        _scrollDownThreshold;
    if (atBottom != !_showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollCtrl.hasClients) return;
    final target = _scrollCtrl.position.maxScrollExtent;
    if (jump) {
      _scrollCtrl.jumpTo(target);
      return;
    }
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _maybeScrollForNewMessages(int count) {
    if (count == _lastMessageCount) return;
    final grew = count > _lastMessageCount;
    final firstLoad = _lastMessageCount == 0;
    _lastMessageCount = count;
    if (!grew && !firstLoad) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (firstLoad || !_showScrollDown) {
        _scrollToBottom(jump: firstLoad);
      }
    });
  }

  void _send(String text) {
    context.read<AppState>().sendMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _attachFile() async {
    final state = context.read<AppState>();
    final ok = await state.sendFileAttachment();
    if (!mounted) return;
    if (!ok && state.error != null) {
      showMessengerSnackBar(context, state.error!);
      state.clearError();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;

    return Selector<AppState, _ChatViewData>(
      selector: (_, state) => _ChatViewData(
        messages: state.getMessages(state.activeChatUserId ?? ''),
        me: state.me,
        peerId: state.activeChatUserId,
        peerName: state.activeChatUsername,
      ),
      builder: (context, data, _) {
        _maybeScrollForNewMessages(data.messages.length);

        return Scaffold(
          backgroundColor: c.bg,
          appBar: _buildAppBar(context, data.peerName ?? 'Chat'),
          body: Column(
            children: [
              Expanded(
                child: data.messages.isEmpty
                    ? _emptyState(context, data.peerName ?? '')
                    : Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          ListView.builder(
                            controller: _scrollCtrl,
                            cacheExtent: 500,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: data.messages.length,
                            itemBuilder: (context, i) {
                              final msg = data.messages[i];
                              final isMe = msg.senderId == data.me?.uuid;
                              final showDate = i == 0 ||
                                  !_sameDay(
                                    data.messages[i - 1].createdAt,
                                    msg.createdAt,
                                  );
                              return RepaintBoundary(
                                child: Column(
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
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          _ScrollDownFab(
                            visible: _showScrollDown,
                            onPressed: () {
                              messengerHapticLight();
                              _scrollToBottom();
                            },
                          ),
                        ],
                      ),
              ),
              ChatComposer(onSend: _send, onAttach: _attachFile),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, String name) {
    final c = context.mc;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      toolbarHeight: 52,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: c.secondary),
        onPressed: () {
          messengerHapticLight();
          context.read<AppState>().closeChat();
          Navigator.pop(context);
        },
      ),
      title: ChatAppBarTitle(name: name, initial: initial),
    );
  }

  Widget _emptyState(BuildContext context, String username) {
    final c = context.mc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.waving_hand_outlined, color: c.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Say hi to $username',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.primary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Messages are delivered when they come online',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.secondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
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
  const _MessageBubble({
    required this.screenContext,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final c = screenContext.mc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(screenContext).size.width * 0.78,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 18),
              ),
            ),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? c.bubbleOut : c.bubbleIn,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 18),
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
                if (message.fileId != null &&
                    message.fileId!.isNotEmpty) ...[
                  FileAttachment(
                    fileId: message.fileId!,
                    isMe: isMe,
                  ),
                  if (message.text != null &&
                      message.text!.trim().isNotEmpty)
                    const SizedBox(height: 6),
                ],
                if (message.text != null &&
                    message.text!.trim().isNotEmpty) ...[
                  MessageBody(
                    text: message.text,
                    textStyle: TextStyle(
                      color: c.primary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
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
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
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

class _ScrollDownFab extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const _ScrollDownFab({
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: visible ? 1 : 0.85,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: c.surface,
              elevation: 2,
              shadowColor: c.primary.withValues(alpha: 0.12),
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
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: c.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
