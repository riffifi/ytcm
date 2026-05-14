import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final contacts = state.contacts;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: _Avatar(
                label: state.me?.initials ?? '?',
                size: 32,
                color: AppTheme.accentSoft,
                textColor: AppTheme.accent,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: contacts.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, i) =>
                  _ConversationTile(contact: contacts[i]),
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: AppTheme.secondary, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('No conversations yet',
              style: TextStyle(color: AppTheme.primary, fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Start chatting from contacts',
              style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Connection contact;
  const _ConversationTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lastMsg = state.getLastMessage(contact.uuid);
    final unread = state.getUnreadCount(contact.uuid);

    return GestureDetector(
      onTap: () {
        state.openChat(contact.uuid, contact.username);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(label: contact.username[0].toUpperCase()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        contact.username,
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                      if (lastMsg != null)
                        Text(
                          _formatTime(lastMsg.createdAt),
                          style: TextStyle(
                            color: unread > 0
                                ? AppTheme.accent
                                : AppTheme.tertiary,
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
                          lastMsg?.text ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0
                                ? AppTheme.primary
                                : AppTheme.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppTheme.border, size: 16),
          ],
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

class _Avatar extends StatelessWidget {
  final String label;
  final double size;
  final Color color;
  final Color textColor;

  const _Avatar({
    required this.label,
    this.size = 44,
    this.color = AppTheme.surfaceHigh,
    this.textColor = AppTheme.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
