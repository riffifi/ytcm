import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme.dart';
import 'file_attachment.dart';
import 'message_body.dart';

/// Single chat row — isolated repaint, stable [ValueKey] from parent.
class ChatMessageTile extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showDate;
  final AppColors colors;
  final double maxBubbleWidth;

  const ChatMessageTile({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDate,
    required this.colors,
    required this.maxBubbleWidth,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        children: [
          if (showDate) _DateDivider(date: message.createdAt, colors: colors),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: _Bubble(
                  message: message,
                  isMe: isMe,
                  colors: colors,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final AppColors colors;

  const _Bubble({
    required this.message,
    required this.isMe,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt);
    final hasFile =
        message.fileId != null && message.fileId!.isNotEmpty;
    final text = message.text?.trim();
    final hasText = text != null && text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? colors.bubbleOut : colors.bubbleIn,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 18),
        ),
        border: Border.all(
          color: isMe ? colors.bubbleOutBorder : colors.bubbleInBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasFile) ...[
            FileAttachment(
              key: ValueKey('file-${message.fileId}'),
              fileId: message.fileId!,
              isMe: isMe,
            ),
            if (hasText) const SizedBox(height: 6),
          ],
          if (hasText)
            MessageBody(
              text: message.text,
              colors: colors,
              textStyle: TextStyle(
                color: colors.primary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          if (hasText) const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(color: colors.tertiary, fontSize: 10),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _StatusIcon(status: message.status, colors: colors),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final int status;
  final AppColors colors;

  const _StatusIcon({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (status == 2) {
      return Icon(Icons.done_all, size: 12, color: colors.accent);
    }
    if (status == 1) {
      return Icon(Icons.done_all, size: 12, color: colors.tertiary);
    }
    return Icon(Icons.access_time, size: 10, color: colors.tertiary);
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  final AppColors colors;

  const _DateDivider({required this.date, required this.colors});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String label;
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
          Expanded(child: Divider(color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: colors.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.border)),
        ],
      ),
    );
  }
}

int chatMessageFingerprint(List<Message> messages, {String? meId}) {
  var h = messages.length;
  if (meId != null) {
    var pending = 0;
    for (final m in messages) {
      if (m.senderId != meId && m.status < 2) pending++;
    }
    h = Object.hash(h, pending);
  }
  final start = messages.length > 12 ? messages.length - 12 : 0;
  for (var i = start; i < messages.length; i++) {
    final m = messages[i];
    h = Object.hash(h, m.uuid, m.status, m.text, m.fileId);
  }
  return h;
}

bool sameChatDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
