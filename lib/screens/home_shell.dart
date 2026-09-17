import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
import '../widgets/app_components.dart';
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

  void _selectTab(int index) {
    if (index == _mobileIndex) return;
    messengerHapticSelection();
    setState(() => _mobileIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (!isWideLayout(context)) {
      return Scaffold(
        body: _TabTransition(
          index: _mobileIndex,
          child: IndexedStack(
            index: _mobileIndex,
            children: const [
              ConversationsScreen(inShell: true),
              GroupsScreen(embedded: true),
              ProfileScreen(embedded: true),
              SettingsScreen(embedded: true),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _mobileIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.chat, size: 22),
              selectedIcon: PhosphorIcon(
                PhosphorAssets.chat,
                size: 22,
                weight: PhosphorWeight.fill,
              ),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.groups, size: 22),
              selectedIcon: PhosphorIcon(
                PhosphorAssets.groups,
                size: 22,
                weight: PhosphorWeight.fill,
              ),
              label: 'Groups',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.user, size: 22),
              selectedIcon: PhosphorIcon(
                PhosphorAssets.user,
                size: 22,
                weight: PhosphorWeight.fill,
              ),
              label: 'You',
            ),
            NavigationDestination(
              icon: PhosphorIcon(PhosphorAssets.settings, size: 22),
              selectedIcon: PhosphorIcon(
                PhosphorAssets.settings,
                size: 22,
                weight: PhosphorWeight.fill,
              ),
              label: 'Settings',
            ),
          ],
        ),
      );
    }

    final c = context.mc;
    final compactWide = isCompactWideLayout(context);
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
                  onDestinationSelected: _selectTab,
                  backgroundColor: c.surface,
                  indicatorColor: c.accentSoft,
                  labelType: compactWide
                      ? NavigationRailLabelType.selected
                      : NavigationRailLabelType.all,
                  minWidth: compactWide ? 68 : 82,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: PhosphorIcon(
                        PhosphorAssets.chat,
                        size: 22,
                        color: c.tertiary,
                      ),
                      selectedIcon: PhosphorIcon(
                        PhosphorAssets.chat,
                        size: 22,
                        color: c.accent,
                        weight: PhosphorWeight.fill,
                      ),
                      label: const Text('Chats'),
                    ),
                    NavigationRailDestination(
                      icon: PhosphorIcon(
                        PhosphorAssets.groups,
                        size: 22,
                        color: c.tertiary,
                      ),
                      selectedIcon: PhosphorIcon(
                        PhosphorAssets.groups,
                        size: 22,
                        color: c.accent,
                        weight: PhosphorWeight.fill,
                      ),
                      label: const Text('Groups'),
                    ),
                    NavigationRailDestination(
                      icon: PhosphorIcon(
                        PhosphorAssets.user,
                        size: 22,
                        color: c.tertiary,
                      ),
                      selectedIcon: PhosphorIcon(
                        PhosphorAssets.user,
                        size: 22,
                        color: c.accent,
                        weight: PhosphorWeight.fill,
                      ),
                      label: const Text('You'),
                    ),
                    NavigationRailDestination(
                      icon: PhosphorIcon(
                        PhosphorAssets.settings,
                        size: 22,
                        color: c.tertiary,
                      ),
                      selectedIcon: PhosphorIcon(
                        PhosphorAssets.settings,
                        size: 22,
                        color: c.accent,
                        weight: PhosphorWeight.fill,
                      ),
                      label: const Text('Settings'),
                    ),
                  ],
                ),
                Container(width: 1, color: c.borderSoft),
                Expanded(
                  child: _TabTransition(
                    index: _mobileIndex,
                    child: IndexedStack(
                      index: _mobileIndex,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: compactWide ? 300 : 370,
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
                        const SettingsScreen(embedded: true),
                      ],
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

class _TabTransition extends StatefulWidget {
  const _TabTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.base,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: .78 + animation.value * .22,
        child: Transform.translate(
          offset: Offset(_direction * 10 * (1 - animation.value), 0),
          child: child,
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
    return EmptyState(
      icon: PhosphorAssets.chat,
      title: 'Your conversations live here',
      message:
          'Choose a chat from the sidebar or start a new one.\n${desktopShortcutHint(context)}',
      action: FilledButton.icon(
        onPressed: onNewChat,
        icon: const PhosphorIcon(
          PhosphorAssets.edit,
          color: Colors.white,
          size: 18,
        ),
        label: const Text('New chat'),
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
