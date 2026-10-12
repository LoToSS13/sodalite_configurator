import 'package:sodalite_configurator/ui/help_copy.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_help.dart';
import 'package:sodalite_configurator/ui/sodalite_select.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/sodalite_tooltip.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/editor/slug_field.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class FieldControls extends StatelessWidget {
  const FieldControls({super.key, required this.node, required this.fields, required this.controller});

  final Node node;
  final List<FieldSpec> fields;
  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < fields.length; index++)
          Padding(
            key: ValueKey('${node.id}-${fields[index].key}'),
            padding: EdgeInsets.only(bottom: index == fields.length - 1 ? 0 : 16),
            child: Focus(
              canRequestFocus: false,
              onFocusChange: (hasFocus) {
                if (!hasFocus && context.mounted) {
                  controller.markFieldVisited(node.id, fields[index].key);
                }
              },
              child: _FieldControl(node: node, spec: fields[index], controller: controller),
            ),
          ),
      ],
    );
  }
}

class _FieldControl extends StatelessWidget {
  const _FieldControl({required this.node, required this.spec, required this.controller});

  final Node node;
  final FieldSpec spec;
  final DocumentController controller;

  String? get _error {
    final Issue? issue = controller.visibleIssues
        .where((item) => item.nodeId == node.id && item.path == spec.key)
        .firstOrNull;
    return issue == null ? null : UiStrings.issueReason(issue.message);
  }

  @override
  Widget build(BuildContext context) {
    if (spec.key == 'slug') return SlugField(controller: controller);
    final value = node.fields[spec.key];
    final label = '${UiStrings.pathLabel(spec.key)}${spec.required && spec.kind != FieldKind.boolean ? ' *' : ''}';
    final help = HelpCopy.field(node.typeId, spec.key);
    final helper = switch ((node.typeId, spec.key)) {
      (TypeIds.geo, 'alias') ||
      (TypeIds.info, 'alias') ||
      (TypeIds.searchObject, 'alias') ||
      (TypeIds.geoSource, 'view') => 'Точный алиас из\u00a0настройки источника данных',
      (_, 'visibilityThreshold') => 'Уровень масштаба: 15, 16 или\u00a017',
      _ => null,
    };
    final decoration = InputDecoration(labelText: help == null ? label : null, errorText: _error, helperText: helper);
    final control = switch (spec.kind) {
      FieldKind.boolean when spec.required && value is! bool => SodaliteSelect<bool>(
        key: ValueKey('${node.id}-${spec.key}-unset'),
        value: null,
        decoration: InputDecoration(
          labelText: help == null ? '$label *' : null,
          errorText: _error == null ? null : 'Выберите «Да» или «Нет»',
        ),
        values: const [true, false],
        labelOf: (value) => value ? 'Да' : 'Нет',
        onChanged: (next) => controller.setField(node.id, spec.key, next),
      ),
      FieldKind.boolean => Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final focused = Focus.of(context).hasFocus;
          return Theme(
            data: theme.copyWith(
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              switchTheme: theme.switchTheme.copyWith(
                trackOutlineColor: WidgetStatePropertyAll(focused ? SodaliteColors.text : Colors.transparent),
                trackOutlineWidth: WidgetStatePropertyAll(focused ? 2 : 0),
              ),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: help == null
                  ? Text(label)
                  : Row(
                      children: [
                        Flexible(child: Text(label)),
                        SodaliteHelpButton(name: UiStrings.pathLabel(spec.key), text: help),
                        const Spacer(),
                      ],
                    ),
              value: value as bool? ?? false,
              onChanged: (next) => controller.setField(node.id, spec.key, next),
            ),
          );
        },
      ),
      FieldKind.enumeration => SodaliteSelect<String>(
        key: ValueKey('${node.id}-${spec.key}'),
        value: spec.enumValues?.contains(value) == true ? value as String : null,
        decoration: decoration,
        values: spec.enumValues ?? const <String>[],
        labelOf: UiStrings.enumLabel,
        onChanged: (next) => controller.setField(node.id, spec.key, next),
      ),
      FieldKind.integer => SyncedTextField(
        key: ValueKey('${node.id}-${spec.key}'),
        value: value == null ? '' : '$value',
        decoration: decoration,
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final trimmed = text.trim();
          if (trimmed.isEmpty) {
            controller.setField(node.id, spec.key, null);
            return;
          }
          controller.setField(node.id, spec.key, int.tryParse(trimmed) ?? trimmed);
        },
      ),
      FieldKind.stringMap => _StringMapControl(
        node: node,
        spec: spec,
        controller: controller,
        label: label,
        errorText: _error,
        floatingLabel: help == null,
      ),
      FieldKind.stringList => StringListEditor(
        node: node,
        spec: spec,
        controller: controller,
        label: label,
        errorText: _error,
        floatingLabel: help == null,
      ),
      FieldKind.color => _ColorControl(node: node, spec: spec, controller: controller, label: label, errorText: _error),
      FieldKind.string || FieldKind.nonEmptyString => SyncedTextField(
        key: ValueKey('${node.id}-${spec.key}'),
        value: value is String ? value : '',
        decoration: decoration,
        onChanged: (text) => controller.setField(node.id, spec.key, text),
      ),
    };
    if (help == null || (spec.kind == FieldKind.boolean && value is bool)) return control;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(child: Text(label, style: labelStyle)),
            SodaliteHelpButton(name: UiStrings.pathLabel(spec.key), text: help),
            const Spacer(),
          ],
        ),
        control,
      ],
    );
  }
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.node,
    required this.spec,
    required this.controller,
    required this.label,
    required this.errorText,
  });

  final Node node;
  final FieldSpec spec;
  final DocumentController controller;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final value = node.fields[spec.key];
    final parsed = _parseHexColor(value is String ? value : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 12),
              child: DecoratedBox(
                key: ValueKey('${node.id}-${spec.key}-swatch'),
                decoration: BoxDecoration(
                  color: parsed ?? Colors.transparent,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(width: 32, height: 32),
              ),
            ),
            Expanded(
              child: SyncedTextField(
                key: ValueKey('${node.id}-${spec.key}'),
                value: value is String ? value : '',
                decoration: InputDecoration(labelText: label, errorText: errorText),
                onChanged: (text) => controller.setField(node.id, spec.key, text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final hex in colorPalette)
              Semantics(
                key: ValueKey('${node.id}-${spec.key}-palette-$hex'),
                button: true,
                selected: parsed == _parseHexColor(hex),
                label: '${_paletteNames[hex]}, $hex',
                child: SodaliteTooltip(
                  message: '${_paletteNames[hex]} · $hex',
                  excludeFromSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => controller.setField(node.id, spec.key, hex),
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Colors.transparent,
                      focusColor: SodaliteColors.accentMuted,
                      splashFactory: NoSplash.splashFactory,
                      child: Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(6),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: parsed == _parseHexColor(hex) ? SodaliteColors.text : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _parseHexColor(hex),
                            borderRadius: BorderRadius.circular(8),
                            border: hex == '#FFFFFF' ? Border.all(color: SodaliteColors.border) : null,
                          ),
                          child: parsed == _parseHexColor(hex)
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: (_parseHexColor(hex)!.computeLuminance() > .179) ? Colors.black : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Figma Tokens: Blue/500, Blue/700, Green/500, Yellow/950, Red/500,
// Gray/700, Gray/900, Gray/000. Suggestions only; custom HEX remains available.
const colorPalette = <String>['#0075FF', '#0C4CB7', '#40C267', '#C2A840', '#F04438', '#5E5E5E', '#191A1B', '#FFFFFF'];
const _paletteNames = <String, String>{
  '#0075FF': 'Синий',
  '#40C267': 'Зелёный',
  '#C2A840': 'Золотистый',
  '#F04438': 'Красный',
  '#0C4CB7': 'Глубокий синий',
  '#5E5E5E': 'Серый',
  '#191A1B': 'Тёмный',
  '#FFFFFF': 'Белый',
};

class _StringMapControl extends StatelessWidget {
  const _StringMapControl({
    required this.node,
    required this.spec,
    required this.controller,
    required this.label,
    required this.errorText,
    this.floatingLabel = true,
  });

  final Node node;
  final FieldSpec spec;
  final DocumentController controller;
  final String label;
  final String? errorText;
  final bool floatingLabel;

  List<MapEntry<String, String>> get _entries {
    final value = node.fields[spec.key];
    if (value is Map) {
      return [
        for (final entry in value.entries)
          if (entry.key is String && entry.value is String) MapEntry(entry.key as String, entry.value as String),
      ];
    }
    if (value is List) {
      return [
        for (final item in value)
          if (item is Map && item['key'] is String && item['value'] is String)
            MapEntry(item['key'] as String, item['value'] as String),
      ];
    }
    return const [];
  }

  void _commit(List<MapEntry<String, String>> entries) {
    final keys = [for (final entry in entries) entry.key];
    final blank = keys.any((key) => key.trim().isEmpty);
    final duplicated = keys.length != keys.toSet().length;
    final Object value = blank || duplicated
        ? [
            for (final entry in entries) {'key': entry.key, 'value': entry.value},
          ]
        : {for (final entry in entries) entry.key: entry.value};
    controller.setField(node.id, spec.key, value);
  }

  String? _keyError(List<MapEntry<String, String>> entries, int index) {
    if (errorText == null) return null;
    final key = entries[index].key;
    if (key.trim().isEmpty) {
      return UiStrings.issueReason('Map key must not be blank');
    }
    if (entries.where((entry) => entry.key == key).length > 1) {
      return UiStrings.issueReason('Map key is duplicated');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: floatingLabel ? label : null,
        errorText: errorText,
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SodaliteColors.muted),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SyncedTextField(
                      key: ValueKey('${node.id}-${spec.key}-key-$index'),
                      value: entries[index].key,
                      decoration: InputDecoration(labelText: 'Ключ', errorText: _keyError(entries, index)),
                      onChanged: (text) {
                        final next = [...entries];
                        next[index] = MapEntry(text, next[index].value);
                        _commit(next);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SyncedTextField(
                      key: ValueKey('${node.id}-${spec.key}-value-$index'),
                      value: entries[index].value,
                      decoration: const InputDecoration(labelText: 'Путь'),
                      onChanged: (text) {
                        final next = [...entries];
                        next[index] = MapEntry(next[index].key, text);
                        _commit(next);
                      },
                    ),
                  ),
                  SodaliteIconButton(
                    tooltip: 'Удалить значение',
                    onPressed: () {
                      final next = [...entries]..removeAt(index);
                      _commit(next);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: SodaliteButton.ghost(
              key: ValueKey('${node.id}-${spec.key}-add'),
              onPressed: () {
                var key = '';
                var suffix = 0;
                final used = {for (final entry in entries) entry.key};
                while (used.contains(key)) {
                  key = 'key$suffix';
                  suffix += 1;
                }
                _commit([...entries, MapEntry(key, '')]);
              },
              child: const Text(UiStrings.addEntry),
            ),
          ),
        ],
      ),
    );
  }
}

class StringListEditor extends StatelessWidget {
  const StringListEditor({
    super.key,
    required this.node,
    required this.spec,
    required this.controller,
    required this.label,
    required this.errorText,
    this.floatingLabel = true,
  });

  final Node node;
  final FieldSpec spec;
  final DocumentController controller;
  final String label;
  final String? errorText;
  final bool floatingLabel;

  List<String> get _values {
    final value = node.fields[spec.key];
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is String) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: floatingLabel ? label : null,
        errorText: errorText,
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SodaliteColors.muted),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < values.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SyncedTextField(
                      key: ValueKey('${node.id}-${spec.key}-$index'),
                      value: values[index],
                      onChanged: (text) {
                        final next = [...values];
                        next[index] = text;
                        controller.setField(node.id, spec.key, next);
                      },
                    ),
                  ),
                  SodaliteIconButton(
                    tooltip: 'Удалить значение',
                    onPressed: () {
                      final next = [...values]..removeAt(index);
                      controller.setField(node.id, spec.key, next);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: SodaliteButton.ghost(
              key: ValueKey('${node.id}-${spec.key}-add'),
              onPressed: () => controller.setField(node.id, spec.key, [...values, '']),
              child: const Text(UiStrings.addValue),
            ),
          ),
        ],
      ),
    );
  }
}

Color? _parseHexColor(String? value) {
  if (value == null || !RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$').hasMatch(value)) {
    return null;
  }
  final hex = value.substring(1);
  final parsed = int.parse(hex, radix: 16);
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}

class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.decoration,
    this.keyboardType,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _text.text) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _text,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}
