import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../icons/phosphor_assets.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../screens/chat_screen.dart';

/// Layout breakpoint for master–detail (desktop / tablet landscape).
const wideLayoutBreakpoint = 900.0;

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool isWideLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
}

bool useDesktopChrome(BuildContext context) =>
    isDesktopPlatform || isWideLayout(context);

String adaptiveBackIcon(BuildContext context) =>
    useDesktopChrome(context) ? PhosphorAssets.arrowLeft : PhosphorAssets.back;

double adaptiveBackIconSize(BuildContext context) =>
    useDesktopChrome(context) ? 22 : 18;

/// Opens a DM — master–detail on wide layouts, push route on phone.
void openChatInApp(
  BuildContext context, {
  required String peerId,
  required String username,
  ValueChanged<ConversationPeer>? onPeerSelected,
}) {
  context.read<AppState>().openChat(peerId, username);
  final peer = ConversationPeer(userId: peerId, username: username);
  if (isWideLayout(context)) {
    onPeerSelected?.call(peer);
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ChatScreen()),
  );
}

/// Ctrl/Cmd+N and Ctrl/Cmd+, (desktop master–detail).
Map<ShortcutActivator, Intent> desktopShortcuts(Intents intents) => {
      SingleActivator(LogicalKeyboardKey.keyN, control: true): intents.newChat,
      SingleActivator(LogicalKeyboardKey.keyN, meta: true): intents.newChat,
      SingleActivator(LogicalKeyboardKey.comma, control: true): intents.settings,
      SingleActivator(LogicalKeyboardKey.comma, meta: true): intents.settings,
      SingleActivator(LogicalKeyboardKey.escape): intents.closeChat,
    };

abstract class Intents {
  Intent get newChat;
  Intent get settings;
  Intent get closeChat;
}

String desktopShortcutHint(BuildContext context) {
  if (!isDesktopPlatform) return 'Ctrl+N — new chat';
  return Platform.isMacOS
      ? '⌘N — new chat   ·   ⌘, — settings'
      : 'Ctrl+N — new chat   ·   Ctrl+, — settings';
}
