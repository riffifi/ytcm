import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact chat header title row that scales on narrow screens.
class ChatAppBarTitle extends StatelessWidget {
  final String name;
  final String initial;

  const ChatAppBarTitle({
    super.key,
    required this.name,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: c.accentSoft,
          child: Text(
            initial,
            style: TextStyle(
              color: c.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.primary,
              letterSpacing: -0.3,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
