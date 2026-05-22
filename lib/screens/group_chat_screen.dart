import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/messenger_haptics.dart';
import '../utils/messenger_snackbar.dart';
import '../widgets/chat_composer.dart';
import '../widgets/file_attachment.dart';
import '../widgets/message_body.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  void _send(String text) {
    context.read<AppState>().sendGroupMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _attachFile() async {
    final state = context.read<AppState>();
    final ok = await state.sendGroupFileAttachment();
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
    return Selector<AppState, ({List<GroupMessage> messages, String? name})>(
      selector: (_, s) => (
        messages: s.getGroupMessages(s.activeGroupId ?? ''),
        name: s.activeGroupName,
      ),
      builder: (context, data, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            title: Text(data.name ?? 'Group'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () {
                messengerHapticLight();
                context.read<AppState>().closeGroupChat();
                Navigator.pop(context);
              },
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: data.messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: c.secondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: data.messages.length,
                        itemBuilder: (context, i) {
                          final msg = data.messages[i];
                          final isMe =
                              msg.senderId == context.read<AppState>().me?.uuid;
                          return _GroupBubble(message: msg, isMe: isMe);
                        },
                      ),
              ),
              ChatComposer(onSend: _send, onAttach: _attachFile),
            ],
          ),
        );
      },
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;

  const _GroupBubble({required this.message, required this.isMe});

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
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderId.length > 8
                          ? message.senderId.substring(0, 8)
                          : message.senderId,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (message.fileId != null && message.fileId!.isNotEmpty)
                  FileAttachment(fileId: message.fileId!, isMe: isMe),
                if (message.text != null && message.text!.trim().isNotEmpty)
                  MessageBody(
                    text: message.text,
                    textStyle: TextStyle(
                      color: c.primary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(color: c.tertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
