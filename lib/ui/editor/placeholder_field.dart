import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/editor/placeholder_keys.dart';

final _openBrace = RegExp(r'\{([A-Za-z0-9_]*)$');

/// Text field that offers `{key}` completions from the card's paths or endpoints.
class PlaceholderKeyField extends StatefulWidget {
  const PlaceholderKeyField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.source,
    this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final PlaceholderKeySource source;
  final InputDecoration? decoration;

  @override
  State<PlaceholderKeyField> createState() => _PlaceholderKeyFieldState();
}

class _PlaceholderKeyFieldState extends State<PlaceholderKeyField> {
  late final TextEditingController _text = TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode();
  int _highlight = 0;
  String? _dismissedToken;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onCaret);
    _focus.addListener(_onCaret);
    _focus.onKeyEvent = _onKey;
  }

  @override
  void didUpdateWidget(PlaceholderKeyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _text.text) {
      _text.removeListener(_onCaret);
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      _text.addListener(_onCaret);
    }
    final count = _matches.length;
    if (count == 0) {
      _highlight = 0;
    } else if (_highlight >= count) {
      _highlight = count - 1;
    }
  }

  @override
  void dispose() {
    _text.removeListener(_onCaret);
    _focus.removeListener(_onCaret);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _rebuildScheduled = false;

  void _onCaret() {
    final token = _token;
    if (_dismissedToken != null && _dismissedToken != token) _dismissedToken = null;
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  String? get _token {
    final text = _text.text;
    final selection = _text.selection;
    if (selection.isValid && selection.isCollapsed) {
      final end = selection.extentOffset.clamp(0, text.length);
      final direct = _openBrace.firstMatch(text.substring(0, end))?.group(0);
      if (direct != null) return direct;
    }
    if (RegExp(r'^\{[A-Za-z0-9_]*$').hasMatch(text)) return text;
    if (!selection.isValid) return null;
    final end = selection.extentOffset.clamp(0, text.length);
    return _openBrace.firstMatch(text.substring(0, end))?.group(0);
  }

  String get _prefix {
    final token = _token;
    if (token == null || token.length < 2) return '';
    return token.substring(1);
  }

  bool get _open => _focus.hasFocus && _token != null && _token != _dismissedToken;

  List<PlaceholderKeyOption> get _matches {
    final prefix = _prefix;
    return [
      for (final option in widget.source.options)
        if (option.key.startsWith(prefix)) option,
    ];
  }

  void _move(int delta) {
    final count = _matches.length;
    if (count == 0) return;
    setState(() => _highlight = (_highlight + delta + count) % count);
  }

  void _accept() {
    final matches = _matches;
    if (matches.isEmpty) return;
    _insert(matches[_highlight.clamp(0, matches.length - 1)].key);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_open) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _accept();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _dismissedToken = _token);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insert(String key) {
    final text = _text.text;
    final token = _token;
    if (token == null) return;
    final selection = _text.selection;
    final extent = selection.isValid ? selection.extentOffset.clamp(0, text.length) : text.length;
    final match = _openBrace.firstMatch(text.substring(0, extent));
    final start = match?.start ?? (text.startsWith(token) ? 0 : null);
    if (start == null) return;
    var replaceEnd = start + token.length;
    if (replaceEnd < text.length && text[replaceEnd] == '}') replaceEnd++;
    final next = text.replaceRange(start, replaceEnd, '{$key}');
    final offset = start + key.length + 2;
    _dismissedToken = null;
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset),
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(controller: _text, focusNode: _focus, decoration: widget.decoration, onChanged: widget.onChanged),
        if (open) ...[
          const SizedBox(height: 8),
          _KeyMenu(source: widget.source, matches: matches, highlight: _highlight, onSelect: _insert),
        ],
      ],
    );
  }
}

class _KeyMenu extends StatelessWidget {
  const _KeyMenu({required this.source, required this.matches, required this.highlight, required this.onSelect});

  final PlaceholderKeySource source;
  final List<PlaceholderKeyOption> matches;
  final int highlight;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary);
    return Material(
      color: SodaliteColors.surface,
      elevation: 8,
      shadowColor: SodaliteColors.text.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('Ключи из «${source.label}»', style: caption),
            ),
            if (source.options.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Text('Сначала добавьте ключи в «${source.label}» этой карточки', style: caption),
              )
            else if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Text('Нет ключа с таким началом', style: caption),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var index = 0; index < matches.length; index++)
                      _KeyRow(
                        option: matches[index],
                        selected: index == highlight,
                        onSelect: () => onSelect(matches[index].key),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.option, required this.selected, required this.onSelect});

  final PlaceholderKeyOption option;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Вставить {${option.key}}',
      child: Listener(
        onPointerDown: (_) => onSelect(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? SodaliteColors.canvas : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? SodaliteColors.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Text('{${option.key}}', style: Theme.of(context).textTheme.bodyLarge),
              if (option.path.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.path,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
