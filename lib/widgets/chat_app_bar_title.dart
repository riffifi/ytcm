import 'package:flutter/material.dart';

import '../theme.dart';
import 'user_avatar.dart';

/// Compact chat header title row that scales on narrow screens.
class ChatAppBarTitle extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String initial;
  final String? avatarFileId;
  final bool online;
  final VoidCallback? onTap;

  const ChatAppBarTitle({
    super.key,
    required this.name,
    this.subtitle,
    required this.initial,
    this.avatarFileId,
    this.online = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;

    final row = Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              avatarFileId: avatarFileId,
              initials: initial,
              radius: 16,
            ),
            if (online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
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
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: online ? c.success : c.tertiary,
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}
