import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/profile_extras.dart';
import '../widgets/user_avatar.dart';

class UserProfileScreen extends StatefulWidget {
  final String peerId;

  const UserProfileScreen({super.key, required this.peerId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshPeerProfile(widget.peerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final loaded = state.peerProfile(widget.peerId);
    final profile = loaded ??
        UserInfo(
          uuid: widget.peerId,
          username: state.peerUsername(widget.peerId),
        );
    final online = state.isPeerOnline(widget.peerId);
    final username = state.peerUsername(widget.peerId);
    final extras = ProfileExtras.parse(profile.additionalInfo);
    final loadingFull = loaded == null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: PhosphorIcon(
            adaptiveBackIcon(context),
            size: adaptiveBackIconSize(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile', style: AppTheme.heading(c, fontSize: 26)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
            children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      avatarFileId: extras.avatarFileId,
                      initials: profile.initials,
                      radius: 40,
                    ),
                    if (online)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: c.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bg, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: TextStyle(color: c.secondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    online ? 'Online now' : 'Offline',
                    style: TextStyle(
                      color: online ? c.success : c.tertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _InfoSection(
            label: 'About',
            value: extras.bio?.isNotEmpty == true ? extras.bio! : 'No bio yet',
          ),
          if (_hasValue(profile.firstName) || _hasValue(profile.lastName))
            const SizedBox(height: 20),
          if (_hasValue(profile.firstName))
            _InfoSection(label: 'First name', value: profile.firstName!),
          if (_hasValue(profile.lastName)) ...[
            const SizedBox(height: 12),
            _InfoSection(label: 'Last name', value: profile.lastName!),
          ],
          if (_hasValue(profile.dateOfBirth)) ...[
            const SizedBox(height: 12),
            _InfoSection(
              label: 'Date of birth',
              value: profile.dateOfBirth!,
            ),
          ],
          const SizedBox(height: 20),
          _InfoSection(label: 'User ID', value: widget.peerId, mono: true),
          if (loadingFull) ...[
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: c.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasValue(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t != 'null';
  }
}

class _InfoSection extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoSection({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: c.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: c.primary,
              fontSize: mono ? 11 : 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
