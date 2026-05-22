import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a Phosphor icon from [SVGs/regular/] (stroke `currentColor`).
class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  static String assetPath(String name) => 'SVGs/regular/$name.svg';

  /// Sized for [InputDecoration.prefixIcon] / suffixIcon (M3 stretches raw widgets).
  static Widget forInput(
    String name, {
    Color? color,
    double size = 18,
  }) {
    return SizedBox(
      width: 40,
      height: 24,
      child: Center(
        child: PhosphorIcon(name, size: size, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color;
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        assetPath(name),
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: semanticLabel,
        colorFilter: effectiveColor != null
            ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
            : null,
      ),
    );
  }
}
