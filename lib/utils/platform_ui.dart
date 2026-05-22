import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Layout breakpoint for master–detail (desktop / tablet landscape).
const wideLayoutBreakpoint = 900.0;

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool isWideLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
}

bool useDesktopChrome(BuildContext context) =>
    isDesktopPlatform || isWideLayout(context);

IconData adaptiveBackIcon(BuildContext context) =>
    useDesktopChrome(context) ? Icons.arrow_back : Icons.arrow_back_ios;

double adaptiveBackIconSize(BuildContext context) =>
    useDesktopChrome(context) ? 22 : 18;
