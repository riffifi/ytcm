import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_snackbar.dart';
import '../utils/profile_extras.dart';
import '../widgets/user_avatar.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _dateOfBirthCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarFileId;

  @override
  void initState() {
    super.initState();
    _syncFromState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadMyProfile();
    });
  }

  void _syncFromState() {
    final me = context.read<AppState>().me;
    _firstNameCtrl.text = me?.firstName ?? '';
    _lastNameCtrl.text = me?.lastName ?? '';
    _usernameCtrl.text = me?.username ?? '';
    _dateOfBirthCtrl.text = me?.dateOfBirth ?? '';
    final extras = ProfileExtras.parse(me?.additionalInfo);
    _bioCtrl.text = extras.bio ?? '';
    _avatarFileId = extras.avatarFileId;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _dateOfBirthCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _uploadingAvatar = true);
    final state = context.read<AppState>();
    final fileId = await state.uploadAvatarImage();
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    if (fileId == null) return;

    final ok = await state.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      dateOfBirth: _dateOfBirthCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      avatarFileId: fileId,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _avatarFileId = fileId);
      showMessengerSnackBar(context, 'Avatar updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final me = state.me;
    final extras = ProfileExtras.parse(me?.additionalInfo);
    final avatarId = _avatarFileId ?? extras.avatarFileId;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: PhosphorIcon(
                  adaptiveBackIcon(context),
                  size: adaptiveBackIconSize(context),
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          widget.embedded ? 'You' : 'Profile',
          style: AppTheme.heading(c, fontSize: 26),
        ),
        actions: widget.embedded
            ? [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  icon: PhosphorIcon(
                    PhosphorAssets.settings,
                    color: c.secondary,
                  ),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    UserAvatar(
                      avatarFileId: avatarId,
                      initials: me?.initials ?? '?',
                      radius: 40,
                    ),
                    Material(
                      color: c.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _uploadingAvatar
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const PhosphorIcon(
                                  PhosphorAssets.camera,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  me?.displayName ?? me?.username ?? '',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${me?.username ?? ''}',
                  style: TextStyle(color: c.secondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    me?.uuid ?? '',
                    style: TextStyle(color: c.secondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          const _SectionLabel('Profile info'),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameCtrl,
            autocorrect: false,
            style: TextStyle(color: c.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _firstNameCtrl,
            style: TextStyle(color: c.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'First name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dateOfBirthCtrl,
            keyboardType: TextInputType.datetime,
            style: TextStyle(color: c.primary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Date of birth',
              helperText: 'Use the format expected by your server',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameCtrl,
            style: TextStyle(color: c.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Last name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioCtrl,
            maxLines: 4,
            style: TextStyle(color: c.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Bio'),
          ),
          const SizedBox(height: 20),
          _saving
              ? Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: () async {
                    setState(() => _saving = true);
                    final ok = await state.updateProfile(
                      firstName: _firstNameCtrl.text.trim(),
                      lastName: _lastNameCtrl.text.trim(),
                      username: _usernameCtrl.text.trim(),
                      dateOfBirth: _dateOfBirthCtrl.text.trim(),
                      bio: _bioCtrl.text.trim(),
                      avatarFileId: avatarId,
                    );
                    if (!context.mounted) return;
                    setState(() => _saving = false);
                    if (ok) {
                      showMessengerSnackBar(context, 'Profile updated');
                    } else {
                      showMessengerSnackBar(
                        context,
                        'Could not update profile',
                      );
                    }
                  },
                  child: const Text('Save changes'),
                ),
          const SizedBox(height: 32),
          const _SectionLabel('More'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: PhosphorAssets.settings,
            label: 'Settings',
            color: c.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Text(
      text.toUpperCase(),
      style: AppTheme.sectionLabel(c),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            PhosphorIcon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
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
