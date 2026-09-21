import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/constraints.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/node_type.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';

final RegExp _colorPattern = RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');

List<Issue> validate(Node root, Catalog catalog) {
  final issues = <Issue>[];
  _validateNode(root, catalog, issues);
  return issues;
}

void _validateNode(Node node, Catalog catalog, List<Issue> issues) {
  final NodeType type;
  try {
    type = catalog.type(node.typeId);
  } on StateError {
    issues.add(Issue(nodeId: node.id, path: 'typeId', message: 'Unknown node type: ${node.typeId}'));
    return;
  }

  for (final field in type.fields) {
    _validateField(node, field, issues);
  }

  for (final slot in type.slots) {
    final children = node.childrenBySlot[slot.key] ?? const <Node>[];
    _validateSlot(node, slot, children, issues);
  }

  issues.addAll(extraConstraints(node, catalog));

  for (final slot in type.slots) {
    final children = node.childrenBySlot[slot.key] ?? const <Node>[];
    for (final child in children) {
      _validateNode(child, catalog, issues);
    }
  }
}

void _validateField(Node node, FieldSpec spec, List<Issue> issues) {
  final value = node.fields[spec.key];

  if (value == null) {
    if (spec.required) {
      issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Required field is missing'));
    }
    return;
  }

  if (!_hasExpectedType(value, spec.kind)) {
    issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Value has the wrong type'));
    return;
  }

  if (spec.kind == FieldKind.nonEmptyString && (value as String).trim().isEmpty) {
    issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Required field must not be blank'));
  }

  if (spec.kind == FieldKind.integer) {
    final integer = value as int;
    if (spec.min != null && integer < spec.min!) {
      issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Value must be at least ${spec.min}'));
    } else if (spec.max != null && integer > spec.max!) {
      issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Value must be at most ${spec.max}'));
    }
  }

  if (spec.kind == FieldKind.enumeration && spec.enumValues?.contains(value) != true) {
    issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Value is not in the allowed values'));
  }

  if (spec.kind == FieldKind.color && (value is! String || !_colorPattern.hasMatch(value))) {
    issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Value must be a hexadecimal color'));
  }

  if (spec.pattern != null && (value is! String || !RegExp(spec.pattern!).hasMatch(value))) {
    issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Value does not match the required pattern'));
  }
}

bool _hasExpectedType(Object value, FieldKind kind) {
  return switch (kind) {
    FieldKind.string || FieldKind.nonEmptyString || FieldKind.enumeration || FieldKind.color => value is String,
    FieldKind.boolean => value is bool,
    FieldKind.integer => value is int,
    FieldKind.stringMap =>
      value is Map && value.keys.every((key) => key is String) && value.values.every((item) => item is String),
    FieldKind.stringList => value is List && value.every((item) => item is String),
  };
}

void _validateSlot(Node node, SlotSpec spec, List<Node> children, List<Issue> issues) {
  final invalidCardinality = switch (spec.cardinality) {
    SlotCardinality.one => children.length != 1,
    SlotCardinality.optionalOne => children.length > 1,
    SlotCardinality.list => spec.required && children.isEmpty,
  };

  if (invalidCardinality) {
    issues.add(Issue(nodeId: node.id, path: spec.key, message: 'Slot has invalid cardinality'));
  }

  for (final child in children) {
    if (!spec.allowedTypeIds.contains(child.typeId)) {
      issues.add(
        Issue(nodeId: node.id, path: spec.key, message: 'Child type ${child.typeId} is not allowed in this slot'),
      );
    }
  }
}
