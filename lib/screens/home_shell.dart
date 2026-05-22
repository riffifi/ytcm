import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'settings_screen.dart';

/// Root after login: mobile stack or desktop master–detail.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String? _selectedPeerId;

  void _selectPeer(ConversationPeer peer) {
    final state = context.read<AppState>();
    state.openChat(peer.userId, peer.username);
    setState(() => _selectedPeerId = peer.userId);
  }

  void _clearSelection() {
    context.read<AppState>().closeChat();
    setState(() => _selectedPeerId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!isWideLayout(context)) {
      return const ConversationsScreen();
    }

    final c = context.mc;
    final activeId = context.select<AppState, String?>(
      (s) => s.activeChatUserId,
    );
    final showChat = (activeId ?? _selectedPeerId) != null;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _NewChatIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: true):
            _OpenSettingsIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CloseChatIntent(),
      },
      child: Actions(
        actions: {
          _NewChatIntent: CallbackAction<_NewChatIntent>(
            onInvoke: (_) {
              ConversationsScreen.showNewChatModal(context);
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              return null;
            },
          ),
          _CloseChatIntent: CallbackAction<_CloseChatIntent>(
            onInvoke: (_) {
              if (showChat) _clearSelection();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: c.bg,
            body: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: ConversationsScreen(
                    selectionMode: true,
                    selectedPeerId: activeId ?? _selectedPeerId,
                    onPeerSelected: _selectPeer,
                  ),
                ),
                Container(width: 1, color: c.border),
                Expanded(
                  child: showChat
                      ? ChatScreen(
                          embedded: true,
                          onClose: _clearSelection,
                        )
                      : const _DesktopEmptyPane(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopEmptyPane extends StatelessWidget {
  const _DesktopEmptyPane();

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: c.border),
          const SizedBox(height: 16),
          Text(
            'Select a conversation',
            style: TextStyle(
              color: c.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ctrl+N — new chat   ·   Ctrl+, — settings',
            style: TextStyle(color: c.tertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NewChatIntent extends Intent {
  const _NewChatIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _CloseChatIntent extends Intent {
  const _CloseChatIntent();
}
