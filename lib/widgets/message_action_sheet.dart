import 'package:flutter/material.dart';

import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';
import 'phosphor_icon.dart';

enum MessageAction { copy, deleteForMe, deleteForEveryone }

Future<MessageAction?> showMessageActionSheet(
  BuildContext context, {
  required bool canCopy,
  required bool canDeleteForMe,
  required bool canDeleteForEveryone,
}) {
  return AppBottomSheet.show<MessageAction>(
    context,
    title: 'Message actions',
    builder: (context) {
      final c = context.mc;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            0,
            AppSpace.sm,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canCopy)
                _Action(
                  icon: PhosphorAssets.copy,
                  label: 'Copy text',
                  onTap: () => Navigator.pop(context, MessageAction.copy),
                ),
              if (canDeleteForMe)
                _Action(
                  icon: PhosphorAssets.trash,
                  label: 'Delete for me',
                  onTap: () =>
                      Navigator.pop(context, MessageAction.deleteForMe),
                ),
              if (canDeleteForEveryone)
                _Action(
                  icon: PhosphorAssets.trash,
                  label: 'Delete for everyone',
                  color: c.error,
                  onTap: () =>
                      Navigator.pop(context, MessageAction.deleteForEveryone),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _Action extends StatelessWidget {
  final String icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final fg = color ?? c.primary;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      leading: PhosphorIcon(icon, color: fg),
      title: Text(label, style: AppTheme.listTitle(c).copyWith(color: fg)),
      onTap: onTap,
    );
  }
}
