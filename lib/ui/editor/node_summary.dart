import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/strings.dart';

const _summaryKeys = <String>[
  'alias',
  'name',
  'title',
  'tabName',
  'pathKey',
  'attribute',
  'placeholder',
  'property',
  'xsdPath',
  'rawType',
];

String? nodeSummary(Node node) {
  for (final key in _summaryKeys) {
    final value = node.fields[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  final type = node.fields['type'];
  if (type is String && type.isNotEmpty) {
    return UiStrings.enumLabel(type);
  }
  final operator = node.fields['operator'];
  if (operator is String && operator.isNotEmpty) {
    final alias = node.fields['alias'];
    final label = UiStrings.enumLabel(operator);
    if (alias is String && alias.trim().isNotEmpty) {
      return '$label · ${alias.trim()}';
    }
    return label;
  }
  return null;
}
