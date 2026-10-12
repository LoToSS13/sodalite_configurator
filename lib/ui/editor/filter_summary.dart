import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/strings.dart';

bool isFilterNode(Node node) => node.typeId == TypeIds.geoRule || node.typeId.startsWith('searchFilter');

/// Preserve group boundaries and every value: the summary must not change the rule's meaning.
String filterSummary(Node node) {
  if (node.typeId == TypeIds.searchFilterGroup) {
    final children = node.childrenBySlot['criterions'] ?? const <Node>[];
    if (children.isEmpty) return 'Условия пока не добавлены';
    final joiner = node.fields['operator'] == 'or' ? ' ИЛИ ' : ' И ';
    return children
        .map((child) {
          final text = filterSummary(child);
          return child.typeId == TypeIds.searchFilterGroup ? '($text)' : text;
        })
        .join(joiner);
  }
  if (node.typeId == TypeIds.searchFilterInvalid) return 'Условие не распознано';
  final property = node.fields['alias'] ?? node.fields['property'];
  final name = property is String && property.trim().isNotEmpty ? property.trim() : 'Поле не выбрано';
  final operator = node.fields['operator'] as String? ?? '';
  if (operator == 'empty') return '$name — не заполнено';
  if (operator == 'notempty') return '$name — заполнено';
  final value = node.fields['value'];
  final text = switch (value) {
    List values => values.isEmpty ? 'значения не заданы' : values.map((item) => '«$item»').join(', '),
    String text when text.trim().isNotEmpty => '«${text.trim()}»',
    _ => 'значение не задано',
  };
  return '$name ${UiStrings.enumLabel(operator)} $text';
}
