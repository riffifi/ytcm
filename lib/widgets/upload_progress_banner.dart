import 'package:flutter/material.dart';

import '../theme.dart';

class UploadProgressBanner extends StatelessWidget {
  final double? progress;

  const UploadProgressBanner({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final value = progress;
    if (value == null) return const SizedBox.shrink();
    final percent = (value * 100).round();
    return Container(
      color: context.mc.surfaceHigh,
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: context.mc.border,
                color: context.mc.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Uploading $percent%',
            style: TextStyle(color: context.mc.secondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
