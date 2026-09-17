import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../icons/phosphor_svg_data.dart';

enum PhosphorWeight { thin, light, regular, bold, fill, duotone }

extension on PhosphorWeight {
  String get folder => name;
}

/// Renders a Phosphor icon from the bundled SVG weight sets.
class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
    this.weight = PhosphorWeight.regular,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final PhosphorWeight weight;

  static String assetPath(
    String name, [
    PhosphorWeight weight = PhosphorWeight.regular,
  ]) {
    final suffix = weight == PhosphorWeight.regular ? '' : '-${weight.folder}';
    return 'SVGs/${weight.folder}/$name$suffix.svg';
  }

  static String? embeddedSvg(
    String name, [
    PhosphorWeight weight = PhosphorWeight.regular,
  ]) =>
      phosphorSvgData['${weight.folder}/$name'];

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
    final svg = embeddedSvg(name, weight);
    return SizedBox(
      width: size,
      height: size,
      child: svg == null
          ? CustomPaint(
              painter: _MissingIconPainter(
                color: effectiveColor ??
                    Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : SvgPicture.string(
              svg,
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

/// Keeps a stale or incomplete platform asset bundle from crashing the UI.
class _MissingIconPainter extends CustomPainter {
  const _MissingIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * .075).clamp(1.25, 2.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .34;
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * .45),
      Offset(center.dx, center.dy + radius * .08),
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius * .5),
      paint.strokeWidth * .65,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _MissingIconPainter oldDelegate) =>
      color != oldDelegate.color;
}
