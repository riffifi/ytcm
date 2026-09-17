import 'package:flutter/material.dart';

import '../theme.dart';

class ConnectionBanner extends StatelessWidget {
  final bool connected;
  final String? message;

  const ConnectionBanner({
    super.key,
    required this.connected,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.base,
      curve: Curves.easeOut,
      child: connected
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              color: context.mc.accent.withValues(alpha: 0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: context.mc.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message ?? 'Reconnecting… Messages will be queued.',
                      textAlign: TextAlign.center,
                      style: AppTheme.caption(context.mc,
                          color: context.mc.accent),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
