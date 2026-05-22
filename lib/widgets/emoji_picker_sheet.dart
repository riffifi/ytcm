import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/messenger_haptics.dart';

/// Full-width emoji panel (bottom sheet) — avoids inline rebuild lag in the composer.
class EmojiPickerSheet extends StatelessWidget {
  final ValueChanged<Emoji> onEmojiSelected;

  const EmojiPickerSheet({super.key, required this.onEmojiSelected});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Emoji> onEmojiSelected,
  }) {
    messengerHapticSelection();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => EmojiPickerSheet(onEmojiSelected: onEmojiSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * 0.42).clamp(280.0, 380.0);

    return Container(
      height: height + bottom,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Text(
                  'Emoji',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.secondary, size: 22),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
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
