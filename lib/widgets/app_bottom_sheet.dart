import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/platform_ui.dart';
import '../icons/phosphor_assets.dart';
import 'phosphor_icon.dart';

class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget> actions;

  const AppBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.actions = const [],
  });

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required WidgetBuilder builder,
  }) {
    if (isWideLayout(context)) {
      return showDialog<T>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: AppBottomSheet(title: title, child: builder(context)),
          ),
        ),
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => AppBottomSheet(
        title: title,
        child: builder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      padding: EdgeInsets.only(bottom: keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpace.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(title!, style: AppTheme.appBarTitle(c))),
                  ...actions,
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.maybePop(context),
                    icon: PhosphorIcon(
                      PhosphorAssets.close,
                      color: c.secondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}
