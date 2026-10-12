import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';
import 'sodalite_buttons.dart';
import 'sodalite_tooltip.dart';

/// Desktop adaptation of Sodalite Search bar 96:26141.
/// Filters immediately; clearing keeps keyboard focus in the field.
class SodaliteSearchField extends StatefulWidget {
  const SodaliteSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<SodaliteSearchField> createState() => _SodaliteSearchFieldState();
}

class _SodaliteSearchFieldState extends State<SodaliteSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(42), borderSide: BorderSide.none);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
      child: Semantics(
        container: true,
        label: 'Поиск черновиков',
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            style: textStyle,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              constraints: const BoxConstraints.tightFor(height: 48),
              isDense: true,
              hintText: 'Название или идентификатор',
              hintStyle: textStyle?.copyWith(color: SodaliteColors.secondary),
              fillColor: SodaliteColors.surface,
              hoverColor: Colors.transparent,
              contentPadding: const EdgeInsets.fromLTRB(0, 12, 20, 12),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(borderSide: const BorderSide(color: SodaliteColors.accent, width: 1.5)),
              prefixIconConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.search, size: 24, color: SodaliteColors.text),
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
              suffixIcon: value.text.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(2),
                      child: MergeSemantics(
                        child: Semantics(
                          label: 'Очистить поиск',
                          button: true,
                          child: SodaliteTooltip(
                            message: 'Очистить поиск',
                            excludeFromSemantics: true,
                            child: SodalitePress(
                              scale: 1.16,
                              whiteOverlay: false,
                              builder: (states) => IconButton(
                                statesController: states,
                                onPressed: _clear,
                                tooltip: null,
                                icon: const Icon(Icons.close, size: 20),
                                style:
                                    IconButton.styleFrom(
                                      foregroundColor: SodaliteColors.secondary,
                                      splashFactory: NoSplash.splashFactory,
                                    ).copyWith(
                                      overlayColor: WidgetStateProperty.resolveWith(
                                        (states) => states.contains(WidgetState.focused)
                                            ? SodaliteColors.accent.withValues(alpha: .12)
                                            : Colors.transparent,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
