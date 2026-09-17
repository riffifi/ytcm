import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../models/group_models.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'phosphor_icon.dart';
import 'file_attachment.dart';
import 'message_body.dart';

/// Single chat row — isolated repaint, stable [ValueKey] from parent.
class ChatMessageTile extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showDate;
  final bool animate;
  final bool startsSequence;
  final bool endsSequence;
  final AppColors colors;
  final double maxBubbleWidth;
  final VoidCallback? onLongPress;

  const ChatMessageTile({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDate,
    this.animate = false,
    this.startsSequence = true,
    this.endsSequence = true,
    required this.colors,
    required this.maxBubbleWidth,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Padding(
      padding: EdgeInsets.only(bottom: endsSequence ? AppSpace.md : 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: GestureDetector(
            onLongPress: onLongPress,
            child: ChatBubble(
              text: message.text,
              fileId: message.fileId,
              createdAt: message.createdAt,
              status: message.status == 2
                  ? MessageStatus.read
                  : message.status == 1
                      ? MessageStatus.sent
                      : MessageStatus.pending,
              isMe: isMe,
              startsSequence: startsSequence,
              endsSequence: endsSequence,
              colors: colors,
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Column(
        children: [
          if (showDate)
            ChatDateDivider(date: message.createdAt, colors: colors),
          if (animate)
            _MessageEnterAnimation(isMe: isMe, child: bubble)
          else
            bubble,
        ],
      ),
    );
  }
}

class GroupChatMessageTile extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;
  final bool showDate;
  final bool animate;
  final bool startsSequence;
  final bool endsSequence;
  final String? senderLabel;
  final AppColors colors;
  final double maxBubbleWidth;
  final VoidCallback? onLongPress;

  const GroupChatMessageTile({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDate,
    this.animate = false,
    this.startsSequence = true,
    this.endsSequence = true,
    this.senderLabel,
    required this.colors,
    required this.maxBubbleWidth,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = message.uuid.startsWith('local-')
        ? MessageStatus.pending
        : message.readBy.isNotEmpty
            ? MessageStatus.read
            : MessageStatus.sent;
    final bubble = Padding(
      padding: EdgeInsets.only(bottom: endsSequence ? AppSpace.md : 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: GestureDetector(
            onLongPress: onLongPress,
            child: ChatBubble(
              text: message.text,
              fileId: message.fileId,
              createdAt: message.createdAt,
              status: status,
              senderLabel: isMe ? null : senderLabel,
              startsSequence: startsSequence,
              endsSequence: endsSequence,
              isMe: isMe,
              colors: colors,
            ),
          ),
        ),
      ),
    );
    return RepaintBoundary(
      child: Column(
        children: [
          if (showDate)
            ChatDateDivider(date: message.createdAt, colors: colors),
          if (animate)
            _MessageEnterAnimation(isMe: isMe, child: bubble)
          else
            bubble,
        ],
      ),
    );
  }
}

/// Quick fade + slide when a new message appears.
class _MessageEnterAnimation extends StatefulWidget {
  final bool isMe;
  final Widget child;

  const _MessageEnterAnimation({
    required this.isMe,
    required this.child,
  });

  @override
  State<_MessageEnterAnimation> createState() => _MessageEnterAnimationState();
}

class _MessageEnterAnimationState extends State<_MessageEnterAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.enter,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: Offset(widget.isMe ? 0.06 : -0.06, 0.08),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: widget.child,
        ),
      ),
    );
  }
}

enum MessageStatus { pending, sent, read }

class ChatBubble extends StatelessWidget {
  final String? text;
  final String? fileId;
  final DateTime createdAt;
  final MessageStatus status;
  final String? senderLabel;
  final bool isMe;
  final bool startsSequence;
  final bool endsSequence;
  final AppColors colors;

  const ChatBubble({
    super.key,
    this.text,
    this.fileId,
    required this.createdAt,
    required this.status,
    this.senderLabel,
    required this.isMe,
    this.startsSequence = true,
    this.endsSequence = true,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(createdAt);
    final hasFile = fileId != null && fileId!.isNotEmpty;
    final cleanText = text?.trim();
    final hasText = cleanText != null && cleanText.isNotEmpty;

    final topInner = startsSequence ? AppRadius.lg : AppRadius.sm;
    final bottomTail = endsSequence ? AppRadius.tail : AppRadius.sm;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
      decoration: BoxDecoration(
        color: isMe ? colors.bubbleOut : colors.bubbleIn,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? AppRadius.lg : topInner),
          topRight: Radius.circular(isMe ? topInner : AppRadius.lg),
          bottomLeft: Radius.circular(isMe ? AppRadius.lg : bottomTail),
          bottomRight: Radius.circular(isMe ? bottomTail : AppRadius.lg),
        ),
        border: Border.all(
          color: isMe ? colors.bubbleOutBorder : colors.bubbleInBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderLabel != null && startsSequence) ...[
            Text(
              senderLabel!,
              style: AppTheme.caption(colors, color: colors.accent),
            ),
            const SizedBox(height: AppSpace.xs),
          ],
          if (hasFile) ...[
            FileAttachment(
              key: ValueKey('file-$fileId'),
              fileId: fileId!,
              isMe: isMe,
            ),
            if (hasText) const SizedBox(height: 6),
          ],
          if (hasText)
            MessageBody(
              text: text,
              colors: colors,
              textStyle: AppTheme.text(colors, fontSize: 15, height: 1.4),
            ),
          if (hasText) const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: AppTheme.timestamp(
                  colors,
                  color: isMe
                      ? colors.primary.withValues(alpha: .58)
                      : colors.tertiary,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _StatusIcon(status: status, colors: colors),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final AppColors colors;

  const _StatusIcon({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (status == MessageStatus.read) {
      return PhosphorIcon(
        PhosphorAssets.checks,
        size: 12,
        color: colors.accent,
      );
    }
    if (status == MessageStatus.sent) {
      return PhosphorIcon(
        PhosphorAssets.checks,
        size: 12,
        color: colors.tertiary,
      );
    }
    return PhosphorIcon(
      PhosphorAssets.clock,
      size: 10,
      color: colors.tertiary,
    );
  }
}

class ChatDateDivider extends StatelessWidget {
  final DateTime date;
  final AppColors colors;

  const ChatDateDivider({super.key, required this.date, required this.colors});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (DateTime(now.year, now.month, now.day)
            .difference(DateTime(date.year, date.month, date.day))
            .inDays ==
        1) {
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
              style: AppTheme.timestamp(colors),
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

bool messagesFormSequence({
  required String firstSenderId,
  required DateTime firstCreatedAt,
  required String secondSenderId,
  required DateTime secondCreatedAt,
}) =>
    firstSenderId == secondSenderId &&
    sameChatDay(firstCreatedAt, secondCreatedAt) &&
    secondCreatedAt.difference(firstCreatedAt).abs() <=
        const Duration(minutes: 5);

/// Animate only small batches of new messages (not full history load).
bool shouldAnimateChatMessage({
  required Message message,
  required int index,
  required int messageCount,
  required int previousCount,
}) {
  if (message.uuid.startsWith('local-')) return true;
  final added = messageCount - previousCount;
  if (added <= 0) return false;
  if (added > 4) return false;
  return index >= messageCount - added;
}
