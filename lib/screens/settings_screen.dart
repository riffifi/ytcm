import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../icons/phosphor_assets.dart';
import '../models/color_palette.dart';
import '../services/app_state.dart';
import '../services/appearance_preferences.dart';
import '../services/background_messaging.dart';
import '../services/notification_preferences.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../utils/profile_extras.dart';
import '../widgets/app_components.dart';
import '../widgets/log_status_bar.dart';
import '../widgets/phosphor_icon.dart';
import '../widgets/user_avatar.dart';
import 'profile_screen.dart';
import 'server_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final appearance = context.watch<AppearancePreferences>();
    final notifications = context.watch<NotificationPreferences>();
    final state = context.watch<AppState>();
    final me = state.me;
    final extras = ProfileExtras.parse(me?.additionalInfo);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        leading: embedded
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: PhosphorIcon(
                  adaptiveBackIcon(context),
                  size: adaptiveBackIconSize(context),
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text('Settings', style: AppTheme.heading(c, fontSize: 26)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              64,
            ),
            children: [
              Text(
                'Your YeChat',
                style: AppTheme.display(c, fontSize: 30),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Make the app feel right and keep your connection in view.',
                style: AppTheme.text(
                  c,
                  color: c.secondary,
                  fontSize: 14,
                ),
              ),
              if (me != null) ...[
                const SizedBox(height: AppSpace.xl),
                _AccountCard(
                  name: me.displayName,
                  username: me.username,
                  initials: me.initials,
                  avatarFileId: extras.avatarFileId,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              _SettingsPanel(
                title: 'Appearance',
                subtitle: 'Theme and accent colors',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: PhosphorIcon(PhosphorAssets.theme, size: 18),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: PhosphorIcon(PhosphorAssets.sun, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: PhosphorIcon(PhosphorAssets.moon, size: 18),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {appearance.mode},
                      onSelectionChanged: (selection) =>
                          appearance.setMode(selection.first),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text('Accent', style: AppTheme.listTitle(c)),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      appearance.palette.name,
                      style: AppTheme.caption(c),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      spacing: AppSpace.md,
                      runSpacing: AppSpace.md,
                      children: [
                        for (final palette in ColorPaletteOption.presets)
                          _PaletteButton(
                            option: palette,
                            selected: appearance.palette.id == palette.id,
                            onTap: () => appearance.setPaletteId(palette.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (NotificationPreferences.isMobilePlatform) ...[
                const SizedBox(height: AppSpace.xl),
                _SettingsPanel(
                  title: 'Notifications',
                  subtitle: 'Messages received while you appear offline',
                  padding: EdgeInsets.zero,
                  child: _SettingsRow(
                    icon: PhosphorAssets.bell,
                    title: 'Message notifications',
                    subtitle:
                        'Android controls exact background delivery time.',
                    trailing: AppSwitch(
                      value: notifications.enabled,
                      onChanged: (value) => _setNotifications(
                        context,
                        notifications,
                        value,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              _SettingsPanel(
                title: 'Connection',
                subtitle: 'Server configuration and diagnostics',
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: PhosphorAssets.server,
                      title: 'Server settings',
                      subtitle: 'Authentication, chat and file services',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServerSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: c.borderSoft),
                    const _DiagnosticsDisclosure(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              _SettingsPanel(
                title: 'Session',
                subtitle: 'This only signs out this device',
                padding: EdgeInsets.zero,
                child: _SettingsRow(
                  icon: PhosphorAssets.logout,
                  title: 'Sign out',
                  foreground: c.error,
                  onTap: () async {
                    await state.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setNotifications(
    BuildContext context,
    NotificationPreferences preferences,
    bool value,
  ) async {
    await preferences.setEnabled(value);
    if (!value) {
      await BackgroundMessaging.stop();
      return;
    }
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      await preferences.setEnabled(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow YeChat notifications in Android settings.'),
          ),
        );
      }
      return;
    }
    await BackgroundMessaging.ensureRunning();
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.username,
    required this.initials,
    required this.avatarFileId,
    required this.onTap,
  });

  final String name;
  final String username;
  final String initials;
  final String? avatarFileId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            UserAvatar(
              avatarFileId: avatarFileId,
              initials: initials,
              radius: 28,
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.heading(c, fontSize: 17)),
                  const SizedBox(height: AppSpace.xs),
                  Text('@$username', style: AppTheme.caption(c)),
                ],
              ),
            ),
            PhosphorIcon(
              PhosphorAssets.caretRight,
              color: c.tertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  final String title;
  final String subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTheme.heading(c, fontSize: 18)),
        const SizedBox(height: AppSpace.xs),
        Text(subtitle, style: AppTheme.caption(c)),
        const SizedBox(height: AppSpace.md),
        SurfaceCard(padding: padding, child: child),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.foreground,
    this.onTap,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final color = foreground ?? c.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        child: Row(
          children: [
            _IconTile(icon: icon, color: foreground),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.listTitle(c).copyWith(color: color),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(subtitle!, style: AppTheme.caption(c)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              PhosphorIcon(
                PhosphorAssets.caretRight,
                color: c.tertiary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.color});

  final String icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final foreground = color ?? c.accent;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color == null ? c.accentSoft : foreground.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Center(child: PhosphorIcon(icon, color: foreground, size: 18)),
    );
  }
}

class _DiagnosticsDisclosure extends StatefulWidget {
  const _DiagnosticsDisclosure();

  @override
  State<_DiagnosticsDisclosure> createState() => _DiagnosticsDisclosureState();
}

class _DiagnosticsDisclosureState extends State<_DiagnosticsDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Row(
              children: [
                const _IconTile(icon: PhosphorAssets.bug),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diagnostics', style: AppTheme.listTitle(c)),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Connection and server activity',
                        style: AppTheme.caption(c),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: AppMotion.base,
                  child: PhosphorIcon(
                    PhosphorAssets.caretDown,
                    color: _expanded ? c.accent : c.tertiary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.lg,
            ),
            child: LogStatusBar(inScrollView: true),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: AppMotion.base,
          sizeCurve: AppMotion.standard,
        ),
      ],
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ColorPaletteOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Semantics(
      button: true,
      selected: selected,
      label: option.name,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: AnimatedContainer(
          duration: AppMotion.base,
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? option.accent : c.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: ClipOval(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ColoredBox(color: option.accent)),
                Expanded(child: ColoredBox(color: option.companion)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
