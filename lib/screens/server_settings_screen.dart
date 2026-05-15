import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/server_settings.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/messenger_snackbar.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late TextEditingController _authCtrl;
  late TextEditingController _chatCtrl;
  bool _saving = false;
  String? _authPingResult;
  String? _chatPingResult;
  bool _pingingAuth = false;
  bool _pingingChat = false;

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
    if (mounted) {
      await context.read<AppState>().reconnectWithNewSettings();
    }
    setState(() => _saving = false);
    if (mounted) {
      showMessengerSnackBar(context, 'Settings saved');
      Navigator.pop(context);
    }
  }

  Future<void> _reset() async {
    final settings = context.read<ServerSettings>();
    await settings.reset();
    setState(() {
      _authCtrl.text = ServerSettings.defaultAuthUrl;
      _chatCtrl.text = ServerSettings.defaultChatUrl;
      _authPingResult = null;
      _chatPingResult = null;
    });
  }

  Future<void> _pingAuth() async {
    setState(() {
      _pingingAuth = true;
      _authPingResult = null;
    });
    final result =
        await AuthService(baseUrl: _authCtrl.text.trim()).ping();
    if (mounted) {
      setState(() {
        _pingingAuth = false;
        _authPingResult = result;
      });
    }
  }

  Future<void> _pingChat() async {
    setState(() {
      _pingingChat = true;
      _chatPingResult = null;
    });
    final state = context.read<AppState>();
    final wsUrl = _chatCtrl.text.trim();

    var result = await ChatService(wsUrl: wsUrl).pingReachability();
    if (state.isLoggedIn) {
      final sessionResult = await state.pingChatSession();
      result = '$result\n$sessionResult';
    }

    if (mounted) {
      setState(() {
        _pingingChat = false;
        _chatPingResult = result;
      });
    }
  }

  bool _isValidUrl(String url,
      {bool requireHttp = false, bool requireWs = false}) {
    if (url.isEmpty) return false;
    if (requireHttp) {
      return url.startsWith('http://') || url.startsWith('https://');
    }
    if (requireWs) return url.startsWith('ws://') || url.startsWith('wss://');
    return true;
  }

  void _showError(String msg) {
    final c = context.mc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: c.primary)),
        backgroundColor: c.error.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Server settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        children: [
          _infoBox(context),
          const SizedBox(height: 20),
          _label(context, 'Auth service'),
          const SizedBox(height: 8),
          TextField(
            controller: _authCtrl,
            decoration: InputDecoration(
              hintText: 'http://127.0.0.1:3000',
              prefixIcon: Icon(Icons.lock_outline,
                  color: c.secondary, size: 16),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          _pingRow(
            context: context,
            label: 'Test auth',
            loading: _pingingAuth,
            result: _authPingResult,
            onPressed: _pingAuth,
          ),
          const SizedBox(height: 6),
          Text('HTTP — login, register, profile',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _label(context, 'Chat service'),
          const SizedBox(height: 8),
          TextField(
            controller: _chatCtrl,
            decoration: InputDecoration(
              hintText: 'ws://127.0.0.1:3001/ws',
              prefixIcon: Icon(Icons.swap_horiz,
                  color: c.secondary, size: 16),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          _pingRow(
            context: context,
            label: 'Test chat',
            loading: _pingingChat,
            result: _chatPingResult,
            onPressed: _pingChat,
          ),
          const SizedBox(height: 6),
          Text('WebSocket — real-time messaging',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          _saving
              ? _loadingButton(context)
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

  Widget _pingRow({
    required BuildContext context,
    required String label,
    required bool loading,
    required String? result,
    required VoidCallback onPressed,
  }) {
    final c = context.mc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_ping, size: 16),
          label: Text(label),
        ),
        if (result != null) ...[
          const SizedBox(height: 6),
          Text(
            result,
            style: TextStyle(
              color: result.startsWith('Failed') || result.contains('Not connected')
                  ? c.error
                  : c.accent,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoBox(BuildContext context) {
    final c = context.mc;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: c.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'On Android emulator use 10.0.2.2 instead of 127.0.0.1. '
              'On a physical device use your computer\'s LAN IP.',
              style: TextStyle(
                color: c.accent.withValues(alpha: 0.85),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
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

  Widget _loadingButton(BuildContext context) {
    final c = context.mc;
    return Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.5),
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
}
