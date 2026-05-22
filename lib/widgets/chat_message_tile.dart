import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
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
  final AppColors colors;
  final double maxBubbleWidth;

  const ChatMessageTile({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDate,
    this.animate = false,
    required this.colors,
    required this.maxBubbleWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Padding(
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
    );

    return RepaintBoundary(
      child: Column(
        children: [
          if (showDate) _DateDivider(date: message.createdAt, colors: colors),
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
      duration: const Duration(milliseconds: 200),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
          alignment:
              widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: widget.child,
        ),
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
      return PhosphorIcon(
        PhosphorAssets.checks,
        size: 12,
        color: colors.accent,
      );
    }
    if (status == 1) {
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
