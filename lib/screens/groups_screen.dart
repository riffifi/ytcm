import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../utils/messenger_snackbar.dart';
import 'group_chat_screen.dart';

class GroupsScreen extends StatelessWidget {
  final bool embedded;

  const GroupsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text('Groups', style: AppTheme.heading(c, fontSize: 26)),
        leading: embedded
            ? null
            : IconButton(
                icon: PhosphorIcon(
                  adaptiveBackIcon(context),
                  size: adaptiveBackIconSize(context),
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroup(context),
        child: const PhosphorIcon(PhosphorAssets.userAdd),
      ),
      body: Selector<AppState, List<ChatGroup>>(
        selector: (_, s) => s.groups,
        builder: (context, groups, _) {
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorAssets.groups,
                      size: 40,
                      color: c.border,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No groups yet',
                      style: AppTheme.text(
                        c,
                        fontSize: 15,
                        wght: AppFontWeight.medium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to create a group or channel',
                      textAlign: TextAlign.center,
                      style: AppTheme.text(c, color: c.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final group = groups[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        group.isChannel
                            ? PhosphorAssets.megaphone
                            : PhosphorAssets.groups,
                        color: c.accent,
                      ),
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: group.description != null &&
                          group.description!.isNotEmpty
                      ? Text(
                          group.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.secondary, fontSize: 13),
                        )
                      : Text(
                          group.isChannel ? 'Channel' : 'Group',
                          style: TextStyle(color: c.tertiary, fontSize: 12),
                        ),
                  onTap: () {
                    messengerHapticSelection();
                    context
                        .read<AppState>()
                        .openGroupChat(group.uuid, group.name);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GroupChatScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateGroup(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final membersCtrl = TextEditingController();
    var isPrivate = false;
    var isChannel = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.mc;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: c.surface,
            title: Text('New group', style: TextStyle(color: c.primary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: membersCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Add members (optional)',
                      hintText: 'usernames, separated by commas',
                    ),
                    maxLines: 2,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Channel'),
                    subtitle: const Text('Broadcast-style group'),
                    value: isChannel,
                    onChanged: (value) =>
                        setDialogState(() => isChannel = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Private'),
                    value: isPrivate,
                    onChanged: (value) =>
                        setDialogState(() => isPrivate = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
    final name = nameCtrl.text;
    final description = descriptionCtrl.text;
    final members = membersCtrl.text;
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    membersCtrl.dispose();
    if (ok != true || !context.mounted) return;

    final state = context.read<AppState>();
    final result = await state.createGroup(
      name,
      memberUsernames: AppState.parseUsernameList(members),
      description: description,
      isPrivate: isPrivate,
      isChannel: isChannel,
    );
    if (!context.mounted) return;
    if (!result.ok) {
      showMessengerSnackBar(
          context, result.message ?? 'Could not create group');
    } else if (result.message != null) {
      showMessengerSnackBar(context, result.message!);
    } else {
      showMessengerSnackBar(context, 'Group created');
    }
  }
}
