import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../services/notification_preferences.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../screens/chat_screen.dart';
import '../utils/platform_ui.dart';
import 'app_bottom_sheet.dart';

bool conversationContextMenuIsDesktop(BuildContext context) {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

/// Long-press (mobile) shows preview; right-click (desktop) does not.
Future<void> showConversationContextMenu({
  required BuildContext context,
  required ConversationPeer peer,
  required String preview,
  Offset? globalPosition,
}) async {
  final showPreview = !conversationContextMenuIsDesktop(context);
  final state = context.read<AppState>();
  final notifPrefs = context.read<NotificationPreferences>();
  final c = context.mc;
  final unread = state.getUnreadCount(peer.userId);

  if (showPreview) {
    messengerHapticMedium();
    await AppBottomSheet.show<void>(
      context,
      title: 'Chat options',
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewCard(
                  peer: peer,
                  preview: preview,
                  unread: unread,
                ),
                const SizedBox(height: 8),
                _MenuActions(
                  peer: peer,
                  unread: unread,
                  notifEnabled: notifPrefs.enabled,
                  onClose: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
      },
    );
    return;
  }

  final position = globalPosition ?? _defaultMenuPosition(context);
  final value = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    color: c.surfaceHigh,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm)),
    items: _desktopMenuItems(
      c: c,
      unread: unread,
      notifEnabled: notifPrefs.enabled,
    ),
  );
  if (value == null || !context.mounted) return;
  if (value == 'notif') {
    await notifPrefs.setEnabled(!notifPrefs.enabled);
    return;
  }
  _handleMenuSelection(context, peer, unread, value);
}

Offset _defaultMenuPosition(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  final offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
  return offset + const Offset(48, 48);
}

void _handleMenuSelection(
  BuildContext context,
  ConversationPeer peer,
  int unread,
  Object? value,
) {
  final state = context.read<AppState>();
  switch (value) {
    case 'open':
      messengerHapticLight();
      state.openChat(peer.userId, peer.username);
      if (!isWideLayout(context)) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
      break;
    case 'read':
      if (unread > 0) {
        state.markPeerRead(peer.userId);
      }
      break;
    case 'notif':
      break;
  }
}

List<PopupMenuEntry<String>> _desktopMenuItems({
  required AppColors c,
  required int unread,
  required bool notifEnabled,
}) {
  return [
    PopupMenuItem<String>(
      value: 'open',
      child: Text('Open chat', style: AppTheme.listTitle(c)),
    ),
    if (unread > 0)
      PopupMenuItem<String>(
        value: 'read',
        child: Text('Mark as read', style: AppTheme.listTitle(c)),
      ),
    if (NotificationPreferences.isMobilePlatform)
      PopupMenuItem<String>(
        value: 'notif',
        child: Text(
          notifEnabled ? 'Turn off notifications' : 'Turn on notifications',
          style: AppTheme.listTitle(c),
        ),
      ),
  ];
}

class _PreviewCard extends StatelessWidget {
  final ConversationPeer peer;
  final String preview;
  final int unread;

  const _PreviewCard({
    required this.peer,
    required this.preview,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final initial =
        peer.username.isNotEmpty ? peer.username[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: c.accentSoft,
            child: Text(
              initial,
              style: AppTheme.listTitle(c).copyWith(color: c.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        peer.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.listTitle(c, emphasized: true),
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: AppTheme.timestamp(c, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  preview.isNotEmpty ? preview : 'No messages yet',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption(c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuActions extends StatelessWidget {
  final ConversationPeer peer;
  final int unread;
  final bool notifEnabled;
  final VoidCallback onClose;

  const _MenuActions({
    required this.peer,
    required this.unread,
    required this.notifEnabled,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final notifPrefs = context.read<NotificationPreferences>();

    return Column(
      children: [
        _ActionRow(
          icon: PhosphorAssets.chat,
          label: 'Open chat',
          onTap: () {
            onClose();
            _handleMenuSelection(context, peer, unread, 'open');
          },
        ),
        if (unread > 0)
          _ActionRow(
            icon: PhosphorAssets.checks,
            label: 'Mark as read',
            onTap: () {
              onClose();
              _handleMenuSelection(context, peer, unread, 'read');
            },
          ),
        if (NotificationPreferences.isMobilePlatform)
          _ActionRow(
            icon: notifEnabled
                ? PhosphorAssets.bellOff
                : PhosphorAssets.bellRinging,
            label: notifEnabled
                ? 'Turn off notifications'
                : 'Turn on notifications',
            onTap: () async {
              onClose();
              await notifPrefs.setEnabled(!notifEnabled);
            },
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              PhosphorIcon(icon, color: c.secondary, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTheme.listTitle(c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
