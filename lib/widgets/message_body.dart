import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/gif_message.dart';

/// Renders plain text or a GIF from the `@gif <url>` wire format.
class MessageBody extends StatelessWidget {
  final String? text;
  final TextStyle? textStyle;

  const MessageBody({
    super.key,
    required this.text,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final url = GifMessage.mediaUrl(text);
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260, maxHeight: 220),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 140,
                alignment: Alignment.center,
                color: c.surfaceHigh,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.accent,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              color: c.surfaceHigh,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gif_box_outlined, color: c.secondary, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    GifMessage.previewLabel,
                    style: TextStyle(color: c.secondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.tertiary, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final t = text?.trim();
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Text(
      t,
      style: textStyle ?? TextStyle(color: c.primary, fontSize: 15, height: 1.4),
    );
  }
}
