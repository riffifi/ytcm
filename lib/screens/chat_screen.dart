import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
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

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      setState(() => _hasText = _textCtrl.text.trim().isNotEmpty);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

  void _send() {
    final state = context.read<AppState>();
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    state.sendMessage(text);
    _textCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final messages = state.getMessages(state.activeChatUserId ?? '');
    final me = state.me;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(context, state),
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
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, AppState state) {
    final c = context.mc;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18),
        onPressed: () {
          state.closeChat();
          Navigator.pop(context);
        },
      ),
      title: Row(
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
          Text(state.activeChatUsername ?? '',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.waving_hand_outlined,
              color: c.secondary, size: 32),
          const SizedBox(height: 12),
          Text('Say hi to $username',
              style: TextStyle(
                  color: c.secondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final c = context.mc;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: c.primary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.only(bottom: 4),
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
                color: isMe
                    ? c.bubbleOutBorder
                    : c.bubbleInBorder,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.previewText.isNotEmpty)
                  Text(
                    message.previewText,
                    style: TextStyle(
                        color: c.primary, fontSize: 15, height: 1.4),
                  ),
                if (message.previewText.isNotEmpty) const SizedBox(height: 4),
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
