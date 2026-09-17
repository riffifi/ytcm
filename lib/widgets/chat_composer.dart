import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/gif_search_service.dart';
import '../services/server_settings.dart';
import '../icons/phosphor_assets.dart';
import '../theme.dart';
import 'phosphor_icon.dart';
import '../utils/gif_message.dart';
import '../utils/messenger_haptics.dart';
import 'emoji_picker_sheet.dart';
import 'app_bottom_sheet.dart';

class ChatComposer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback? onAttach;
  final bool autofocus;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.onAttach,
    this.autofocus = true,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _hasText = false;
  List<GifResult> _gifResults = [];
  String _gifQuery = '';
  int _gifTriggerStart = -1;
  Timer? _gifDebounce;
  bool _gifLoading = false;

  static const _fieldRadius = 24.0;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _gifDebounce?.cancel();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _textCtrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    _updateGifSuggestions();
  }

  void _updateGifSuggestions() {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.isValid
        ? _textCtrl.selection.baseOffset
        : text.length;
    final trigger = GifMessage.atGifTrigger(text, cursor);
    if (trigger == null) {
      if (_gifTriggerStart >= 0 || _gifResults.isNotEmpty || _gifLoading) {
        setState(() {
          _gifTriggerStart = -1;
          _gifQuery = '';
          _gifResults = [];
          _gifLoading = false;
        });
      }
      _gifDebounce?.cancel();
      return;
    }

    if (trigger.start != _gifTriggerStart || trigger.query != _gifQuery) {
      setState(() {
        _gifTriggerStart = trigger.start;
        _gifQuery = trigger.query;
      });
    }

    _gifDebounce?.cancel();
    _gifDebounce = Timer(AppMotion.theme, () {
      _fetchGifs(trigger.query);
    });
  }

  GifSearchService _gifService() => GifSearchService(
        tenorApiKey: context.read<ServerSettings>().tenorApiKey,
      );

  Future<void> _fetchGifs(String query) async {
    if (!mounted) return;
    if (query.trim().isEmpty) {
      setState(() {
        _gifResults = [];
        _gifLoading = false;
      });
      return;
    }
    setState(() => _gifLoading = true);
    final results = await _gifService().search(query);
    if (!mounted) return;
    if (_gifQuery != query) return;
    setState(() {
      _gifResults = results;
      _gifLoading = false;
    });
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    messengerHapticMedium();
    widget.onSend(text);
    _textCtrl.clear();
    setState(() {
      _gifTriggerStart = -1;
      _gifResults = [];
      _gifLoading = false;
    });
    _focusNode.requestFocus();
  }

  void _sendGif(String mediaUrl) {
    messengerHapticMedium();
    widget.onSend(GifMessage.encode(mediaUrl));
    _textCtrl.clear();
    setState(() {
      _gifTriggerStart = -1;
      _gifResults = [];
      _gifLoading = false;
    });
    _focusNode.requestFocus();
  }

  void _insertNewline() {
    final text = _textCtrl.text;
    final sel = _textCtrl.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : start;
    final updated = text.replaceRange(start, end, '\n');
    _textCtrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }

    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isMetaPressed) {
      _insertNewline();
      return KeyEventResult.handled;
    }

    if (hw.isShiftPressed) return KeyEventResult.ignored;

    _send();
    return KeyEventResult.handled;
  }

  Future<void> _openEmojiPicker() async {
    _focusNode.unfocus();
    await EmojiPickerSheet.show(
      context,
      onEmojiSelected: (emoji) {
        final text = _textCtrl.text;
        final sel = _textCtrl.selection;
        final start = sel.start >= 0 ? sel.start : text.length;
        final end = sel.end >= 0 ? sel.end : start;
        final updated = text.replaceRange(start, end, emoji.emoji);
        _textCtrl.value = TextEditingValue(
          text: updated,
          selection:
              TextSelection.collapsed(offset: start + emoji.emoji.length),
        );
        _focusNode.requestFocus();
      },
    );
  }

  Future<void> _openGifPicker() async {
    messengerHapticSelection();
    final picked = await AppBottomSheet.show<GifResult>(
      context,
      title: 'GIF search',
      builder: (ctx) => _GifPickerSheet(
        search: (q) => _gifService().search(q),
      ),
    );
    if (picked != null && mounted) _sendGif(picked.gifUrl);
  }

  void _applyGifResult(GifResult gif) {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.isValid
        ? _textCtrl.selection.baseOffset
        : text.length;
    final trigger = GifMessage.atGifTrigger(text, cursor);
    if (trigger != null) {
      final before = text.substring(0, trigger.start);
      final after = text.substring(cursor);
      _textCtrl.text = '$before${GifMessage.encode(gif.gifUrl)}$after';
      _send();
      return;
    }
    _sendGif(gif.gifUrl);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final showGifStrip = _gifTriggerStart >= 0 &&
        (_gifLoading || _gifResults.isNotEmpty || _gifQuery.isNotEmpty);
    final compact = MediaQuery.sizeOf(context).width < 420;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showGifStrip) _buildGifStrip(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.onAttach != null) ...[
                    _ComposerIconButton(
                      icon: PhosphorAssets.attach,
                      tooltip: 'Attach file',
                      onTap: widget.onAttach!,
                      colors: c,
                    ),
                    const SizedBox(width: 2),
                  ],
                  _ComposerIconButton(
                    icon: PhosphorAssets.smiley,
                    tooltip: 'Emoji',
                    onTap: _openEmojiPicker,
                    colors: c,
                  ),
                  const SizedBox(width: 2),
                  if (!compact) ...[
                    const SizedBox(width: 2),
                    _ComposerIconButton(
                      icon: PhosphorAssets.gif,
                      tooltip: 'GIF — or type @gif cats',
                      onTap: _openGifPicker,
                      colors: c,
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(child: _buildTextField(c)),
                  const SizedBox(width: 8),
                  _SendButton(hasText: _hasText, onSend: _send, colors: c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGifStrip(AppColors c) {
    return Material(
      color: c.surfaceHigh,
      child: SizedBox(
        height: 108,
        child: _gifLoading && _gifResults.isEmpty
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.accent,
                  ),
                ),
              )
            : _gifResults.isEmpty
                ? Center(
                    child: Text(
                      _gifQuery.isEmpty
                          ? 'Type after @gif to search'
                          : 'No GIFs for “$_gifQuery”',
                      style: AppTheme.caption(c),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: _gifResults.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final gif = _gifResults[i];
                      return GestureDetector(
                        onTap: () {
                          messengerHapticSelection();
                          _applyGifResult(gif);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Image.network(
                            gif.previewUrl,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 88,
                              height: 88,
                              color: c.surface,
                              child: PhosphorIcon(
                                PhosphorAssets.imageBroken,
                                color: c.tertiary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildTextField(AppColors c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_fieldRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.surfaceHigh),
        child: Focus(
          onKeyEvent: _handleKey,
          child: TextField(
            controller: _textCtrl,
            focusNode: _focusNode,
            maxLines: 6,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: AppTheme.text(c, fontSize: 15, height: 1.35),
            cursorColor: c.accent,
            decoration: InputDecoration(
              hintText: MediaQuery.sizeOf(context).width < 600
                  ? 'Message'
                  : 'Message · Enter to send · Shift+Enter for new line',
              hintStyle: AppTheme.text(c, color: c.tertiary, fontSize: 14),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppColors colors;

  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: () {
          messengerHapticSelection();
          onTap();
        },
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        icon: PhosphorIcon(icon, color: colors.secondary, size: 22),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool hasText;
  final VoidCallback onSend;
  final AppColors colors;

  const _SendButton({
    required this.hasText,
    required this.onSend,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: hasText ? 1.0 : 0.92,
      duration: AppMotion.base,
      curve: Curves.easeOut,
      child: Material(
        color: hasText ? colors.accent : colors.surfaceHigh,
        shape: const CircleBorder(),
        elevation: hasText ? 2 : 0,
        shadowColor: colors.accent.withValues(alpha: 0.35),
        child: InkWell(
          onTap: hasText ? onSend : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: PhosphorIcon(
                PhosphorAssets.send,
                color: hasText ? Colors.white : colors.tertiary,
                size: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GifPickerSheet extends StatefulWidget {
  final Future<List<GifResult>> Function(String query) search;

  const _GifPickerSheet({required this.search});

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  List<GifResult> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _queryCtrl.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(AppMotion.theme, _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _queryCtrl.text.trim();
    if (!mounted) return;
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await widget.search(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mc;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox(
      height: (MediaQuery.sizeOf(context).height * .68).clamp(420, 680),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 1,
          minChildSize: 1,
          maxChildSize: 1,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.md)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _queryCtrl,
                      autofocus: true,
                      style: AppTheme.text(c),
                      cursorColor: c.accent,
                      decoration: InputDecoration(
                        hintText: 'Search GIFs',
                        prefixIcon: PhosphorIcon.forInput(
                          PhosphorAssets.search,
                          color: c.tertiary,
                        ),
                        filled: true,
                        fillColor: c.surfaceHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _loading && _results.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(color: c.accent),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  _queryCtrl.text.trim().isEmpty
                                      ? 'Search for a GIF'
                                      : 'No results',
                                  style: AppTheme.caption(c),
                                ),
                              )
                            : GridView.builder(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                                itemCount: _results.length,
                                itemBuilder: (context, i) {
                                  final gif = _results[i];
                                  return GestureDetector(
                                    onTap: () {
                                      messengerHapticSelection();
                                      Navigator.pop(context, gif);
                                    },
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      child: Image.network(
                                        gif.previewUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            ColoredBox(
                                          color: c.surfaceHigh,
                                          child: PhosphorIcon(
                                            PhosphorAssets.imageBroken,
                                            color: c.tertiary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
