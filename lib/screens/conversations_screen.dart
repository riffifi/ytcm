import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/messenger_haptics.dart';
import 'chat_screen.dart';
import '../widgets/conversation_context_menu.dart';
import 'groups_screen.dart';
import 'settings_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Selector<AppState, ({List<ConversationPeer> peers, String? status})>(
      selector: (_, s) => (
        peers: s.conversationPeers,
        status: s.chatStatus?.trim(),
      ),
      builder: (context, data, _) {
        final peers = data.peers;
        final status = data.status;
        final showStatus = status != null && status.isNotEmpty;
        return _buildScaffold(context, c, peers, showStatus, status);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AppColors c,
    List<ConversationPeer> peers,
    bool showStatus,
    String? status,
  ) {

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 52,
        title: Text(
          'Messages',
          style: TextStyle(
            color: c.primary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              messengerHapticSelection();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupsScreen()),
              );
            },
            icon: Icon(Icons.groups_outlined, color: c.secondary, size: 22),
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
              icon: Icon(Icons.settings_outlined, color: c.secondary, size: 22),
              tooltip: 'Settings',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(showStatus ? 33 : 1),
          child: Column(
            children: [
              if (showStatus)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: c.surfaceHigh,
                  child: Text(
                    status!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.secondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              Container(height: 1, color: c.border),
            ],
          ),
        ),
      ),
      body: peers.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: peers.length,
              itemBuilder: (context, i) =>
                  _ConversationTile(peer: peers[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          messengerHapticMedium();
          _showNewChatModal(context);
        },
        backgroundColor: c.accent,
        elevation: 3,
        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
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

  void _showNewChatModal(BuildContext context) {
    final c = context.mc;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _NewChatSheet(),
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
              child: Icon(Icons.chat_bubble_outline,
                  color: c.secondary, size: 28),
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
  const _NewChatSheet();

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
    state.openChat(resolved.peerId, resolved.username);
    if (!navContext.mounted) return;
    Navigator.push(
      navContext,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _openOnlinePeer(Connection peer) {
    messengerHapticLight();
    final navContext = context;
    final sheetContext = context;
    final state = context.read<AppState>();
    Navigator.pop(sheetContext);
    state.openChat(peer.uuid, peer.username);
    if (!navContext.mounted) return;
    Navigator.push(
      navContext,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
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
  const _ConversationTile({required this.peer});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final lastMsg = state.getLastMessage(peer.userId);
    final preview = state.lastMessagePreview(peer.userId);
    final unread = state.getUnreadCount(peer.userId);
    final label = peer.username.isNotEmpty
        ? peer.username[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          messengerHapticLight();
          state.openChat(peer.userId, peer.username);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Avatar(label: label),
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
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 15,
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
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0 ? c.primary : c.secondary,
                              fontSize: 13,
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
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: c.border, size: 16),
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
