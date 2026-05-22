import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Light haptic feedback on mobile; no-op elsewhere.
void messengerHapticLight() {
  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) return;
  HapticFeedback.lightImpact();
}

void messengerHapticSelection() {
  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) return;
  HapticFeedback.selectionClick();
}

void messengerHapticMedium() {
  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) return;
  HapticFeedback.mediumImpact();
}
