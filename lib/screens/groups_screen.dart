import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../icons/phosphor_assets.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/messenger_haptics.dart';
import '../utils/messenger_snackbar.dart';
import '../utils/platform_ui.dart';
import '../widgets/app_components.dart';
import '../widgets/phosphor_icon.dart';
import '../widgets/user_avatar.dart';
import 'group_chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  final bool embedded;
  const GroupsScreen({super.key, this.embedded = false});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _query = '';

  String _time(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return DateFormat('HH:mm').format(date);
    if (days == 1) return 'Yesterday';
    if (days < 7) return DateFormat('EEE').format(date);
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final q = _query.trim().toLowerCase();
    final groups = state.groups
        .where((g) =>
            q.isEmpty ||
            g.name.toLowerCase().contains(q) ||
            (g.description ?? '').toLowerCase().contains(q))
        .toList();
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: PhosphorIcon(adaptiveBackIcon(context),
                    size: adaptiveBackIconSize(context)),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text('Groups', style: AppTheme.heading(c, fontSize: 26)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.md),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: AppTheme.text(c),
              decoration: InputDecoration(
                hintText: 'Search groups and channels',
                prefixIcon: PhosphorIcon.forInput(PhosphorAssets.search,
                    color: c.tertiary),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create-group',
        tooltip: 'Create group',
        onPressed: () => _create(context),
        child: const PhosphorIcon(PhosphorAssets.userAdd),
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshGroups,
        child: groups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * .6,
                    child: EmptyState(
                      icon: q.isEmpty
                          ? PhosphorAssets.groups
                          : PhosphorAssets.search,
                      title: q.isEmpty ? 'No groups yet' : 'No matches',
                      message: q.isEmpty
                          ? 'Create a group or channel to bring everyone together.'
                          : 'Try a different name or description.',
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.md, AppSpace.sm, AppSpace.md, 96),
                itemCount: groups.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpace.sm),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final last = state.getLastGroupMessage(group.uuid);
                  final unread = state.getGroupUnreadCount(group.uuid);
                  final preview = last?.previewText.isNotEmpty == true
                      ? last!.previewText
                      : group.description?.trim().isNotEmpty == true
                          ? group.description!
                          : group.isChannel
                              ? 'Channel'
                              : 'Group';
                  return SurfaceCard(
                    padding: EdgeInsets.zero,
                    onTap: () {
                      messengerHapticSelection();
                      state.openGroupChat(group.uuid, group.name);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const GroupChatScreen()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg, vertical: AppSpace.md),
                      child: Row(
                        children: [
                          UserAvatar(
                              avatarFileId: group.avatarId,
                              initials: group.name,
                              radius: 24),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.listTitle(c,
                                        emphasized: unread > 0)),
                                const SizedBox(height: AppSpace.xs),
                                Text(preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.caption(c)),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (last != null)
                                Text(_time(last.createdAt),
                                    style: AppTheme.timestamp(c)),
                              if (unread > 0) ...[
                                const SizedBox(height: AppSpace.sm),
                                Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 22),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Text(unread > 99 ? '99+' : '$unread',
                                      textAlign: TextAlign.center,
                                      style: AppTheme.timestamp(c,
                                          color: Colors.white)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final members = TextEditingController();
    var isPrivate = false;
    var isChannel = false;
    String? avatarId;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New group'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AvatarPicker(
                  currentFileId: avatarId,
                  fallbackInitials: name.text.isEmpty ? 'G' : name.text,
                  onPick: () => context
                      .read<AppState>()
                      .uploadAvatarImage(shareWithContacts: false),
                  onPicked: (id) => setDialogState(() => avatarId = id),
                ),
                const SizedBox(height: AppSpace.xl),
                TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Group name')),
                const SizedBox(height: AppSpace.md),
                TextField(
                    controller: description,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                const SizedBox(height: AppSpace.md),
                TextField(
                  controller: members,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Members',
                      hintText: 'Usernames separated by commas'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Channel'),
                  subtitle: const Text('Broadcast-style conversation'),
                  trailing: AppSwitch(
                      value: isChannel,
                      onChanged: (v) => setDialogState(() => isChannel = v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private'),
                  trailing: AppSwitch(
                      value: isPrivate,
                      onChanged: (v) => setDialogState(() => isPrivate = v)),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    final groupName = name.text;
    final groupDescription = description.text;
    final groupMembers = members.text;
    name.dispose();
    description.dispose();
    members.dispose();
    if (created != true || !context.mounted) return;
    final result = await context.read<AppState>().createGroup(
          groupName,
          memberUsernames: AppState.parseUsernameList(groupMembers),
          description: groupDescription,
          isPrivate: isPrivate,
          isChannel: isChannel,
          avatarId: avatarId,
        );
    if (!context.mounted) return;
    showMessengerSnackBar(
        context,
        result.ok
            ? result.message ?? 'Group created'
            : result.message ?? 'Could not create group');
  }
}
