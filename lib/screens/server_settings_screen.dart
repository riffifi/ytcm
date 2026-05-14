import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_settings.dart';
import '../services/app_state.dart';
import '../theme.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late TextEditingController _authCtrl;
  late TextEditingController _chatCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<ServerSettings>();
    _authCtrl = TextEditingController(text: s.authUrl);
    _chatCtrl = TextEditingController(text: s.chatUrl);
  }

  @override
  void dispose() {
    _authCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final authUrl = _authCtrl.text.trim();
    final chatUrl = _chatCtrl.text.trim();

    if (!_isValidUrl(authUrl, requireHttp: true)) {
      _showError('Auth URL must start with http:// or https://');
      return;
    }
    if (!_isValidUrl(chatUrl, requireWs: true)) {
      _showError('Chat URL must start with ws:// or wss://');
      return;
    }

    setState(() => _saving = true);
    await context.read<ServerSettings>().save(authUrl, chatUrl);
    // Reconnect if logged in
    if (mounted) {
      await context.read<AppState>().reconnectWithNewSettings();
    }
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppTheme.surface,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _reset() async {
    final settings = context.read<ServerSettings>();
    await settings.reset();
    setState(() {
      _authCtrl.text = ServerSettings.defaultAuthUrl;
      _chatCtrl.text = ServerSettings.defaultChatUrl;
    });
  }

  bool _isValidUrl(String url, {bool requireHttp = false, bool requireWs = false}) {
    if (url.isEmpty) return false;
    if (requireHttp) return url.startsWith('http://') || url.startsWith('https://');
    if (requireWs) return url.startsWith('ws://') || url.startsWith('wss://');
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error.withOpacity(0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Server settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _infoBox(),
          const SizedBox(height: 24),
          _label('Auth service'),
          const SizedBox(height: 8),
          TextField(
            controller: _authCtrl,
            decoration: const InputDecoration(
              hintText: 'http://127.0.0.1:3000',
              prefixIcon: Icon(Icons.lock_outline,
                  color: AppTheme.secondary, size: 16),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 6),
          Text('HTTP — used for login, register, profile',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _label('Chat service'),
          const SizedBox(height: 8),
          TextField(
            controller: _chatCtrl,
            decoration: const InputDecoration(
              hintText: 'ws://127.0.0.1:3001/ws',
              prefixIcon: Icon(Icons.swap_horiz,
                  color: AppTheme.secondary, size: 16),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 6),
          Text('WebSocket — used for real-time messaging',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _saving
              ? _loadingButton()
              : ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save & apply'),
                ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _reset,
            child: const Text('Reset to defaults'),
          ),
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Configure the addresses of your Rust messenger backend. '
              'Changes take effect immediately.',
              style: TextStyle(
                color: AppTheme.accent.withOpacity(0.85),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: AppTheme.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8),
      );

  Widget _loadingButton() => Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      );
}
