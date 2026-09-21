import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';

List<Issue> extraConstraints(Node node, Catalog catalog) {
  switch (node.typeId) {
    case TypeIds.geoSource:
      final view = node.fields['view'];
      final hasView = view is String && view.trim().isNotEmpty;
      final hasRule = (node.childrenBySlot['rule'] ?? const <Node>[]).any((child) => child.typeId == TypeIds.geoRule);
      if (!hasView && !hasRule) {
        return [Issue(nodeId: node.id, path: 'view', message: 'A non-empty view or a rule child is required')];
      }
    case TypeIds.geoRule:
      final operator = node.fields['operator'];
      if (operator == 'eq' || operator == 'noteq' || operator == 'notin') {
        final value = node.fields['value'];
        if (value is! String || value.trim().isEmpty) {
          return [Issue(nodeId: node.id, path: 'value', message: 'A non-empty value is required for $operator')];
        }
      }
  }

  return const [];
}
