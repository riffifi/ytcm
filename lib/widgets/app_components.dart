import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'phosphor_icon.dart';
import 'user_avatar.dart';

enum EmptyStateStyle { badge, tile }

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? message;
  final Widget? action;
  final EmptyStateStyle style;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.style = EmptyStateStyle.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: style == EmptyStateStyle.badge
                    ? c.accentSoft
                    : c.surfaceHigh,
                shape: style == EmptyStateStyle.badge
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: style == EmptyStateStyle.tile
                    ? BorderRadius.circular(AppRadius.lg)
                    : null,
              ),
              child: Center(
                child: PhosphorIcon(icon, color: c.accent, size: 30),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTheme.heading(c, fontSize: 20)),
            if (message != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(message!,
                  textAlign: TextAlign.center, style: AppTheme.caption(c)),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppTheme.sectionLabel(context.mc));
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool useCardTheme;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadius.lg,
    this.useCardTheme = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final content = Padding(padding: padding, child: child);
    if (useCardTheme) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      );
    }
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.borderSoft),
          ),
          child: content,
        ),
      ),
    );
  }
}

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: context.mc.accent,
      );
}

class LoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  const LoadingButton({
    super.key,
    required this.loading,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: outlined ? context.mc.accent : Colors.white,
      ),
    );
    if (outlined) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: loading ? spinner : Text(label),
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading ? spinner : Text(label),
    );
  }
}

enum InlineNoticeLevel { info, warning, error }

class InlineNotice extends StatelessWidget {
  final String message;
  final InlineNoticeLevel level;
  const InlineNotice(this.message,
      {super.key, this.level = InlineNoticeLevel.info});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final color = switch (level) {
      InlineNoticeLevel.info => c.accent,
      InlineNoticeLevel.warning => const Color(0xFFD7961D),
      InlineNoticeLevel.error => c.error,
    };
    final icon = switch (level) {
      InlineNoticeLevel.info => PhosphorAssets.info,
      InlineNoticeLevel.warning => PhosphorAssets.warning,
      InlineNoticeLevel.error => PhosphorAssets.warningCircle,
    };
    return SurfaceCard(
      useCardTheme: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhosphorIcon(icon, color: color, size: 20),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(message, style: AppTheme.caption(c))),
        ],
      ),
    );
  }
}

class AvatarPicker extends StatefulWidget {
  final String? currentFileId;
  final String fallbackInitials;
  final double radius;
  final Future<String?> Function() onPick;
  final ValueChanged<String> onPicked;
  final ValueChanged<Uint8List>? onImageLoaded;

  const AvatarPicker({
    super.key,
    this.currentFileId,
    required this.fallbackInitials,
    this.radius = 40,
    required this.onPick,
    required this.onPicked,
    this.onImageLoaded,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _loading = false;

  Future<void> _pick() async {
    if (_loading) return;
    setState(() => _loading = true);
    final id = await widget.onPick();
    if (!mounted) return;
    setState(() => _loading = false);
    if (id != null) widget.onPicked(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    return Semantics(
      button: true,
      label: 'Choose avatar',
      child: InkResponse(
        onTap: _pick,
        radius: widget.radius + AppSpace.md,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            UserAvatar(
              avatarFileId: widget.currentFileId,
              initials: widget.fallbackInitials,
              radius: widget.radius,
              onImageLoaded: widget.onImageLoaded,
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2),
                boxShadow: AppShadow.level1(c),
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const PhosphorIcon(
                        PhosphorAssets.camera,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
