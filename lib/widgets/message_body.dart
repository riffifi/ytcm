import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/chat_image.dart';
import '../utils/gif_message.dart';

/// Renders plain text or a GIF from the `@gif <url>` wire format.
class MessageBody extends StatelessWidget {
  final String? text;
  final TextStyle? textStyle;
  final AppColors colors;

  const MessageBody({
    super.key,
    required this.text,
    required this.colors,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final url = GifMessage.mediaUrl(text);
    if (url != null) {
      return ChatImage.network(url, colors);
    }

    final t = text?.trim();
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Text(
      t,
      style: textStyle ?? AppTheme.text(colors, fontSize: 15, height: 1.4),
    );
  }
}
