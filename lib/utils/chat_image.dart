import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Thumbnail sizing for chat bubbles — keeps decode work small while scrolling.
class ChatImage {
  static const maxDisplayWidth = 260.0;
  static const maxDisplayHeight = 220.0;

  static int cacheWidth(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (maxDisplayWidth * dpr).round().clamp(64, 720);
  }

  static int cacheHeight(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (maxDisplayHeight * dpr).round().clamp(64, 720);
  }

  static Widget network(String url, AppColors colors) {
    return Builder(
      builder: (context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: maxDisplayWidth,
            height: maxDisplayHeight,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              cacheWidth: cacheWidth(context),
              cacheHeight: cacheHeight(context),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: colors.surfaceHigh,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => ColoredBox(
                color: colors.surfaceHigh,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.secondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget file(String path, AppColors colors) {
    return Builder(
      builder: (context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: maxDisplayWidth,
            height: maxDisplayHeight,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              cacheWidth: cacheWidth(context),
              cacheHeight: cacheHeight(context),
              errorBuilder: (_, __, ___) => ColoredBox(
                color: colors.surfaceHigh,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.secondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
