import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/file_service.dart';
import '../services/server_settings.dart';
import '../services/app_state.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_snackbar.dart';
import '../widgets/app_components.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late TextEditingController _authCtrl;
  late TextEditingController _chatCtrl;
  late TextEditingController _fileCtrl;
  late TextEditingController _tenorCtrl;
  bool _saving = false;
  String? _authPingResult;
  String? _chatPingResult;
  String? _filePingResult;
  bool _pingingAuth = false;
  bool _pingingChat = false;
  bool _pingingFile = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<ServerSettings>();
    _authCtrl = TextEditingController(text: s.authUrl);
    _chatCtrl = TextEditingController(text: s.chatUrl);
    _fileCtrl = TextEditingController(text: s.fileUrl);
    _tenorCtrl = TextEditingController(text: s.tenorApiKey ?? '');
  }

  @override
  void dispose() {
    _authCtrl.dispose();
    _chatCtrl.dispose();
    _fileCtrl.dispose();
    _tenorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final authUrl = _authCtrl.text.trim();
    final chatUrl = _chatCtrl.text.trim();
    final fileUrl = _fileCtrl.text.trim();

    if (!_isValidUrl(authUrl, requireHttp: true)) {
      _showError('Auth URL must start with http:// or https://');
      return;
    }
    if (!_isValidUrl(chatUrl, requireWs: true)) {
      _showError('Chat URL must start with ws:// or wss://');
      return;
    }
    if (!_isValidUrl(fileUrl, requireWs: true)) {
      _showError('File URL must start with ws:// or wss://');
      return;
    }

    setState(() => _saving = true);
    await context.read<ServerSettings>().save(
          authUrl,
          chatUrl,
          fileUrl,
          tenorApiKey: _tenorCtrl.text,
        );
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
      _authCtrl.text = ServerSettings.desktopAuthDefault;
      _chatCtrl.text = ServerSettings.desktopChatDefault;
      _fileCtrl.text = ServerSettings.desktopFileDefault;
      _tenorCtrl.clear();
      _authPingResult = null;
      _chatPingResult = null;
      _filePingResult = null;
    });
  }

  Future<void> _pingAuth() async {
    setState(() {
      _pingingAuth = true;
      _authPingResult = null;
    });
    final result = await AuthService(baseUrl: _authCtrl.text.trim()).ping();
    if (mounted) {
      setState(() {
        _pingingAuth = false;
        _authPingResult = result;
      });
    }
  }

  Future<void> _pingFile() async {
    setState(() {
      _pingingFile = true;
      _filePingResult = null;
    });
    final result =
        await FileService(wsUrl: _fileCtrl.text.trim()).pingReachability();
    if (mounted) {
      setState(() {
        _pingingFile = false;
        _filePingResult = result;
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
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (requireHttp) {
      return uri.scheme == 'http' || uri.scheme == 'https';
    }
    if (requireWs) return uri.scheme == 'ws' || uri.scheme == 'wss';
    return true;
  }

  void _showError(String msg) {
    final c = context.mc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTheme.text(c)),
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
          icon: PhosphorIcon(
            adaptiveBackIcon(context),
            size: adaptiveBackIconSize(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Server settings',
          style: AppTheme.heading(c, fontSize: 26),
        ),
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
            padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
            children: [
              const InlineNotice(
                'Use the same host/IP as your messenger servers (LAN IP on a phone, not 127.0.0.1). Saved here is used everywhere, including background notifications.',
              ),
              const SizedBox(height: 20),
              const SectionLabel('Auth service'),
              const SizedBox(height: 8),
              TextField(
                controller: _authCtrl,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.10:3000',
                  prefixIcon: PhosphorIcon.forInput(
                    PhosphorAssets.lock,
                    color: c.secondary,
                  ),
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
              const SectionLabel('Chat service'),
              const SizedBox(height: 8),
              TextField(
                controller: _chatCtrl,
                decoration: InputDecoration(
                  hintText: 'ws://192.168.1.10:3001/ws',
                  prefixIcon: PhosphorIcon.forInput(
                    PhosphorAssets.arrowsLeftRight,
                    color: c.secondary,
                  ),
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
              const SizedBox(height: 20),
              const SectionLabel('File service'),
              const SizedBox(height: 8),
              TextField(
                controller: _fileCtrl,
                decoration: InputDecoration(
                  hintText: 'ws://192.168.1.10:25463/ws',
                  prefixIcon: PhosphorIcon.forInput(
                    PhosphorAssets.attach,
                    color: c.secondary,
                  ),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 8),
              _pingRow(
                context: context,
                label: 'Test file service',
                loading: _pingingFile,
                result: _filePingResult,
                onPressed: _pingFile,
              ),
              const SizedBox(height: 6),
              Text('WebSocket — upload, download, and file sharing',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              const SectionLabel('Tenor API key (GIF search)'),
              const SizedBox(height: 8),
              TextField(
                controller: _tenorCtrl,
                decoration: InputDecoration(
                  hintText: 'Optional — uses built-in test key if empty',
                  prefixIcon: PhosphorIcon.forInput(
                    PhosphorAssets.gif,
                    color: c.secondary,
                  ),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 6),
              Text(
                'Get a free key at console.cloud.google.com (Tenor API). '
                'Leave blank to use the default search key.',
                style: AppTheme.caption(c),
              ),
              const SizedBox(height: 28),
              LoadingButton(
                loading: _saving,
                label: 'Save & apply',
                onPressed: _save,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _reset,
                child: const Text('Reset to defaults'),
              ),
            ],
          ),
        ),
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
    final normalizedResult = result?.toLowerCase();
    final failed = normalizedResult != null &&
        (normalizedResult.startsWith('failed') ||
            normalizedResult.contains('error') ||
            normalizedResult.contains('unavailable') ||
            normalizedResult.contains('not connected'));
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
              : const PhosphorIcon(
                  PhosphorAssets.pulse,
                  size: 16,
                  semanticLabel: 'Test connection',
                ),
          label: Text(label),
        ),
        if (result != null) ...[
          const SizedBox(height: 6),
          Text(
            result,
            style: AppTheme.caption(c, color: failed ? c.error : c.accent),
          ),
        ],
      ],
    );
  }
}
