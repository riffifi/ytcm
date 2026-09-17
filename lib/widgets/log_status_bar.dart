import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/messenger_log.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'phosphor_icon.dart';
import '../utils/messenger_haptics.dart';
import '../utils/messenger_snackbar.dart';

/// Activity / debug log. Use [inScrollView] inside Settings (not under an app bar).
class LogStatusBar extends StatefulWidget {
  final ValueChanged<double>? onHeightChanged;

  /// When true, lays out inside a scroll view without fixed app-bar height.
  final bool inScrollView;

  const LogStatusBar({
    super.key,
    this.onHeightChanged,
    this.inScrollView = false,
  });

  static const expandedPanelHeight = 260.0;

  @override
  State<LogStatusBar> createState() => _LogStatusBarState();
}

class _LogStatusBarState extends State<LogStatusBar> {
  bool _expanded = false;

  double _heightFor(bool expanded, MessengerLog log) {
    final hasContent =
        (log.banner != null && log.banner!.isNotEmpty) || !log.isEmpty;
    if (!hasContent) return 1;
    final panel = expanded ? LogStatusBar.expandedPanelHeight : 0.0;
    return _collapsedBarHeight + panel;
  }

  static const _collapsedBarHeight = 36.0;

  void _setExpanded(bool value, MessengerLog log) {
    if (!widget.inScrollView) {
      widget.onHeightChanged?.call(_heightFor(value, log));
    }
    setState(() => _expanded = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final log = context.watch<MessengerLog>();
    final banner = log.banner;
    final hasContent = (banner != null && banner.isNotEmpty) || !log.isEmpty;

    if (!hasContent) {
      if (!widget.inScrollView) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onHeightChanged?.call(1);
        });
        return Container(height: 1, color: c.border);
      }
      return _emptyLogCard(c);
    }

    final level = log.bannerLevel ?? LogLevel.info;
    final accent = _levelColor(c, level);

    final header = _LogHeader(
      banner: banner,
      level: level,
      accent: accent,
      hasErrors: log.hasErrors,
      expanded: _expanded,
      onTap: () {
        messengerHapticSelection();
        _setExpanded(!_expanded, log);
      },
    );

    if (widget.inScrollView) {
      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (_expanded)
              SizedBox(
                height: LogStatusBar.expandedPanelHeight,
                child: _LogPanel(log: log),
              ),
          ],
        ),
      );
    }

    final totalHeight = _heightFor(_expanded, log);
    return SizedBox(
      height: totalHeight,
      child: Material(
        color: c.surfaceHigh,
        child: Column(
          children: [
            header,
            if (_expanded)
              SizedBox(
                height: LogStatusBar.expandedPanelHeight,
                child: _LogPanel(log: log),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyLogCard(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.border),
      ),
      child: Text(
        'No log entries yet',
        style: AppTheme.caption(c, color: c.tertiary),
      ),
    );
  }

  Color _levelColor(AppColors c, LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return c.error;
      case LogLevel.warn:
        return c.accent;
      case LogLevel.info:
        return c.secondary;
      case LogLevel.debug:
        return c.tertiary;
    }
  }
}

class _LogHeader extends StatelessWidget {
  final String? banner;
  final LogLevel level;
  final Color accent;
  final bool hasErrors;
  final bool expanded;
  final VoidCallback onTap;

  const _LogHeader({
    required this.banner,
    required this.level,
    required this.accent,
    required this.hasErrors,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mc;

    return Material(
      color: c.surfaceHigh,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                PhosphorIcon(_levelIcon(level), size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    banner ?? 'Activity log — tap to expand',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.timestamp(c,
                        color: level == LogLevel.error ? c.error : c.secondary),
                  ),
                ),
                if (hasErrors)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                PhosphorIcon(
                  expanded ? PhosphorAssets.caretUp : PhosphorAssets.caretDown,
                  size: 18,
                  color: c.tertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _levelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return PhosphorAssets.warningCircle;
      case LogLevel.warn:
        return PhosphorAssets.warning;
      case LogLevel.info:
        return PhosphorAssets.info;
      case LogLevel.debug:
        return PhosphorAssets.bug;
    }
  }
}

class _LogPanel extends StatelessWidget {
  final MessengerLog log;

  const _LogPanel({required this.log});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final entries = log.entries;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderSoft)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
            child: Row(
              children: [
                Text(
                  'LOG (${entries.length})',
                  style: AppTheme.sectionLabel(c),
                ),
                const Spacer(),
                TextButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: log.exportText()),
                          );
                          if (context.mounted) {
                            showMessengerSnackBar(context, 'Log copied');
                          }
                        },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Copy',
                    style: AppTheme.timestamp(c, color: c.accent),
                  ),
                ),
                TextButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () {
                          messengerHapticSelection();
                          log.clear();
                        },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Clear',
                    style: AppTheme.timestamp(c, color: c.secondary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No log entries yet',
                      style: AppTheme.caption(c, color: c.tertiary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _LogLine(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final color = switch (entry.level) {
      LogLevel.error => c.error,
      LogLevel.warn => c.accent,
      LogLevel.info => c.secondary,
      LogLevel.debug => c.tertiary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: AppTheme.timestamp(c, color: c.primary).copyWith(height: 1.4),
          children: [
            TextSpan(
              text: '${entry.timeLabel} ',
              style: AppTheme.timestamp(c),
            ),
            TextSpan(
              text: '${entry.level.label} ',
              style: AppTheme.timestamp(c, color: color),
            ),
            TextSpan(
              text: '[${entry.category}] ',
              style: AppTheme.timestamp(c),
            ),
            TextSpan(text: entry.message),
          ],
        ),
      ),
    );
  }
}
