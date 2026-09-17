import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../utils/platform_ui.dart';
import '../widgets/phosphor_icon.dart';
import '../utils/messenger_snackbar.dart';
import '../utils/profile_extras.dart';
import '../widgets/app_components.dart';
import '../widgets/app_bottom_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _dateOfBirthCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _avatarFileId;
  List<Color>? _avatarColors;

  @override
  void initState() {
    super.initState();
    _syncFromState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().loadMyProfile();
      if (!mounted) return;
      setState(_syncFromState);
    });
  }

  void _syncFromState() {
    final me = context.read<AppState>().me;
    _firstNameCtrl.text = me?.firstName ?? '';
    _lastNameCtrl.text = me?.lastName ?? '';
    _usernameCtrl.text = me?.username ?? '';
    _dateOfBirthCtrl.text = me?.dateOfBirth ?? '';
    final extras = ProfileExtras.parse(me?.additionalInfo);
    _bioCtrl.text = extras.bio ?? '';
    _avatarFileId = extras.avatarFileId;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _dateOfBirthCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<String?> _pickAvatar() async {
    final state = context.read<AppState>();
    final fileId = await state.uploadAvatarImage();
    if (!mounted || fileId == null) return null;

    final ok = await state.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      dateOfBirth: _dateOfBirthCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      avatarFileId: fileId,
    );
    if (!mounted) return null;
    if (ok) {
      setState(() => _avatarFileId = fileId);
      showMessengerSnackBar(context, 'Avatar updated');
    }
    return fileId;
  }

  Future<void> _updateBackdropColors(Uint8List bytes) async {
    try {
      final colors = await _extractAvatarColors(bytes);
      if (mounted) setState(() => _avatarColors = colors);
    } catch (_) {
      // A malformed avatar should not prevent the profile from rendering.
    }
  }

  Future<void> _showEditProfile(String? avatarId) async {
    _syncFromState();
    var saving = false;
    await AppBottomSheet.show<void>(
      context,
      title: 'Edit profile',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: (MediaQuery.sizeOf(context).height * .68).clamp(420, 610),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.xl,
            ),
            children: [
              TextField(
                controller: _usernameCtrl,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'First name'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: TextField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _dateOfBirthCtrl,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  helperText: 'Use the format expected by your server',
                ),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _bioCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              LoadingButton(
                loading: saving,
                label: 'Save changes',
                onPressed: () async {
                  setSheetState(() => saving = true);
                  final ok = await context.read<AppState>().updateProfile(
                        firstName: _firstNameCtrl.text.trim(),
                        lastName: _lastNameCtrl.text.trim(),
                        username: _usernameCtrl.text.trim(),
                        dateOfBirth: _dateOfBirthCtrl.text.trim(),
                        bio: _bioCtrl.text.trim(),
                        avatarFileId: avatarId,
                      );
                  if (!mounted || !sheetContext.mounted) return;
                  setSheetState(() => saving = false);
                  if (!ok) {
                    showMessengerSnackBar(context, 'Could not update profile');
                    return;
                  }
                  Navigator.pop(sheetContext);
                  showMessengerSnackBar(this.context, 'Profile updated');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final state = context.watch<AppState>();
    final me = state.me;
    final extras = ProfileExtras.parse(me?.additionalInfo);
    final avatarId = _avatarFileId ?? extras.avatarFileId;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: PhosphorIcon(
                  adaptiveBackIcon(context),
                  size: adaptiveBackIconSize(context),
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          widget.embedded ? 'You' : 'Profile',
          style: AppTheme.heading(c, fontSize: 26),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: _AvatarProfileBackdrop(
                  avatarColors: _avatarColors,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          AvatarPicker(
                            currentFileId: avatarId,
                            fallbackInitials: me?.initials ?? '?',
                            radius: 48,
                            onPick: _pickAvatar,
                            onPicked: (id) =>
                                setState(() => _avatarFileId = id),
                            onImageLoaded: _updateBackdropColors,
                          ),
                          const SizedBox(height: AppSpace.lg),
                          Text(
                            me?.displayName ?? me?.username ?? '',
                            textAlign: TextAlign.center,
                            style: AppTheme.heading(c, fontSize: 24),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            '@${me?.username ?? ''}',
                            style: AppTheme.caption(c),
                          ),
                          if (extras.bio?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: AppSpace.md),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Text(
                                extras.bio!.trim(),
                                textAlign: TextAlign.center,
                                style: AppTheme.text(
                                  c,
                                  color: c.secondary,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpace.xl),
                          SizedBox(
                            width: 190,
                            child: OutlinedButton(
                              onPressed: () => _showEditProfile(avatarId),
                              child: const Text('Edit profile'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              const SectionLabel('Account'),
              const SizedBox(height: AppSpace.sm),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ProfileDetail(
                      label: 'Username',
                      value: '@${me?.username ?? ''}',
                    ),
                    if (me?.dateOfBirth?.isNotEmpty == true) ...[
                      Divider(height: 1, color: c.borderSoft),
                      _ProfileDetail(
                        label: 'Date of birth',
                        value: me!.dateOfBirth!,
                      ),
                    ],
                    Divider(height: 1, color: c.borderSoft),
                    _ProfileDetail(
                      label: 'User ID',
                      value: me?.uuid ?? '',
                      compactValue: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarProfileBackdrop extends StatelessWidget {
  const _AvatarProfileBackdrop({
    required this.avatarColors,
    required this.child,
  });

  final List<Color>? avatarColors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final colors = avatarColors ?? [c.accent, c.accentDim];
    final paletteKey = Object.hashAll(colors.map((color) => color.toARGB32()));
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: AppMotion.theme,
            switchInCurve: AppMotion.standard,
            switchOutCurve: AppMotion.standard,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current],
            ),
            child: CustomPaint(
              key: ValueKey(paletteKey),
              painter: _SoftAvatarBackdropPainter(
                surface: c.surface,
                primary: colors.first,
                secondary: colors.last,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

Future<List<Color>> _extractAvatarColors(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 40,
    targetHeight: 40,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return const [Color(0xFFD75F10), Color(0xFFA94F16)];

  final buckets = List.generate(12, (_) => _ColorBucket());
  for (var offset = 0; offset < data.lengthInBytes; offset += 4) {
    final alpha = data.getUint8(offset + 3);
    if (alpha < 180) continue;
    final color = Color.fromARGB(
      alpha,
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
    final hsv = HSVColor.fromColor(color);
    if (hsv.value < .08 || hsv.value > .96) continue;
    final weight = .2 + hsv.saturation * .8;
    buckets[(hsv.hue ~/ 30).clamp(0, 11)].add(color, weight);
  }
  buckets.sort((a, b) => b.weight.compareTo(a.weight));
  final first = buckets.first.color;
  final second = buckets
      .skip(1)
      .firstWhere(
        (bucket) => bucket.weight > 0,
        orElse: () => buckets.first,
      )
      .color;
  return [_pleasantBackdropColor(first), _pleasantBackdropColor(second)];
}

Color _pleasantBackdropColor(Color color) {
  final hsv = HSVColor.fromColor(color);
  return hsv
      .withSaturation(hsv.saturation.clamp(.38, .82).toDouble())
      .withValue(hsv.value.clamp(.42, .78).toDouble())
      .toColor();
}

class _ColorBucket {
  double red = 0;
  double green = 0;
  double blue = 0;
  double weight = 0;

  void add(Color color, double amount) {
    red += color.r * 255 * amount;
    green += color.g * 255 * amount;
    blue += color.b * 255 * amount;
    weight += amount;
  }

  Color get color {
    if (weight == 0) return const Color(0xFFD75F10);
    return Color.fromARGB(
      255,
      (red / weight).round(),
      (green / weight).round(),
      (blue / weight).round(),
    );
  }
}

class _SoftAvatarBackdropPainter extends CustomPainter {
  const _SoftAvatarBackdropPainter({
    required this.surface,
    required this.primary,
    required this.secondary,
  });

  final Color surface;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = surface);
    final blur = ui.MaskFilter.blur(
      ui.BlurStyle.normal,
      (size.shortestSide * .17).clamp(28, 54).toDouble(),
    );
    canvas.drawCircle(
      Offset(size.width * .16, size.height * .18),
      size.longestSide * .30,
      Paint()
        ..color = primary.withValues(alpha: .24)
        ..maskFilter = blur,
    );
    canvas.drawCircle(
      Offset(size.width * .86, size.height * .82),
      size.longestSide * .27,
      Paint()
        ..color = secondary.withValues(alpha: .20)
        ..maskFilter = blur,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftAvatarBackdropPainter oldDelegate) =>
      surface != oldDelegate.surface ||
      primary != oldDelegate.primary ||
      secondary != oldDelegate.secondary;
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.label,
    required this.value,
    this.compactValue = false,
  });

  final String label;
  final String value;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: AppTheme.caption(c)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: compactValue
                  ? AppTheme.timestamp(c, color: c.secondary)
                  : AppTheme.text(c, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
