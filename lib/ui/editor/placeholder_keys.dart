import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

class PlaceholderKeyOption {
  const PlaceholderKeyOption({required this.key, required this.path});

  final String key;
  final String path;
}

class PlaceholderKeySource {
  const PlaceholderKeySource({required this.label, required this.options});

  /// «Пути» or «Конечные точки»: the field whose keys may appear in braces.
  final String label;
  final List<PlaceholderKeyOption> options;
}

const _infoTemplateFields = {'titleContent', 'subtitleContent', 'statusContent'};
const _inspectionTemplateFields = {'titleContent', 'subtitleContent', 'tagContent'};
const _rowTemplateFields = {'content', 'url'};

/// Keys that may be written as `{key}` in this field. Search titles are plain
/// text and return null.
PlaceholderKeySource? placeholderKeys(Node root, Node node, String fieldKey) {
  final chain = _chain(root, node.id);
  if (chain == null) return null;

  if (node.typeId == TypeIds.info && _infoTemplateFields.contains(fieldKey)) {
    return PlaceholderKeySource(label: 'Пути', options: _options(node.fields['paths']));
  }
  if (node.typeId == TypeIds.inspectionObject && _inspectionTemplateFields.contains(fieldKey)) {
    return PlaceholderKeySource(label: 'Конечные точки', options: _options(node.fields['endpoints']));
  }
  if (node.typeId == TypeIds.fieldRow && _rowTemplateFields.contains(fieldKey)) {
    for (final ancestor in chain.reversed.skip(1)) {
      if (ancestor.typeId == TypeIds.inspectionObject) {
        return PlaceholderKeySource(label: 'Конечные точки', options: _options(ancestor.fields['endpoints']));
      }
      if (ancestor.typeId == TypeIds.info) {
        return PlaceholderKeySource(label: 'Пути', options: _options(ancestor.fields['paths']));
      }
    }
  }
  return null;
}

List<Node>? _chain(Node node, String id) {
  if (node.id == id) return [node];
  for (final children in node.childrenBySlot.values) {
    for (final child in children) {
      final nested = _chain(child, id);
      if (nested != null) return [node, ...nested];
    }
  }
  return null;
}

List<PlaceholderKeyOption> _options(Object? value) {
  final entries = switch (value) {
    final Map map => [
      for (final entry in map.entries)
        if (entry.key is String && entry.value is String) MapEntry(entry.key as String, entry.value as String),
    ],
    final List list => [
      for (final item in list)
        if (item is Map && item['key'] is String && item['value'] is String)
          MapEntry(item['key'] as String, item['value'] as String),
    ],
    _ => const <MapEntry<String, String>>[],
  };
  final seen = <String>{};
  return [
    for (final entry in entries)
      if (entry.key.trim().isNotEmpty && seen.add(entry.key)) PlaceholderKeyOption(key: entry.key, path: entry.value),
  ];
}
