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
      duration: const Duration(milliseconds: 180),
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
                      style: TextStyle(
                        color: context.mc.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
