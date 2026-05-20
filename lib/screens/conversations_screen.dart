import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/locale_controller.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'profile_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final peers = state.conversationPeers;
    final status = state.chatStatus?.trim();
    final showStatus = status != null && status.isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: TabBar(
          controller: _tab,
          indicatorColor: c.accent,
          labelColor: c.primary,
          unselectedLabelColor: c.secondary,
          tabs: [
            Tab(text: context.str('tabs.messages')),
            Tab(text: context.str('tabs.groups')),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: _Avatar(
                label: state.me?.initials ?? '?',
                size: 32,
                color: c.accentSoft,
                textColor: c.accent,
              ),
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
                    status,
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
      body: TabBarView(
        controller: _tab,
        children: [
          peers.isEmpty
              ? _emptyMessages(context)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: peers.length,
                  itemBuilder: (context, i) =>
                      _ConversationTile(peer: peers[i]),
                ),
          _GroupsBody(onOpenGroup: (g) {
            state.openGroupChat(g.uuid, g.name);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupChatScreen()),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tab.index == 0) {
            _showNewChatModal(context);
          } else {
            _showNewGroupDialog(context);
          }
        },
        backgroundColor: c.accent,
        child: Icon(
          _tab.index == 0 ? Icons.chat_bubble_outline : Icons.group_add,
          color: Colors.white,
        ),
        tooltip: _tab.index == 0
            ? context.str('conversations.new_chat')
            : context.str('groups.new_group'),
      ),
    );
  }

  void _showNewGroupDialog(BuildContext context) {
    final c = context.mc;
    final state = context.read<AppState>();
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceHigh,
        title: Text(context.str('groups.new_group')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: context.str('groups.group_name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.str('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              state.createGroupByName(ctrl.text);
              Navigator.pop(ctx);
            },
            child: Text(context.str('groups.create')),
          ),
        ],
      ),
    );
  }

  void _showNewChatModal(BuildContext context) {
    final c = context.mc;
    final state = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final sheetColors = ctx.mc;
        final controller = TextEditingController();
        String? error;
        var starting = false;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      context.str('conversations.new_chat'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: sheetColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.str('conversations.username_hint'),
                        errorText: error,
                        filled: true,
                        fillColor: sheetColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: sheetColors.border),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (starting) return;
                        _startChat(
                          navContext: context,
                          sheetContext: ctx,
                          state: state,
                          query: controller.text.trim(),
                          onStarting: () => setState(() => starting = true),
                          onError: (e) => setState(() {
                            starting = false;
                            error = e;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(context.str('common.cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sheetColors.accent,
                            ),
                            onPressed: starting
                                ? null
                                : () => _startChat(
                                      navContext: context,
                                      sheetContext: ctx,
                                      state: state,
                                      query: controller.text.trim(),
                                      onStarting: () =>
                                          setState(() => starting = true),
                                      onError: (e) => setState(() {
                                        starting = false;
                                        error = e;
                                      }),
                                    ),
                            child: starting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    context.str('conversations.start'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startChat({
    required BuildContext navContext,
    required BuildContext sheetContext,
    required AppState state,
    required String query,
    required VoidCallback onStarting,
    required void Function(String message) onError,
  }) async {
    if (query.isEmpty) {
      onError(navContext.str('conversations.empty_query'));
      return;
    }

    onStarting();
    final resolved = await state.resolvePeer(query);
    if (resolved == null) {
      onError(state.resolvePeerErrorHint(query));
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

  Widget _emptyMessages(BuildContext context) {
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
              context.str('chat.no_messages'),
              style: TextStyle(
                color: c.primary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsBody extends StatelessWidget {
  const _GroupsBody({required this.onOpenGroup});

  final void Function(GroupInfo g) onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final groups = state.groups;
    final me = state.me?.uuid ?? '';

    if (groups.isEmpty) {
      return Center(
        child: Text(
          context.str('groups.title'),
          style: TextStyle(color: c.secondary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        final unread = state.getGroupUnreadCount(g.uuid, me);
        final last = state.getLastGroupMessage(g.uuid);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: c.accentSoft,
            child: Text(
              g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
              style: TextStyle(color: c.accent),
            ),
          ),
          title: Text(g.name, style: TextStyle(color: c.primary)),
          subtitle: Text(
            last == null
                ? context.str('chat.no_messages')
                : (last.fileId != null
                    ? context.str('chat.attachment')
                    : last.previewText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.secondary, fontSize: 13),
          ),
          trailing: unread > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
              : null,
          onTap: () => onOpenGroup(g),
        );
      },
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final ConversationPeer peer;
  const _ConversationTile({required this.peer});

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshPresence(widget.peer.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final peer = widget.peer;
    final lastMsg = state.getLastMessage(peer.userId);
    var preview = state.lastMessagePreview(peer.userId);
    if (preview == 'Attachment') preview = context.str('chat.attachment');
    final unread = state.getUnreadCount(peer.userId);
    final label =
        peer.username.isNotEmpty ? peer.username[0].toUpperCase() : '?';

    final sub = state.presenceSubtitle(
      peer.userId,
      onlineLabel: context.str('presence.online'),
      lastSeenTemplate: context.str('presence.last_seen'),
      unknownLabel: context.str('presence.unknown'),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          state.openChat(peer.userId, peer.username);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
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
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (lastMsg != null)
                          Text(
                            _formatTime(context, lastMsg.createdAt),
                            style: TextStyle(
                              color: unread > 0 ? c.accent : c.tertiary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.tertiary, fontSize: 11),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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

  String _formatTime(BuildContext context, DateTime dt) {
    final c = context.mc;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return context.str('common.yesterday');
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM').format(dt);
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
    final bg = color ?? c.surfaceHigh;
    final fg = textColor ?? c.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size / 3),
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
