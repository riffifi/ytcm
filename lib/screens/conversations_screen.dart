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

class ConversationsScreen extends StatefulWidget {
  final bool selectionMode;
  final String? selectedPeerId;
  final ValueChanged<ConversationPeer>? onPeerSelected;

  const ConversationsScreen({
    super.key,
    this.selectionMode = false,
    this.selectedPeerId,
    this.onPeerSelected,
  });

  static void showNewChatModal(
    BuildContext context, {
    ValueChanged<ConversationPeer>? onPeerSelected,
  }) {
    final c = context.mc;
    final sheet = _NewChatSheet(onPeerSelected: onPeerSelected);
    if (isWideLayout(context)) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: sheet,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => sheet,
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
        toolbarHeight: 52,
        title: Text('Messages', style: AppTheme.heading(c)),
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
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                      const Duration(milliseconds: 400),
                    );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
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
              onPressed: () {
                messengerHapticMedium();
                ConversationsScreen.showNewChatModal(context);
              },
              backgroundColor: c.accent,
              elevation: 3,
              icon: const PhosphorIcon(
                PhosphorAssets.edit,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'New chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final c = context.mc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: PhosphorIcon(
                PhosphorAssets.chat,
                color: c.secondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                color: c.primary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + and enter a username, email, or user ID from their Profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.secondary, fontSize: 13),
            ),
          ],
        ),
      ),
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: sheetColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Start new chat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: sheetColors.primary,
                ),
              ),
              if (online.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Connected now (optional)',
                  style: TextStyle(
                    color: sheetColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can also message offline users by username below.',
                  style: TextStyle(
                    color: sheetColors.secondary,
                    fontSize: 11,
                  ),
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
                            style: TextStyle(
                              color: sheetColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onPressed: _starting
                            ? null
                            : () => _openOnlinePeer(peer),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: online.isEmpty,
                style: TextStyle(color: sheetColors.primary),
                decoration: InputDecoration(
                  hintText: 'Username, email, or user ID',
                  errorText: _error,
                  filled: true,
                  fillColor: sheetColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                      onPressed:
                          _starting ? null : () => Navigator.pop(context),
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
                          : const Text(
                              'Start',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

    return Material(
      color: selected ? c.accentSoft.withValues(alpha: 0.35) : Colors.transparent,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          border: Border.all(color: c.bg, width: 2),
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
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 15,
                              height: 1.2,
                              fontWeight:
                                  unread > 0 ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (lastMsg != null)
                          Text(
                            _formatTime(lastMsg.createdAt),
                            style: TextStyle(
                              color: unread > 0 ? c.accent : c.tertiary,
                              fontSize: 11,
                              height: 1.2,
                            ),
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
                            style: TextStyle(
                              color: unread > 0 ? c.primary : c.secondary,
                              fontSize: 13,
                              height: 1.2,
                            ),
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
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final double size;
  final Color? color;
  final Color? textColor;

  const _Avatar({
    required this.label,
    this.size = 44,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final bg = color ?? c.accentSoft;
    final fg = textColor ?? c.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
