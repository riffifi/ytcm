import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../widgets/conversation_context_menu.dart';
import 'groups_screen.dart';
import '../widgets/user_avatar.dart';
import '../utils/profile_extras.dart';
import 'settings_screen.dart';
import '../utils/platform_ui.dart';
import '../widgets/app_components.dart';
import '../widgets/app_bottom_sheet.dart';

class ConversationsScreen extends StatefulWidget {
  final bool selectionMode;
  final bool inShell;
  final String? selectedPeerId;
  final ValueChanged<ConversationPeer>? onPeerSelected;

  const ConversationsScreen({
    super.key,
    this.selectionMode = false,
    this.inShell = false,
    this.selectedPeerId,
    this.onPeerSelected,
  });

  static void showNewChatModal(
    BuildContext context, {
    ValueChanged<ConversationPeer>? onPeerSelected,
  }) {
    AppBottomSheet.show<void>(
      context,
      title: 'Start new chat',
      builder: (_) => _NewChatSheet(onPeerSelected: onPeerSelected),
    );
  }

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  String _prefetchKey = '';
  String _searchQuery = '';
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  List<ConversationPeer> _filterPeers(
    BuildContext context,
    List<ConversationPeer> peers,
  ) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return peers;
    final state = context.read<AppState>();
    return peers.where((p) {
      final name = state.peerDisplayName(p.userId).toLowerCase();
      final user = p.username.toLowerCase();
      final id = p.userId.toLowerCase();
      return name.contains(q) || user.contains(q) || id.contains(q);
    }).toList();
  }

  void _scheduleProfilePrefetch(List<ConversationPeer> peers) {
    final key = peers.map((p) => p.userId).join('\x1e');
    if (key == _prefetchKey) return;
    _prefetchKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().prefetchPeerProfiles(
            peers.map((p) => p.userId),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Selector<AppState, List<ConversationPeer>>(
      selector: (_, s) => s.conversationPeers,
      builder: (context, peers, _) {
        _scheduleProfilePrefetch(peers);
        return _buildScaffold(context, c, peers);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AppColors c,
    List<ConversationPeer> peers,
  ) {
    final filtered = _filterPeers(context, peers);
    final hasQuery = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YeChat', style: AppTheme.heading(c, fontSize: 23)),
                Text(
                  'Your conversations',
                  style: AppTheme.text(
                    c,
                    color: c.secondary,
                    fontSize: 11,
                    wght: AppFontWeight.medium,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.selectionMode)
            IconButton(
              onPressed: () {
                messengerHapticSelection();
                ConversationsScreen.showNewChatModal(
                  context,
                  onPeerSelected: widget.onPeerSelected,
                );
              },
              icon: PhosphorIcon(
                PhosphorAssets.edit,
                color: c.secondary,
                size: 22,
              ),
              tooltip: 'New chat',
            ),
          if (!widget.inShell)
            IconButton(
              onPressed: () {
                messengerHapticSelection();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                );
              },
              icon: PhosphorIcon(
                PhosphorAssets.groups,
                color: c.secondary,
                size: 22,
              ),
              tooltip: 'Groups',
            ),
          if (!widget.inShell)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: () {
                  messengerHapticSelection();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: PhosphorIcon(
                  PhosphorAssets.settings,
                  color: c.secondary,
                  size: 22,
                ),
                tooltip: 'Settings',
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppTheme.text(c, fontSize: 15),
              cursorColor: c.accent,
              decoration: InputDecoration(
                hintText: 'Search chats',
                isDense: true,
                prefixIcon: PhosphorIcon.forInput(
                  PhosphorAssets.search,
                  color: c.tertiary,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: PhosphorIcon(
                          PhosphorAssets.close,
                          color: c.tertiary,
                          size: 18,
                        ),
                        tooltip: 'Clear search',
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: peers.isEmpty
          ? _emptyState(context)
          : filtered.isEmpty
              ? Center(
                  child: Text(
                    'No chats match “$_searchQuery”',
                    style: AppTheme.text(c, color: c.secondary, fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  color: c.accent,
                  onRefresh: () async {
                    context.read<AppState>().chat.listConnections();
                    await Future<void>.delayed(
                      AppMotion.theme,
                    );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ConversationTile(
                      peer: filtered[i],
                      selectionMode: widget.selectionMode,
                      selected: widget.selectedPeerId == filtered[i].userId,
                      onPeerSelected: widget.onPeerSelected,
                    ),
                  ),
                ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'new-direct-message',
              onPressed: () {
                messengerHapticMedium();
                ConversationsScreen.showNewChatModal(context);
              },
              backgroundColor: c.accent,
              elevation: 2,
              icon: const PhosphorIcon(
                PhosphorAssets.edit,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'New chat',
                style: AppTheme.text(c,
                    color: Colors.white,
                    wght: AppFontWeight.semibold,
                    fontSize: 14),
              ),
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return const EmptyState(
      icon: PhosphorAssets.chat,
      title: 'No conversations yet',
      message: 'Start a chat with a username or user ID from their profile.',
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final ValueChanged<ConversationPeer>? onPeerSelected;

  const _NewChatSheet({this.onPeerSelected});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().chat.listConnections();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runStart(String query) async {
    if (_starting) return;
    final navContext = context;
    final sheetContext = context;
    final state = context.read<AppState>();

    setState(() {
      _starting = true;
      _error = null;
    });

    if (query.isEmpty) {
      setState(() {
        _starting = false;
        _error = 'Please enter a username or user ID';
      });
      return;
    }

    final resolved = await state.resolvePeer(query);
    if (resolved == null) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = state.resolvePeerErrorHint(query);
      });
      return;
    }

    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    if (!navContext.mounted) return;
    openChatInApp(
      navContext,
      peerId: resolved.peerId,
      username: resolved.username,
      onPeerSelected: widget.onPeerSelected,
    );
  }

  void _openOnlinePeer(Connection peer) {
    messengerHapticLight();
    final navContext = context;
    final sheetContext = context;
    Navigator.pop(sheetContext);
    if (!navContext.mounted) return;
    openChatInApp(
      navContext,
      peerId: peer.uuid,
      username: peer.username,
      onPeerSelected: widget.onPeerSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetColors = context.mc;
    final state = context.watch<AppState>();
    final online = state.contacts;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (online.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Connected now (optional)',
                style: AppTheme.caption(sheetColors),
              ),
              const SizedBox(height: 4),
              Text(
                'You can also message offline users by username below.',
                style: AppTheme.timestamp(sheetColors),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final peer in online)
                    ActionChip(
                      label: Text(peer.username),
                      avatar: CircleAvatar(
                        backgroundColor: sheetColors.accentSoft,
                        child: Text(
                          peer.username.isNotEmpty
                              ? peer.username[0].toUpperCase()
                              : '?',
                          style: AppTheme.timestamp(sheetColors,
                              color: sheetColors.accent),
                        ),
                      ),
                      onPressed: _starting ? null : () => _openOnlinePeer(peer),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: online.isEmpty,
              style: AppTheme.text(sheetColors),
              decoration: InputDecoration(
                hintText: 'Username, email, or user ID',
                errorText: _error,
                filled: true,
                fillColor: sheetColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: sheetColors.border),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _runStart(_controller.text.trim()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _starting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sheetColors.accent,
                    ),
                    onPressed: _starting
                        ? null
                        : () => _runStart(_controller.text.trim()),
                    child: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Start',
                            style:
                                AppTheme.text(sheetColors, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationPeer peer;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<ConversationPeer>? onPeerSelected;

  const _ConversationTile({
    required this.peer,
    this.selectionMode = false,
    this.selected = false,
    this.onPeerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final lastMsg = state.getLastMessage(peer.userId);
    final preview = state.lastMessagePreview(peer.userId);
    final unread = state.getUnreadCount(peer.userId);
    final displayName = state.peerDisplayName(peer.userId);
    final profile = state.peerProfile(peer.userId);
    final extras = ProfileExtras.parse(profile?.additionalInfo);
    final online = state.isPeerOnline(peer.userId);
    final initials = profile?.initials ??
        (displayName.isNotEmpty ? displayName[0].toUpperCase() : '?');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            messengerHapticLight();
            openChatInApp(
              context,
              peerId: peer.userId,
              username: peer.username,
              onPeerSelected: selectionMode ? onPeerSelected : null,
            );
          },
          onLongPress: conversationContextMenuIsDesktop(context)
              ? null
              : () => showConversationContextMenu(
                    context: context,
                    peer: peer,
                    preview: preview,
                  ),
          onSecondaryTapDown: conversationContextMenuIsDesktop(context)
              ? (details) => showConversationContextMenu(
                    context: context,
                    peer: peer,
                    preview: preview,
                    globalPosition: details.globalPosition,
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    UserAvatar(
                      avatarFileId: extras.avatarFileId,
                      initials: initials,
                      radius: 22,
                    ),
                    if (online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: c.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppTheme.listTitle(c, emphasized: unread > 0),
                            ),
                          ),
                          if (lastMsg != null)
                            Text(
                              _formatTime(lastMsg.createdAt),
                              style: AppTheme.timestamp(c,
                                  color: unread > 0 ? c.accent : c.tertiary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.text(c,
                                  color: unread > 0 ? c.primary : c.secondary,
                                  fontSize: 13,
                                  height: 1.2),
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: unread),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!selectionMode) ...[
                  const SizedBox(width: 4),
                  PhosphorIcon(
                    PhosphorAssets.caretRight,
                    color: c.border,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM').format(dt);
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTheme.timestamp(c, color: Colors.white),
      ),
    );
  }
}
