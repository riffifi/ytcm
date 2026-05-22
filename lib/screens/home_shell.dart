import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
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

class _HomeShellState extends State<HomeShell> implements Intents {
  String? _selectedPeerId;

  @override
  Intent get newChat => const _NewChatIntent();

  @override
  Intent get settings => const _OpenSettingsIntent();

  @override
  Intent get closeChat => const _CloseChatIntent();

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

    if (activeId != null && activeId != _selectedPeerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && activeId == context.read<AppState>().activeChatUserId) {
          setState(() => _selectedPeerId = activeId);
        }
      });
    }

    final showChat = (activeId ?? _selectedPeerId) != null;

    return Shortcuts(
      shortcuts: desktopShortcuts(this),
      child: Actions(
        actions: {
          _NewChatIntent: CallbackAction<_NewChatIntent>(
            onInvoke: (_) {
              ConversationsScreen.showNewChatModal(
                context,
                onPeerSelected: _selectPeer,
              );
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
                      : _DesktopEmptyPane(
                          onNewChat: () => ConversationsScreen.showNewChatModal(
                            context,
                            onPeerSelected: _selectPeer,
                          ),
                        ),
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
  final VoidCallback onNewChat;

  const _DesktopEmptyPane({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(PhosphorAssets.chat, size: 48, color: c.border),
            const SizedBox(height: 16),
            Text(
              'Select a conversation',
              style: AppTheme.text(c, fontSize: 16, wght: AppFontWeight.medium),
            ),
            const SizedBox(height: 8),
            Text(
              desktopShortcutHint(context),
              textAlign: TextAlign.center,
              style: AppTheme.text(
                c,
                color: c.tertiary,
                fontSize: 12,
                wght: 450,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNewChat,
              icon: const PhosphorIcon(
                PhosphorAssets.edit,
                color: Colors.white,
                size: 18,
              ),
              label: const Text('New chat'),
            ),
          ],
        ),
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
