import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/messenger_haptics.dart';
import 'app_bottom_sheet.dart';

/// Full-width emoji panel (bottom sheet) — avoids inline rebuild lag in the composer.
class EmojiPickerSheet extends StatelessWidget {
  final ValueChanged<Emoji> onEmojiSelected;

  const EmojiPickerSheet({super.key, required this.onEmojiSelected});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Emoji> onEmojiSelected,
  }) {
    messengerHapticSelection();
    return AppBottomSheet.show<void>(
      context,
      title: 'Emoji',
      builder: (_) => EmojiPickerSheet(onEmojiSelected: onEmojiSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final height =
        (MediaQuery.sizeOf(context).height * 0.42).clamp(280.0, 380.0);

    return SizedBox(
      height: height + bottom,
      child: Column(
        children: [
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                messengerHapticSelection();
                onEmojiSelected(emoji);
              },
              config: Config(
                height: height - 56,
                checkPlatformCompatibility: false,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: c.surface,
                  columns: 7,
                  emojiSizeMax: 28,
                  verticalSpacing: 6,
                  horizontalSpacing: 6,
                  gridPadding: const EdgeInsets.symmetric(horizontal: 8),
                  buttonMode: ButtonMode.MATERIAL,
                  loadingIndicator: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    ),
                  ),
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: c.surface,
                  dividerColor: c.borderSoft,
                  indicatorColor: c.accent,
                  iconColor: c.tertiary,
                  iconColorSelected: c.accent,
                  backspaceColor: c.secondary,
                  tabIndicatorAnimDuration: kTabScrollDuration,
                  initCategory: Category.RECENT,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  enabled: false,
                  backgroundColor: c.surface,
                ),
                skinToneConfig: const SkinToneConfig(enabled: true),
              ),
            ),
          ),
          SizedBox(height: bottom),
        ],
      ),
    );
  }
}
