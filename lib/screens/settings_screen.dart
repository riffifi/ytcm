import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/color_palette.dart';
import '../services/app_state.dart';
import '../services/appearance_preferences.dart';
import '../services/background_messaging.dart';
import '../services/notification_preferences.dart';
import '../services/notification_service.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/platform_ui.dart';
import '../widgets/log_status_bar.dart';
import 'profile_screen.dart';
import 'server_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final appearance = context.watch<AppearancePreferences>();
    final notifPrefs = context.watch<NotificationPreferences>();
    final state = context.watch<AppState>();
    final me = state.me;

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
        title: Text('Settings', style: AppTheme.heading(c, fontSize: 26)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
          if (me != null) ...[
            const _SectionLabel('Account'),
            const SizedBox(height: 10),
            _NavTile(
              icon: PhosphorAssets.user,
              label: 'Profile',
              subtitle: '@${me.username}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
          const _SectionLabel('Appearance'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.borderSoft),
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('Dark'),
                  ),
                ],
                selected: {appearance.mode},
                onSelectionChanged: (selection) =>
                    appearance.setMode(selection.first),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Color story',
            style: TextStyle(color: c.secondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in ColorPaletteOption.presets)
                _PaletteChip(
                  option: option,
                  selected: appearance.palette.id == option.id,
                  onTap: () => appearance.setPaletteId(option.id),
                ),
            ],
          ),
          if (NotificationPreferences.isMobilePlatform) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Notifications'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Message notifications',
                  style: TextStyle(color: c.primary, fontSize: 15),
                ),
                subtitle: Text(
                  'Checks for new messages in the background while your account remains offline. Android controls the exact delivery time.',
                  style: TextStyle(color: c.secondary, fontSize: 12),
                ),
                value: notifPrefs.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: c.accent,
                onChanged: (v) async {
                  await notifPrefs.setEnabled(v);
                  if (v) {
                    final granted =
                        await NotificationService.instance.requestPermission();
                    if (!granted) {
                      await notifPrefs.setEnabled(false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Allow YeChat notifications in Android settings.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await BackgroundMessaging.ensureRunning();
                  } else {
                    await BackgroundMessaging.stop();
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionLabel('Diagnostics'),
          const SizedBox(height: 6),
          Text(
            'Connection and server messages for troubleshooting.',
            style: TextStyle(color: c.secondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const LogStatusBar(inScrollView: true),
          const SizedBox(height: 24),
          const _SectionLabel('Server'),
          const SizedBox(height: 10),
          _NavTile(
            icon: PhosphorAssets.server,
            label: 'Server settings',
            subtitle: 'Auth and chat URLs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Session'),
          const SizedBox(height: 10),
          _NavTile(
            icon: PhosphorAssets.logout,
            label: 'Sign out',
            subtitle: null,
            labelColor: c.error,
            onTap: () async {
              await state.logout();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
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

class _NavTile extends StatelessWidget {
  final String icon;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final fg = labelColor ?? c.primary;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              PhosphorIcon(icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: c.secondary, fontSize: 12),
                      ),
                    ],
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
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final ColorPaletteOption option;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? option.accent : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [option.accent, option.companion],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                option.name,
                style: TextStyle(
                  color: selected ? c.primary : c.secondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
