import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

Map<String, dynamic> encodeSearch(Node search) {
  final encoded = <String, dynamic>{};
  final placeholder = search.fields['placeholder'];
  if (placeholder is String && placeholder.isNotEmpty) {
    encoded['placeholder'] = placeholder;
  }
  encoded['searchObjects'] = [
    for (final object in search.childrenBySlot['searchObjects'] ?? const <Node>[]) _encodeSearchObject(object),
  ];
  return encoded;
}

({Node node, List<ImportWarning> warnings}) decodeSearch(Map<String, dynamic> json, {required String id}) {
  final warnings = <ImportWarning>[];
  _warnUnknown(json, const {'placeholder', 'searchObjects'}, warnings);

  final fields = <String, Object?>{};
  if (json['placeholder'] is String) {
    fields['placeholder'] = json['placeholder'];
  }

  final children = <String, List<Node>>{};
  final objectsJson = json['searchObjects'];
  if (objectsJson is List) {
    final objects = <Node>[];
    for (var index = 0; index < objectsJson.length; index++) {
      final item = objectsJson[index];
      if (item is Map) {
        objects.add(_decodeSearchObject(Map<String, dynamic>.from(item), id: '$id-object-$index', warnings: warnings));
      } else {
        warnings.add(
          ImportWarning(file: 'search.json', message: 'searchObjects[$index] must be an object and was dropped.'),
        );
      }
    }
    if (objects.isNotEmpty) {
      children['searchObjects'] = objects;
    }
  } else if (objectsJson != null) {
    warnings.add(const ImportWarning(file: 'search.json', message: 'searchObjects must be an array and was dropped.'));
  }

  return (node: Node(id: id, typeId: TypeIds.search, fields: fields, childrenBySlot: children), warnings: warnings);
}

Map<String, dynamic> _encodeSearchObject(Node object) {
  final encoded = <String, dynamic>{
    'alias': object.fields['alias'] ?? '',
    'objectKeyFieldPath': object.fields['objectKeyFieldPath'] ?? '',
    'paths': object.fields['paths'] ?? const <String, String>{},
    'attribute': object.fields['attribute'] ?? '',
  };
  final resultView = <String, dynamic>{'title': object.fields['title'] ?? ''};
  final subtitle1 = object.fields['subtitle1'];
  if (subtitle1 is String && subtitle1.isNotEmpty) {
    resultView['subtitle1'] = subtitle1;
  }
  final subtitle2 = object.fields['subtitle2'];
  if (subtitle2 is String && subtitle2.isNotEmpty) {
    resultView['subtitle2'] = subtitle2;
  }
  encoded['resultView'] = resultView;

  final jetAlias = object.fields['aopJetAlias'];
  final keyField = object.fields['aopKeyField'];
  if (jetAlias is String && jetAlias.isNotEmpty && keyField is String && keyField.isNotEmpty) {
    encoded['alternativePositionObject'] = {'jetAlias': jetAlias, 'keyField': keyField};
  }

  final filter = object.childrenBySlot['filter'];
  if (filter != null && filter.isNotEmpty && filter.first.typeId == TypeIds.searchFilterGroup) {
    encoded['filter'] = _encodeFilter(filter.first);
  }
  return encoded;
}

Node _decodeSearchObject(Map<String, dynamic> json, {required String id, required List<ImportWarning> warnings}) {
  _warnUnknown(json, const {
    'alias',
    'objectKeyFieldPath',
    'paths',
    'attribute',
    'resultView',
    'alternativePositionObject',
    'filter',
  }, warnings);

  final resultView = json['resultView'] is Map
      ? Map<String, dynamic>.from(json['resultView'] as Map)
      : const <String, dynamic>{};
  if (json['resultView'] is Map) {
    _warnUnknown(resultView, const {'title', 'subtitle1', 'subtitle2'}, warnings, path: 'resultView');
  }

  final fields = <String, Object?>{
    'alias': json['alias'] ?? '',
    'objectKeyFieldPath': json['objectKeyFieldPath'] ?? '',
    'attribute': json['attribute'] ?? '',
    'paths': _stringMap(json['paths']),
    'title': resultView['title'] ?? '',
    if (resultView['subtitle1'] is String) 'subtitle1': resultView['subtitle1'],
    if (resultView['subtitle2'] is String) 'subtitle2': resultView['subtitle2'],
  };

  final aop = json['alternativePositionObject'];
  if (aop is Map) {
    final aopMap = Map<String, dynamic>.from(aop);
    _warnUnknown(aopMap, const {'jetAlias', 'keyField'}, warnings, path: 'alternativePositionObject');
    fields['aopJetAlias'] = aopMap['jetAlias'] ?? '';
    fields['aopKeyField'] = aopMap['keyField'] ?? '';
  }

  final children = <String, List<Node>>{};
  if (json.containsKey('filter')) {
    final filterJson = json['filter'];
    if (filterJson is Map) {
      children['filter'] = [
        _decodeFilterRoot(Map<String, dynamic>.from(filterJson), id: '$id-filter', warnings: warnings),
      ];
    } else {
      warnings.add(const ImportWarning(file: 'search.json', message: 'filter must be an object and was dropped.'));
    }
  }

  return Node(id: id, typeId: TypeIds.searchObject, fields: fields, childrenBySlot: children);
}

Map<String, dynamic> _encodeFilter(Node node) {
  return switch (node.typeId) {
    TypeIds.searchFilterGroup => {
      'operator': node.fields['operator'] ?? 'and',
      'criterions': [
        for (final child in node.childrenBySlot['criterions'] ?? const <Node>[])
          if (child.typeId != TypeIds.searchFilterInvalid) _encodeFilter(child),
      ],
    },
    TypeIds.searchFilterScalar => {
      'operator': node.fields['operator'] ?? 'eq',
      'alias': node.fields['alias'] ?? '',
      'value': node.fields['value'] ?? '',
    },
    TypeIds.searchFilterList => {
      'operator': node.fields['operator'] ?? 'in',
      'alias': node.fields['alias'] ?? '',
      'value': node.fields['value'] ?? const <String>[],
    },
    TypeIds.searchFilterEmpty => {'operator': node.fields['operator'] ?? 'empty', 'alias': node.fields['alias'] ?? ''},
    _ => {'operator': 'and', 'criterions': <Map<String, dynamic>>[]},
  };
}

Node _decodeFilterRoot(Map<String, dynamic> json, {required String id, required List<ImportWarning> warnings}) {
  if (json.containsKey('criterions')) {
    return _decodeFilterGroup(json, id: id, warnings: warnings);
  }
  warnings.add(const ImportWarning(file: 'search.json', message: 'filter root must be an and/or group.'));
  return _invalidFilter(id: id, reason: 'filter root must be a group', warnings: warnings);
}

Node _decodeFilterNode(Map<String, dynamic> json, {required String id, required List<ImportWarning> warnings}) {
  if (json.containsKey('criterions')) {
    return _decodeFilterGroup(json, id: id, warnings: warnings);
  }
  if (json.containsKey('property') || json['alias'] is! String || (json['alias'] as String).isEmpty) {
    warnings.add(
      const ImportWarning(
        file: 'search.json',
        message: 'Search filter leaf must use Consul alias, not Jasper property.',
      ),
    );
    return _invalidFilter(id: id, reason: 'leaf used property or missing alias', warnings: warnings);
  }
  final operator = json['operator'];
  return switch (operator) {
    'empty' || 'notempty' => Node(
      id: id,
      typeId: TypeIds.searchFilterEmpty,
      fields: {'operator': operator, 'alias': json['alias']},
    ),
    'in' || 'notin' => Node(
      id: id,
      typeId: TypeIds.searchFilterList,
      fields: {
        'operator': operator,
        'alias': json['alias'],
        'value': json['value'] is List
            ? [
                for (final item in json['value'] as List)
                  if (item is String) item,
              ]
            : const <String>[],
      },
    ),
    'eq' || 'noteq' || 'like' || 'notlike' || 'gt' || 'lt' || 'gte' || 'lte' => Node(
      id: id,
      typeId: TypeIds.searchFilterScalar,
      fields: {'operator': operator, 'alias': json['alias'], 'value': json['value'] ?? ''},
    ),
    _ => _unknownOperator(operator, id: id, warnings: warnings),
  };
}

Node _decodeFilterGroup(Map<String, dynamic> json, {required String id, required List<ImportWarning> warnings}) {
  _warnUnknown(json, const {'operator', 'criterions'}, warnings);
  final criterionsJson = json['criterions'];
  final criterions = <Node>[];
  if (criterionsJson is List) {
    for (var index = 0; index < criterionsJson.length; index++) {
      final item = criterionsJson[index];
      if (item is Map) {
        criterions.add(_decodeFilterNode(Map<String, dynamic>.from(item), id: '$id-c$index', warnings: warnings));
      } else {
        warnings.add(
          ImportWarning(file: 'search.json', message: 'criterions[$index] must be an object and was dropped.'),
        );
      }
    }
  } else if (criterionsJson != null) {
    warnings.add(const ImportWarning(file: 'search.json', message: 'criterions must be an array and was dropped.'));
  }
  return Node(
    id: id,
    typeId: TypeIds.searchFilterGroup,
    fields: {'operator': json['operator'] ?? 'and'},
    childrenBySlot: {if (criterions.isNotEmpty) 'criterions': criterions},
  );
}

Node _unknownOperator(Object? operator, {required String id, required List<ImportWarning> warnings}) {
  warnings.add(ImportWarning(file: 'search.json', message: 'Unknown search filter operator "$operator".'));
  return _invalidFilter(id: id, reason: 'unknown operator $operator', warnings: warnings);
}

Node _invalidFilter({required String id, required String reason, required List<ImportWarning> warnings}) {
  return Node(id: id, typeId: TypeIds.searchFilterInvalid, fields: {'reason': reason});
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
  };
}

void _warnUnknown(Map<String, dynamic> json, Set<String> known, List<ImportWarning> warnings, {String path = r'$'}) {
  for (final key in json.keys.where((key) => !known.contains(key))) {
    warnings.add(ImportWarning(file: 'search.json', message: 'Unknown key "$key" at $path was dropped.'));
  }
}
