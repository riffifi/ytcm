import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../utils/platform_ui.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Root after login: mobile stack or desktop master–detail.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> implements Intents {
  String? _selectedPeerId;
  int _mobileIndex = 0;

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
      return Scaffold(
        body: IndexedStack(
          index: _mobileIndex,
          children: const [
            ConversationsScreen(inShell: true),
            GroupsScreen(embedded: true),
            ProfileScreen(embedded: true),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _mobileIndex,
          onDestinationSelected: (index) {
            messengerHapticSelection();
            setState(() => _mobileIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.chat, size: 22),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.groups, size: 22),
              label: 'Groups',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.user, size: 22),
              label: 'You',
            ),
          ],
        ),
      );
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
                NavigationRail(
                  selectedIndex: _mobileIndex,
                  onDestinationSelected: (index) {
                    messengerHapticSelection();
                    setState(() => _mobileIndex = index);
                  },
                  backgroundColor: c.surface,
                  indicatorColor: c.accentSoft,
                  labelType: NavigationRailLabelType.all,
                  minWidth: 82,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: PhosphorIcon(PhosphorAssets.chat, size: 22),
                      label: Text('Chats'),
                    ),
                    NavigationRailDestination(
                      icon: PhosphorIcon(PhosphorAssets.groups, size: 22),
                      label: Text('Groups'),
                    ),
                    NavigationRailDestination(
                      icon: PhosphorIcon(PhosphorAssets.user, size: 22),
                      label: Text('You'),
                    ),
                  ],
                ),
                Container(width: 1, color: c.borderSoft),
                Expanded(
                  child: IndexedStack(
                    index: _mobileIndex,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 370,
                            child: ConversationsScreen(
                              selectionMode: true,
                              inShell: true,
                              selectedPeerId: activeId ?? _selectedPeerId,
                              onPeerSelected: _selectPeer,
                            ),
                          ),
                          Container(width: 1, color: c.borderSoft),
                          Expanded(
                            child: showChat
                                ? ChatScreen(
                                    embedded: true,
                                    onClose: _clearSelection,
                                  )
                                : _DesktopEmptyPane(
                                    onNewChat: () =>
                                        ConversationsScreen.showNewChatModal(
                                      context,
                                      onPeerSelected: _selectPeer,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const GroupsScreen(embedded: true),
                      const ProfileScreen(embedded: true),
                    ],
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
            Container(
              width: 108,
              height: 108,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: c.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.16),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your conversations live here',
              style: AppTheme.heading(c, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a chat from the sidebar or start a new one.\n${desktopShortcutHint(context)}',
              textAlign: TextAlign.center,
              style: AppTheme.text(
                c,
                color: c.secondary,
                fontSize: 13,
                wght: 450,
                height: 1.5,
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
