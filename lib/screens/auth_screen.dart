import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/server_settings.dart';
import '../theme.dart';
import 'server_settings_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureReg = true;
  String _loginType = 'email';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final width = MediaQuery.of(context).size.width;

    if (width >= 900) {
      return _desktopLayout(state);
    } else if (width >= 600) {
      return _tabletLayout(state);
    } else {
      return _phoneLayout(state);
    }
  }

  // ─── Phone layout ────────────────────────────────────────────────────────────

  Widget _phoneLayout(AppState state) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              _brandHeader(),
              const SizedBox(height: 40),
              _buildTabBar(),
              const SizedBox(height: 28),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [_loginForm(state), _registerForm(state)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tablet layout ───────────────────────────────────────────────────────────

  Widget _tabletLayout(AppState state) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandHeader(),
                  const SizedBox(height: 48),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabBar(),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 420,
                          child: TabBarView(
                            controller: _tab,
                            children: [_loginForm(state), _registerForm(state)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Desktop layout ──────────────────────────────────────────────────────────

  Widget _desktopLayout(AppState state) {
    return Scaffold(
      body: Row(
        children: [
          // Left branding panel
          Expanded(
            flex: 5,
            child: Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'YTCm',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Minimal. Secure. Fast.',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _featurePill(Icons.lock_outline, 'End-to-end encrypted'),
                  const SizedBox(height: 12),
                  _featurePill(Icons.bolt_outlined, 'Real-time messaging'),
                  const SizedBox(height: 12),
                  _featurePill(Icons.devices_outlined, 'Cross-platform'),
                  const Spacer(),
                  _serverBadge(),
                ],
              ),
            ),
          ),
          // Divider
          Container(width: 1, color: AppTheme.border),
          // Right form panel
          Expanded(
            flex: 4,
            child: Container(
              color: AppTheme.surfaceHigh,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabBar(),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 440,
                          child: TabBarView(
                            controller: _tab,
                            children: [
                              _loginForm(context.watch<AppState>()),
                              _registerForm(context.watch<AppState>()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: AppTheme.secondary, fontSize: 14)),
      ],
    );
  }

  Widget _serverBadge() {
    return Consumer<ServerSettings>(
      builder: (_, s, __) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dns_outlined,
                  color: AppTheme.secondary, size: 14),
              const SizedBox(width: 6),
              Text(
                _hostOnly(s.authUrl),
                style: const TextStyle(
                    color: AppTheme.secondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared header (phone / tablet) ──────────────────────────────────────────

  Widget _brandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Messenger',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Minimal. Secure. Fast.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ServerSettingsScreen()),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dns_outlined,
                    color: AppTheme.secondary, size: 13),
                const SizedBox(width: 5),
                Consumer<ServerSettings>(
                  builder: (_, s, __) => Text(
                    _hostOnly(s.authUrl),
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 11,
                    ),
                  ), // ← FIX: was missing closing ) for Text(
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.secondary,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Sign in'), Tab(text: 'Register')],
      ),
    );
  }

  // ─── Login form ───────────────────────────────────────────────────────────────

  Widget _loginForm(AppState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: ['email', 'phone'].map((t) {
              final selected = _loginType == t;
              return GestureDetector(
                onTap: () => setState(() => _loginType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accentSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected
                            ? AppTheme.accent
                            : AppTheme.border),
                  ),
                  child: Text(
                    t == 'email' ? 'Email' : 'Phone',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppTheme.accent
                          : AppTheme.secondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginCtrl,
            keyboardType: _loginType == 'email'
                ? TextInputType.emailAddress
                : TextInputType.phone,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: InputDecoration(
              hintText: _loginType == 'email' ? 'Email' : 'Phone number',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.secondary,
                  size: 18,
                ),
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(state.error!),
          ],
          const SizedBox(height: 24),
          state.loading
              ? _loadingButton()
              : ElevatedButton(
                  onPressed: () async {
                    await context.read<AppState>().login(
                          _loginCtrl.text.trim(),
                          _passCtrl.text,
                          loginType: _loginType,
                        );
                  },
                  child: const Text('Sign in'),
                ),
        ],
      ),
    );
  }

  // ─── Register form ────────────────────────────────────────────────────────────

  Widget _registerForm(AppState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _usernameCtrl,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Phone number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regPassCtrl,
            obscureText: _obscureReg,
            style: const TextStyle(color: AppTheme.primary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscureReg = !_obscureReg),
                child: Icon(
                  _obscureReg
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.secondary,
                  size: 18,
                ),
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(state.error!),
          ],
          const SizedBox(height: 24),
          state.loading
              ? _loadingButton()
              : ElevatedButton(
                  onPressed: () async {
                    final ok =
                        await context.read<AppState>().register(
                              username: _usernameCtrl.text.trim(),
                              email: _emailCtrl.text.trim(),
                              password: _regPassCtrl.text,
                              phone: _phoneCtrl.text.trim(),
                            );
                    if (ok && mounted) {
                      _tab.animateTo(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Account created — sign in now'),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    }
                  },
                  child: const Text('Create account'),
                ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _errorBanner(String msg) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),   // FIX: was withOpacity
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.3)),         // FIX: was withOpacity
      ),
      child: Text(msg,
          style: const TextStyle(color: AppTheme.error, fontSize: 13)),
    );
  }

  Widget _loadingButton() {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.5),             // FIX: was withOpacity
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }

  String _hostOnly(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.isEmpty ? url : uri.host;
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '$host$port';
    } catch (_) {
      return url;
    }
  }
}