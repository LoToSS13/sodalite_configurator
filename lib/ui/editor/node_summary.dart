import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/editor/filter_summary.dart';

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

/// Only explicit object names belong in the primary navigation label.
String? nodeName(Node node) {
  if (node.typeId == TypeIds.layer) {
    final geo = node.childrenBySlot['geo']?.firstOrNull;
    return geo == null ? null : nodeName(geo);
  }
  if (node.fields.containsKey('operator')) return null;
  for (final key in ['name', 'title', 'tabName', 'alias']) {
    final value = node.fields[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? nodeSummary(Node node) {
  if (node.typeId == TypeIds.layer) {
    final geo = node.childrenBySlot['geo']?.firstOrNull;
    if (geo != null) return nodeSummary(geo);
  }
  if (node.typeId == TypeIds.geoStyle) {
    final color = node.fields['color'];
    final parts = [
      if (color is String && color.trim().isNotEmpty) color.trim(),
      if (node.fields['isDashed'] == true) 'Пунктир',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
  final operator = node.fields['operator'];
  if (operator is String && operator.isNotEmpty) {
    return filterSummary(node);
  }
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
  return null;
}

/// A collapsed block explains its identity and its immediate contents.
String? nodeCollapsedSummary(Node node) {
  final identity = nodeSummary(node);
  final parts = [
    if (identity != null) identity,
    for (final slot in node.childrenBySlot.entries)
      if (slot.value.isNotEmpty) _slotSummary(slot.key, slot.value.length),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String _slotSummary(String key, int count) {
  final forms = switch (key) {
    'style' => ['стиль', 'стиля', 'стилей'],
    'sources' => ['источник', 'источника', 'источников'],
    'fields' => ['поле', 'поля', 'полей'],
    'infoSections' => ['раздел информации', 'раздела информации', 'разделов информации'],
    'images' => ['блок изображений', 'блока изображений', 'блоков изображений'],
    'attachments' => ['блок вложений', 'блока вложений', 'блоков вложений'],
    'inspectionView' => ['вкладка инспекции', 'вкладки инспекции', 'вкладок инспекции'],
    'actions' => ['действие', 'действия', 'действий'],
    'geometryTypes' => ['тип геометрии', 'типа геометрии', 'типов геометрии'],
    'searchObjects' => ['объект поиска', 'объекта поиска', 'объектов поиска'],
    _ => null,
  };
  if (forms == null) return '${UiStrings.pathLabel(key)}: $count';
  final lastTwo = count % 100;
  final last = count % 10;
  final form = lastTwo >= 11 && lastTwo <= 14 ? 2 : (last == 1 ? 0 : (last >= 2 && last <= 4 ? 1 : 2));
  return '$count ${forms[form]}';
}
