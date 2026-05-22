import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/color_palette.dart';
import '../services/app_state.dart';
import '../services/appearance_preferences.dart';
import '../services/notification_preferences.dart';
import '../theme.dart';
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
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (me != null) ...[
            _SectionLabel('Account'),
            const SizedBox(height: 10),
            _NavTile(
              icon: Icons.person_outline,
              label: 'Profile',
              subtitle: '@${me.username}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
          _SectionLabel('Appearance'),
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
                'Light theme',
                style: TextStyle(color: c.primary, fontSize: 15),
              ),
              subtitle: Text(
                'White background',
                style: TextStyle(color: c.secondary, fontSize: 12),
              ),
              value: appearance.isLight,
              activeThumbColor: Colors.white,
              activeTrackColor: c.accent,
              onChanged: (v) => appearance.setLight(v),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Accent color',
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
            _SectionLabel('Notifications'),
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
                  'Alerts when the app is in the background',
                  style: TextStyle(color: c.secondary, fontSize: 12),
                ),
                value: notifPrefs.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: c.accent,
                onChanged: (v) => notifPrefs.setEnabled(v),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionLabel('Server'),
          const SizedBox(height: 10),
          _NavTile(
            icon: Icons.dns_outlined,
            label: 'Server settings',
            subtitle: 'Auth and chat URLs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Session'),
          const SizedBox(height: 10),
          _NavTile(
            icon: Icons.logout,
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

class _NavTile extends StatelessWidget {
  final IconData icon;
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
              Icon(icon, color: fg, size: 20),
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
              Icon(Icons.chevron_right, color: c.tertiary, size: 18),
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
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: option.accent,
                  shape: BoxShape.circle,
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
