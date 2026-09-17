import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group_models.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/messenger_snackbar.dart';
import '../utils/platform_ui.dart';
import '../utils/profile_extras.dart';
import '../widgets/phosphor_icon.dart';
import '../widgets/user_avatar.dart';
import '../widgets/app_components.dart';
import '../widgets/app_bottom_sheet.dart';
import '../icons/phosphor_assets.dart';
import 'user_profile_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({super.key});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      final groupId = state.activeGroupId;
      if (groupId != null) state.chat.requestGroupInfo(groupId);
    });
  }

  Future<void> _editGroup(ChatGroup group) async {
    final name = TextEditingController(text: group.name);
    final description = TextEditingController(text: group.description ?? '');
    var isPrivate = group.isPrivate;
    var isChannel = group.isChannel;
    var avatarId = group.avatarId;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final c = context.mc;
          return AlertDialog(
            title: const Text('Edit group'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarPicker(
                      currentFileId: avatarId,
                      fallbackInitials: group.name,
                      radius: 42,
                      onPick: () => context
                          .read<AppState>()
                          .uploadAvatarImage(shareWithContacts: false),
                      onPicked: (id) => setDialogState(() => avatarId = id),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Channel'),
                      subtitle: const Text('Broadcast-style conversation'),
                      trailing: AppSwitch(
                        value: isChannel,
                        onChanged: (value) =>
                            setDialogState(() => isChannel = value),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Private'),
                      trailing: AppSwitch(
                        value: isPrivate,
                        onChanged: (value) =>
                            setDialogState(() => isPrivate = value),
                      ),
                    ),
                    if (avatarId != group.avatarId)
                      Text(
                        'The new image will be shared with current members.',
                        style: AppTheme.caption(c),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (save == true && mounted) {
      final error = await context.read<AppState>().updateActiveGroup(
            name: name.text,
            description: description.text,
            isPrivate: isPrivate,
            isChannel: isChannel,
            avatarId: avatarId,
          );
      if (mounted) {
        showMessengerSnackBar(context, error ?? 'Group updated');
      }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _memberAction(GroupMember member) async {
    final state = context.read<AppState>();
    final action = await AppBottomSheet.show<String>(
      context,
      title: 'Manage member',
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const PhosphorIcon(PhosphorAssets.shield),
              title: Text(member.role == 'admin'
                  ? 'Make regular member'
                  : 'Make admin'),
              onTap: () => Navigator.pop(
                context,
                member.role == 'admin' ? 'member' : 'admin',
              ),
            ),
            ListTile(
              leading: PhosphorIcon(PhosphorAssets.userRemove,
                  color: context.mc.error),
              title: Text('Remove from group',
                  style: AppTheme.listTitle(context.mc)
                      .copyWith(color: context.mc.error)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'remove') {
      state.removeGroupMember(member.userId);
    } else {
      state.setGroupMemberRole(member.userId, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final groupId = state.activeGroupId;
    final details = groupId == null ? null : state.groupDetails(groupId);
    final group = details?.group ??
        state.groups.cast<ChatGroup?>().firstWhere(
              (item) => item?.uuid == groupId,
              orElse: () => null,
            );
    final myMember = details?.members.cast<GroupMember?>().firstWhere(
          (member) => member?.userId == state.me?.uuid,
          orElse: () => null,
        );
    final canManage = myMember?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: PhosphorIcon(
            adaptiveBackIcon(context),
            size: adaptiveBackIconSize(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Group details', style: AppTheme.appBarTitle(c)),
        actions: [
          if (group != null && canManage)
            IconButton(
              tooltip: 'Edit group',
              onPressed: () => _editGroup(group),
              icon: const PhosphorIcon(PhosphorAssets.pencil),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: group == null
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            UserAvatar(
                              avatarFileId: group.avatarId,
                              initials: group.name,
                              radius: 46,
                            ),
                            const SizedBox(height: 16),
                            Text(group.name,
                                textAlign: TextAlign.center,
                                style: AppTheme.heading(c, fontSize: 24)),
                            const SizedBox(height: 6),
                            Text(
                              [
                                group.isChannel ? 'Channel' : 'Group',
                                group.isPrivate ? 'Private' : 'Open',
                                if (details != null)
                                  '${details.members.length} members',
                              ].join(' · '),
                              style: AppTheme.caption(c),
                            ),
                            if (group.description?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 16),
                              Text(
                                group.description!,
                                textAlign: TextAlign.center,
                                style: AppTheme.text(c,
                                    color: c.secondary, height: 1.45),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('MEMBERS', style: AppTheme.sectionLabel(c)),
                    const SizedBox(height: 10),
                    if (details == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < details.members.length;
                                i++) ...[
                              _MemberTile(
                                member: details.members[i],
                                canManage: canManage &&
                                    details.members[i].userId !=
                                        state.me?.uuid &&
                                    !details.members[i].isOwner,
                                onManage: () =>
                                    _memberAction(details.members[i]),
                              ),
                              if (i != details.members.length - 1)
                                Divider(height: 1, color: c.borderSoft),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMember member;
  final bool canManage;
  final VoidCallback onManage;

  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.peerProfile(member.userId);
    final name = member.userId == state.me?.uuid
        ? state.me?.displayName ?? 'You'
        : state.peerDisplayName(member.userId);
    final extras = member.userId == state.me?.uuid
        ? ProfileExtras.parse(state.me?.additionalInfo)
        : state.peerExtras(member.userId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        avatarFileId: extras.avatarFileId,
        initials: profile?.initials ?? name,
        radius: 22,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(member.role),
      trailing: canManage
          ? IconButton(
              tooltip: 'Manage member',
              onPressed: onManage,
              icon: const PhosphorIcon(PhosphorAssets.more),
            )
          : null,
      onTap: member.userId == state.me?.uuid
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(peerId: member.userId),
                ),
              ),
    );
  }
}
