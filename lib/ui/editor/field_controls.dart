import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/node.dart';

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

  @override
  Widget build(BuildContext context) {
    final value = node.fields[spec.key];
    return switch (spec.kind) {
      FieldKind.boolean => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(spec.key),
        value: value as bool? ?? false,
        onChanged: (next) => controller.setField(node.id, spec.key, next),
      ),
      FieldKind.enumeration => DropdownButtonFormField<String>(
        key: ValueKey('${node.id}-${spec.key}'),
        initialValue: spec.enumValues?.contains(value) == true ? value as String : null,
        decoration: InputDecoration(labelText: spec.key),
        items: [
          for (final item in spec.enumValues ?? const <String>[]) DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (next) => controller.setField(node.id, spec.key, next),
      ),
      FieldKind.integer => TextFormField(
        key: ValueKey('${node.id}-${spec.key}'),
        initialValue: value is int ? '$value' : '',
        decoration: InputDecoration(labelText: spec.key),
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final trimmed = text.trim();
          if (trimmed.isEmpty) {
            controller.setField(node.id, spec.key, null);
            return;
          }
          final parsed = int.tryParse(trimmed);
          if (parsed != null) {
            controller.setField(node.id, spec.key, parsed);
          }
        },
      ),
      FieldKind.stringMap || FieldKind.stringList => InputDecorator(
        decoration: InputDecoration(labelText: spec.key),
        child: Text('$value'),
      ),
      FieldKind.string || FieldKind.nonEmptyString || FieldKind.color => TextFormField(
        key: ValueKey('${node.id}-${spec.key}'),
        initialValue: value is String ? value : '',
        decoration: InputDecoration(labelText: spec.key),
        onChanged: (text) => controller.setField(node.id, spec.key, text),
      ),
    };
  }
}
