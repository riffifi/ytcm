import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'server_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<AppState>().me;
    _firstNameCtrl.text = me?.firstName ?? '';
    _lastNameCtrl.text = me?.lastName ?? '';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      me?.initials ?? '?',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('@${me?.username ?? ''}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(me?.uuid ?? '',
                      style: const TextStyle(
                          color: AppTheme.secondary, fontSize: 10)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          _SectionLabel('Profile info'),
          const SizedBox(height: 12),
          TextField(
            controller: _firstNameCtrl,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'First name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameCtrl,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Last name'),
          ),
          const SizedBox(height: 20),
          _saving
              ? Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: () async {
                    setState(() => _saving = true);
                    final token = state.token!;
                    await state.auth.changeFirstName(
                        token, _firstNameCtrl.text.trim());
                    await state.auth.changeLastName(
                        token, _lastNameCtrl.text.trim());
                    setState(() => _saving = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated'),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    }
                  },
                  child: const Text('Save changes'),
                ),
          const SizedBox(height: 32),
          _SectionLabel('Account'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.dns_outlined,
            label: 'Server settings',
            color: AppTheme.secondary,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.logout,
            label: 'Sign out',
            color: AppTheme.error,
            onTap: () async {
              await state.logout();
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: AppTheme.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8),
      );
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
