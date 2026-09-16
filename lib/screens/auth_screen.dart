import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../icons/phosphor_assets.dart';
import '../services/app_state.dart';
import '../services/server_settings.dart';
import '../theme.dart';
import '../widgets/phosphor_icon.dart';
import 'server_settings_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _registerPassword = TextEditingController();
  bool _hidePassword = true;
  bool _hideRegisterPassword = true;
  String _loginType = 'email';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
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
    final desktop = MediaQuery.sizeOf(context).width >= 860;
    return Scaffold(
      body: DecoratedBox(
        decoration: _backdrop(context),
        child: SafeArea(
          child: desktop
              ? Row(
                  children: [
                    const Expanded(flex: 5, child: _BrandPanel()),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: _card(context, state),
                        ),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Column(
                    children: [
                      const _BrandPanel(compact: true),
                      const SizedBox(height: 28),
                      _card(context, state),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  BoxDecoration _backdrop(BuildContext context) {
    final c = context.mc;
    return BoxDecoration(
      color: c.bg,
      gradient: RadialGradient(
        center: const Alignment(-0.9, -0.9),
        radius: 1.3,
        colors: [
          c.accent.withValues(alpha: 0.18),
          c.accentDim.withValues(alpha: 0.08),
          c.bg,
        ],
      ),
    );
  }

  Widget _card(BuildContext context, AppState state) {
    final c = context.mc;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 470),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 42,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome', style: AppTheme.heading(c, fontSize: 25)),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in or create your account.',
                      style: AppTheme.text(c, color: c.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Consumer<ServerSettings>(
                builder: (_, settings, __) => IconButton.filledTonal(
                  tooltip: settings.authUrl.isEmpty
                      ? 'Configure server'
                      : Uri.tryParse(settings.authUrl)?.host ??
                          'Server settings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ServerSettingsScreen(),
                    ),
                  ),
                  style: IconButton.styleFrom(backgroundColor: c.accentSoft),
                  icon: PhosphorIcon(
                    PhosphorAssets.server,
                    color: c.accent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TabBar(
              controller: _tabs,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: c.primary,
              unselectedLabelColor: c.tertiary,
              tabs: const [Tab(text: 'Sign in'), Tab(text: 'Create account')],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 430,
            child: TabBarView(
              controller: _tabs,
              children: [_loginForm(state), _registerForm(state)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginForm(AppState state) {
    final c = context.mc;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SIGN IN WITH', style: AppTheme.sectionLabel(c)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _loginChip('Email', 'email'),
              _loginChip('Phone', 'phone'),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _login,
            keyboardType: _loginType == 'email'
                ? TextInputType.emailAddress
                : TextInputType.phone,
            autofillHints: _loginType == 'email'
                ? const [AutofillHints.email]
                : const [AutofillHints.telephoneNumber],
            decoration: InputDecoration(
              labelText: _loginType == 'email' ? 'Email address' : 'Phone',
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
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
            _ErrorNotice(state.error!),
          ],
          const SizedBox(height: 22),
          _PrimaryAction(
            loading: state.loading,
            label: 'Continue to YeChat',
            onPressed: _signIn,
          ),
          const SizedBox(height: 16),
          Text(
            'Your connection details stay on this device.',
            textAlign: TextAlign.center,
            style: AppTheme.text(c, color: c.tertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _registerForm(AppState state) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_username, 'Username', PhosphorAssets.user),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            _passwordField(
              controller: _registerPassword,
              hidden: _hideRegisterPassword,
              onToggle: () => setState(
                () => _hideRegisterPassword = !_hideRegisterPassword,
              ),
              onSubmitted: _register,
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              _ErrorNotice(state.error!),
            ],
            const SizedBox(height: 18),
            _PrimaryAction(
              loading: state.loading,
              label: 'Create my account',
              onPressed: _register,
            ),
          ],
        ),
      );

  Widget _field(TextEditingController controller, String label, String icon) =>
      TextField(
        controller: controller,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: PhosphorIcon(icon, size: 20),
        ),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required bool hidden,
    required VoidCallback onToggle,
    required VoidCallback onSubmitted,
  }) =>
      TextField(
        controller: controller,
        obscureText: hidden,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const PhosphorIcon(PhosphorAssets.lock, size: 20),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: PhosphorIcon(
              hidden ? PhosphorAssets.eye : PhosphorAssets.eyeSlash,
              size: 20,
            ),
          ),
        ),
      );

  Widget _loginChip(String label, String value) {
    final selected = _loginType == value;
    final c = context.mc;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      onSelected: (_) => setState(() => _loginType = value),
      labelStyle: AppTheme.text(
        c,
        color: selected ? c.accent : c.secondary,
        fontSize: 13,
        wght: AppFontWeight.semibold,
      ),
    );
  }

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
    _tabs.animateTo(0);
    messenger.showSnackBar(
      const SnackBar(content: Text('Account created. You can sign in now.')),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 72 : 104,
          height: compact ? 72 : 104,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(compact ? 22 : 30),
            border: Border.all(color: c.borderSoft),
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.22),
                blurRadius: 42,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 25),
            child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: compact ? 16 : 30),
        Text('YeChat', style: AppTheme.display(c, fontSize: compact ? 36 : 58)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Conversations that feel close, even when people are far away.',
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: AppTheme.text(
              c,
              color: c.secondary,
              fontSize: compact ? 15 : 20,
              height: 1.45,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 36),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _feature(c, PhosphorAssets.bolt, 'Real time'),
              _feature(c, PhosphorAssets.lock, 'Private'),
              _feature(c, PhosphorAssets.devices, 'Everywhere'),
            ],
          ),
        ],
      ],
    );
    return compact
        ? content
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 56),
            child: Align(alignment: Alignment.centerLeft, child: content),
          );
  }

  Widget _feature(AppColors c, String icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, color: c.accent, size: 17),
            const SizedBox(width: 8),
            Text(label, style: AppTheme.text(c, fontSize: 13)),
          ],
        ),
      );
}

class _ErrorNotice extends StatelessWidget {
  final String message;
  const _ErrorNotice(this.message);

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhosphorIcon(PhosphorAssets.warningCircle, color: c.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.text(c, color: c.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;
  const _PrimaryAction({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      );
}
