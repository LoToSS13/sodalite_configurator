import 'package:flutter/material.dart';
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
        for (final spec in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FieldControl(node: node, spec: spec, controller: controller),
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
    final Issue? issue = controller.issues.where((item) => item.nodeId == node.id && item.path == spec.key).firstOrNull;
    return issue == null ? null : UiStrings.issueReason(issue.message);
  }

  @override
  Widget build(BuildContext context) {
    final value = node.fields[spec.key];
    final label = UiStrings.pathLabel(spec.key);
    return switch (spec.kind) {
      FieldKind.boolean => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value as bool? ?? false,
        onChanged: (next) => controller.setField(node.id, spec.key, next),
      ),
      FieldKind.enumeration => DropdownButtonFormField<String>(
        key: ValueKey('${node.id}-${spec.key}'),
        initialValue: spec.enumValues?.contains(value) == true ? value as String : null,
        decoration: InputDecoration(labelText: label, errorText: _error),
        items: [
          for (final item in spec.enumValues ?? const <String>[])
            DropdownMenuItem(value: item, child: Text(UiStrings.enumLabel(item))),
        ],
        onChanged: (next) => controller.setField(node.id, spec.key, next),
      ),
      FieldKind.integer => TextFormField(
        key: ValueKey('${node.id}-${spec.key}'),
        initialValue: value == null ? '' : '$value',
        decoration: InputDecoration(labelText: label, errorText: _error),
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
      ),
      FieldKind.stringList => _StringListControl(
        node: node,
        spec: spec,
        controller: controller,
        label: label,
        errorText: _error,
      ),
      FieldKind.color => _ColorControl(node: node, spec: spec, controller: controller, label: label, errorText: _error),
      FieldKind.string || FieldKind.nonEmptyString => TextFormField(
        key: ValueKey('${node.id}-${spec.key}'),
        initialValue: value is String ? value : '',
        decoration: InputDecoration(labelText: label, errorText: _error),
        onChanged: (text) {
          if (spec.key == 'slug') {
            controller.setField(node.id, spec.key, text, saveDraft: false);
            return;
          }
          controller.setField(node.id, spec.key, text);
        },
        onFieldSubmitted: spec.key == 'slug'
            ? (text) async {
                final renamed = await controller.trySetSlug(text);
                if (!renamed && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(UiStrings.slugTaken)));
                }
              }
            : null,
      ),
    };
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, right: 12),
          child: DecoratedBox(
            key: ValueKey('${node.id}-${spec.key}-swatch'),
            decoration: BoxDecoration(
              color: parsed ?? Colors.transparent,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const SizedBox(width: 28, height: 28),
          ),
        ),
        Expanded(
          child: TextFormField(
            key: ValueKey('${node.id}-${spec.key}'),
            initialValue: value is String ? value : '',
            decoration: InputDecoration(labelText: label, errorText: errorText),
            onChanged: (text) => controller.setField(node.id, spec.key, text),
          ),
        ),
      ],
    );
  }
}

class _StringMapControl extends StatelessWidget {
  const _StringMapControl({
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

  List<MapEntry<String, String>> get _entries {
    final value = node.fields[spec.key];
    if (value is! Map) {
      return const [];
    }
    return [
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String) MapEntry(entry.key as String, entry.value as String),
    ];
  }

  void _commit(List<MapEntry<String, String>> entries) {
    controller.setField(node.id, spec.key, {for (final entry in entries) entry.key: entry.value});
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: errorText, border: const OutlineInputBorder()),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('${node.id}-${spec.key}-key-$index'),
                      initialValue: entries[index].key,
                      decoration: const InputDecoration(labelText: 'Ключ'),
                      onChanged: (text) {
                        final next = [...entries];
                        next[index] = MapEntry(text, next[index].value);
                        _commit(next);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('${node.id}-${spec.key}-value-$index'),
                      initialValue: entries[index].value,
                      decoration: const InputDecoration(labelText: 'Путь'),
                      onChanged: (text) {
                        final next = [...entries];
                        next[index] = MapEntry(next[index].key, text);
                        _commit(next);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: UiStrings.deleteDraft,
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
            child: TextButton(
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

class _StringListControl extends StatelessWidget {
  const _StringListControl({
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
      decoration: InputDecoration(labelText: label, errorText: errorText, border: const OutlineInputBorder()),
      child: Column(
        children: [
          for (var index = 0; index < values.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('${node.id}-${spec.key}-$index'),
                      initialValue: values[index],
                      onChanged: (text) {
                        final next = [...values];
                        next[index] = text;
                        controller.setField(node.id, spec.key, next);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: UiStrings.deleteDraft,
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
            child: TextButton(
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
