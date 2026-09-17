import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../icons/phosphor_assets.dart';
import '../services/app_state.dart';
import '../services/server_settings.dart';
import '../theme.dart';
import '../widgets/app_components.dart';
import '../widgets/phosphor_icon.dart';
import 'server_settings_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _registerPassword = TextEditingController();

  bool _showAuth = false;
  bool _registering = false;
  bool _hidePassword = true;
  bool _hideRegisterPassword = true;
  String _loginType = 'email';

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.mc;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppMotion.enter,
          switchInCurve: AppMotion.standard,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.025, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _showAuth ? _authPage(state, c) : _onboarding(c),
        ),
      ),
    );
  }

  Widget _onboarding(AppColors c) => LayoutBuilder(
        key: const ValueKey('onboarding'),
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 650;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 44),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _serverButton(),
                    ),
                    const Spacer(flex: 3),
                    Container(
                      width: compact ? 92 : 116,
                      height: compact ? 92 : 116,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(compact ? 28 : 36),
                        border: Border.all(color: c.borderSoft),
                        boxShadow: AppShadow.accentGlow(c),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(compact ? 23 : 31),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 30),
                    Text(
                      'YeChat',
                      style: AppTheme.display(c, fontSize: compact ? 38 : 46),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 370),
                      child: Text(
                        'Simple, fast (at times), unfinished at the moment.\nBut we are working on it.',
                        textAlign: TextAlign.center,
                        style: AppTheme.text(
                          c,
                          color: c.secondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () => setState(() {
                              _registering = false;
                              _showAuth = true;
                            }),
                            child: const Text('Start messaging'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _registering = true;
                              _showAuth = true;
                            }),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _authPage(AppState state, AppColors c) => Column(
        key: const ValueKey('auth'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to welcome',
                  onPressed: () => setState(() => _showAuth = false),
                  icon: const PhosphorIcon(PhosphorAssets.back),
                ),
                const Spacer(),
                _serverButton(),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 58).clamp(0, 10000),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 410),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _wordmark(c),
                            const SizedBox(height: 40),
                            Text(
                              _registering
                                  ? 'Create your account'
                                  : 'Welcome back',
                              style: AppTheme.display(c, fontSize: 31),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _registering
                                  ? 'A username and one contact method are all you need.'
                                  : 'Sign in to continue your conversations.',
                              style: AppTheme.text(
                                c,
                                color: c.secondary,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 30),
                            AnimatedSwitcher(
                              duration: AppMotion.base,
                              child: KeyedSubtree(
                                key: ValueKey(_registering),
                                child: _registering
                                    ? _registerForm(state)
                                    : _loginForm(state),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _modeSwitch(c), // fix me: refer to (auth_screen.dart, #1)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _wordmark(AppColors c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Text('YeChat', style: AppTheme.heading(c, fontSize: 20)),
        ],
      );

  Widget _loginForm(AppState state) {
    final c = context.mc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _loginMethodPicker(c),
        const SizedBox(height: 18),
        TextField(
          controller: _login,
          keyboardType: _loginType == 'email'
              ? TextInputType.emailAddress
              : TextInputType.phone,
          autofillHints: _loginType == 'email'
              ? const [AutofillHints.email]
              : const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: _loginType == 'email' ? 'Email address' : 'Phone number',
          ),
        ),
        const SizedBox(height: 14),
        _passwordField(
          controller: _password,
          hidden: _hidePassword,
          onToggle: () => setState(() => _hidePassword = !_hidePassword),
          onSubmitted: _signIn,
        ),
        if (state.error != null) ...[
          const SizedBox(height: 14),
          InlineNotice(state.error!, level: InlineNoticeLevel.error),
        ],
        const SizedBox(height: 22),
        LoadingButton(
          loading: state.loading,
          label: 'Continue',
          onPressed: _signIn,
        ),
      ],
    );
  }

  Widget _registerForm(AppState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            _username,
            'Username',
            autofillHints: const [AutofillHints.newUsername],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _field(
            _email,
            'Email (optional)',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _field(
            _phone,
            'Phone (optional)',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _passwordField(
            controller: _registerPassword,
            hidden: _hideRegisterPassword,
            onToggle: () => setState(
              () => _hideRegisterPassword = !_hideRegisterPassword,
            ),
            onSubmitted: _register,
            newPassword: true,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 14),
            InlineNotice(state.error!, level: InlineNoticeLevel.error),
          ],
          const SizedBox(height: 22),
          LoadingButton(
            loading: state.loading,
            label: 'Create account',
            onPressed: _register,
          ),
        ],
      );

  Widget _loginMethodPicker(AppColors c) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _loginMethod(c, 'Email', 'email'),
            _loginMethod(c, 'Phone', 'phone'),
          ],
        ),
      );

  Widget _loginMethod(AppColors c, String label, String value) {
    final selected = _loginType == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _loginType = value),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: selected ? AppShadow.level1(c) : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.text(
                c,
                color: selected ? c.primary : c.tertiary,
                fontSize: 13,
                wght: selected ? AppFontWeight.semibold : AppFontWeight.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeSwitch(AppColors c) => Row( // fix me: smooth natural animation (auth_screen.dart, #1)
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _registering ? 'Already have an account?' : 'New to YeChat?',
            style: AppTheme.text(c, color: c.secondary, fontSize: 13),
          ),
          TextButton(
            onPressed: () => setState(() => _registering = !_registering),
            child: Text(_registering ? 'Sign in' : 'Create account'),
          ),
        ],
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    TextInputAction? action,
  }) =>
      TextField(
        controller: controller,
        autocorrect: false,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: action,
        decoration: InputDecoration(labelText: label),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required bool hidden,
    required VoidCallback onToggle,
    required VoidCallback onSubmitted,
    bool newPassword = false,
  }) =>
      TextField(
        controller: controller,
        obscureText: hidden,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: [
          newPassword ? AutofillHints.newPassword : AutofillHints.password,
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            tooltip: hidden ? 'Show password' : 'Hide password',
            onPressed: onToggle,
            icon: PhosphorIcon(
              hidden ? PhosphorAssets.eye : PhosphorAssets.eyeSlash,
              size: 20, // fix me: eye icon too small (auth_screen.dart, #2)
            ),
          ),
        ),
      );

  Widget _serverButton() => Consumer<ServerSettings>(
        builder: (_, settings, __) => IconButton(
          tooltip: settings.authUrl.isEmpty
              ? 'Configure server'
              : Uri.tryParse(settings.authUrl)?.host ?? 'Server settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
          ),
          icon: const PhosphorIcon(PhosphorAssets.server, size: 21),
        ),
      );

  void _signIn() => context.read<AppState>().login(
        _login.text.trim(),
        _password.text,
        loginType: _loginType,
      );

  Future<void> _register() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<AppState>().register(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _registerPassword.text,
          phone: _phone.text.trim(),
        );
    if (!mounted || !ok) return;
    setState(() => _registering = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Account created. You can sign in now.')),
    );
  }
}
