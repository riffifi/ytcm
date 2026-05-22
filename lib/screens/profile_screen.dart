import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/messenger_snackbar.dart';
import '../utils/profile_extras.dart';
import '../widgets/user_avatar.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
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
    final extras = ProfileExtras.parse(me?.additionalInfo);
    _bioCtrl.text = extras.bio ?? '';
    _avatarFileId = extras.avatarFileId;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
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
                              : const Icon(
                                  Icons.camera_alt_outlined,
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
          _SectionLabel('Profile info'),
          const SizedBox(height: 12),
          TextField(
            controller: _firstNameCtrl,
            style: TextStyle(color: c.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'First name'),
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
                    color: c.accent.withOpacity(0.5),
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
                      bio: _bioCtrl.text.trim(),
                      avatarFileId: avatarId,
                    );
                    setState(() => _saving = false);
                    if (!mounted) return;
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
          _SectionLabel('More'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            color: c.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
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
      style: TextStyle(
        color: c.secondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
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
            Icon(icon, color: color, size: 18),
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
