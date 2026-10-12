import 'package:flutter/material.dart';

import 'design_system.dart';

/// Single selection: Sodalite field + Context Menu styling, anchored layout.
class SodaliteSelect<T> extends StatefulWidget {
  const SodaliteSelect({
    super.key,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.decoration,
    required this.onChanged,
  });

  final T? value;
  final List<T> values;
  final String Function(T) labelOf;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;

  @override
  State<SodaliteSelect<T>> createState() => _SodaliteSelectState<T>();
}

class _SodaliteSelectState<T> extends State<SodaliteSelect<T>> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _menu = MenuController();
  bool _syncScheduled = false;

  void _onTextChanged() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    // Flutter previews arrow-key highlights in the field. Keep the committed
    // value visible until onSelected updates the document, including on cancel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreValue();
      _syncScheduled = false;
    });
  }

  void _restoreValue() {
    final value = widget.value;
    final label = value != null && widget.values.contains(value) ? widget.labelOf(value) : '';
    if (_text.text != label) _text.text = label;
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _restoreValue();
  }

  @override
  void initState() {
    super.initState();
    _restoreValue();
    _text.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SodaliteSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restoreValue();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: widget.decoration.labelText,
      value: widget.value == null ? 'Не выбрано' : widget.labelOf(widget.value as T),
      child: DropdownMenu<T>(
        controller: _text,
        focusNode: _focus,
        menuController: _menu,
        enabled: widget.onChanged != null && widget.values.isNotEmpty,
        initialSelection: widget.value,
        selectOnly: true,
        requestFocusOnTap: true,
        enableSearch: false,
        enableFilter: false,
        expandedInsets: EdgeInsets.zero,
        menuHeight: 320,
        alignmentOffset: const Offset(0, 8),
        textStyle: theme.textTheme.bodyLarge,
        inputDecorationTheme: theme.inputDecorationTheme,
        decorationBuilder: (_, menu) => widget.decoration.copyWith(
          suffixIcon: ExcludeSemantics(
            child: Icon(menu.isOpen ? Icons.expand_less : Icons.expand_more, size: 24, color: SodaliteColors.secondary),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(SodaliteColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(SodaliteColors.text.withValues(alpha: .05)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          side: const WidgetStatePropertyAll(BorderSide(color: SodaliteColors.muted)),
        ),
        dropdownMenuEntries: [
          for (final value in widget.values)
            DropdownMenuEntry<T>(
              value: value,
              label: widget.labelOf(value),
              labelWidget: Semantics(selected: value == widget.value, child: Text(widget.labelOf(value))),
              trailingIcon: SizedBox.square(
                dimension: 24,
                child: value == widget.value
                    ? const Icon(Icons.check, size: 20, color: SodaliteColors.accentStrong)
                    : null,
              ),
              style:
                  MenuItemButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    textStyle: theme.textTheme.bodyLarge,
                    foregroundColor: value == widget.value ? SodaliteColors.accentStrong : SodaliteColors.text,
                    backgroundColor: value == widget.value ? SodaliteColors.accentSubdued : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                  ).copyWith(
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.pressed) ? SodaliteColors.canvas : Colors.transparent,
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.focused) ? SodaliteColors.accent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                  ),
            ),
        ],
        onSelected: (next) {
          // Enter without an active option must not clear the saved value.
          if (next == null) {
            _restoreValue();
          } else {
            widget.onChanged?.call(next);
          }
        },
      ),
    );
  }
}
