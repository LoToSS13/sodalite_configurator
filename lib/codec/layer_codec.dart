import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

export 'package:sodalite_configurator/codec/json_format.dart' show ImportWarning;

Map<String, dynamic> encodeLayer(Node layer) {
  final geo = _firstChild(layer, 'geo');
  final encoded = <String, dynamic>{'geo': _encodeGeo(geo)};
  final info = _firstChild(layer, 'info');
  if (info != null) {
    encoded['info'] = {'alias': info.fields['alias'] ?? ''};
  }
  return encoded;
}

({Node layer, List<ImportWarning> warnings}) decodeLayer(Object json, {required String id, required bool isBase}) {
  final warnings = <ImportWarning>[];
  final root = _asMap(json);
  if (root == null) {
    warnings.add(const ImportWarning(file: 'layer.json', message: 'Expected a JSON object; value was dropped.'));
  }
  final layerJson = root ?? const <String, dynamic>{};
  _warnUnknown(layerJson, const {'geo', 'info'}, r'$', warnings);

  final geoJson = _asMap(layerJson['geo']) ?? const <String, dynamic>{};
  final geo = _decodeGeo(geoJson, id: '$id-geo', isBase: isBase, warnings: warnings);
  final children = <String, List<Node>>{
    'geo': [geo],
  };

  if (layerJson.containsKey('info')) {
    final infoJson = _asMap(layerJson['info']) ?? const <String, dynamic>{};
    _warnUnknown(infoJson, const {'alias'}, r'$.info', warnings);
    children['info'] = [
      Node(id: '$id-info', typeId: 'info', fields: {'alias': infoJson['alias'] ?? ''}),
    ];
  }

  return (layer: Node(id: id, typeId: TypeIds.layer, childrenBySlot: children), warnings: warnings);
}

Map<String, dynamic> _encodeGeo(Node? geo) {
  final fields = geo?.fields ?? const <String, Object?>{};
  final encoded = <String, dynamic>{'alias': fields['alias'] ?? ''};
  if (fields['name'] != null) {
    encoded['name'] = fields['name'];
  }
  if (fields['visibilityThreshold'] != null) {
    encoded['visibilityThreshold'] = fields['visibilityThreshold'];
  }
  encoded['hasMarkers'] = fields['hasMarkers'] ?? false;
  encoded['showTagInCluster'] = fields['showTagInCluster'] ?? false;

  final style = geo == null ? null : _firstChild(geo, 'style');
  if (style != null) {
    encoded['style'] = _encodeStyle(style);
  }

  final sources = geo?.childrenBySlot['sources'] ?? const <Node>[];
  if (sources.isNotEmpty) {
    encoded['sources'] = sources.map(_encodeSource).toList();
  }
  return encoded;
}

Map<String, dynamic> _encodeStyle(Node style) => {
  'color': style.fields['color'] ?? '',
  'isDashed': style.fields['isDashed'] ?? false,
};

Map<String, dynamic> _encodeSource(Node source) {
  final encoded = <String, dynamic>{};
  if (source.fields['name'] != null) {
    encoded['name'] = source.fields['name'];
  }
  if (source.fields['icon'] != null) {
    encoded['icon'] = source.fields['icon'];
  }
  final style = _firstChild(source, 'style');
  if (style != null) {
    encoded['style'] = _encodeStyle(style);
  }
  if (source.fields['view'] != null) {
    encoded['view'] = source.fields['view'];
  }
  final rule = _firstChild(source, 'rule');
  if (rule != null) {
    encoded['rule'] = _encodeRule(rule);
  }
  return encoded;
}

Map<String, dynamic> _encodeRule(Node rule) {
  final operator = rule.fields['operator'] ?? '';
  return {
    'operator': operator,
    'property': rule.fields['property'] ?? '',
    'value': operator == 'isnull' || operator == 'isnotnull' ? '' : rule.fields['value'] ?? '',
  };
}

Node _decodeGeo(
  Map<String, dynamic> json, {
  required String id,
  required bool isBase,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(
    json,
    const {'alias', 'name', 'visibilityThreshold', 'hasMarkers', 'showTagInCluster', 'style', 'sources'},
    r'$.geo',
    warnings,
  );
  final fields = <String, Object?>{'alias': json['alias'] ?? ''};
  if (json.containsKey('name')) {
    fields['name'] = json['name'];
  }
  if (json.containsKey('visibilityThreshold')) {
    fields['visibilityThreshold'] = json['visibilityThreshold'];
  }
  fields['hasMarkers'] = json.containsKey('hasMarkers') ? json['hasMarkers'] : isBase;
  fields['showTagInCluster'] = json.containsKey('showTagInCluster') ? json['showTagInCluster'] : isBase;

  final children = <String, List<Node>>{};
  if (json.containsKey('style')) {
    final styleJson = _asMap(json['style']) ?? const <String, dynamic>{};
    children['style'] = [_decodeStyle(styleJson, id: '$id-style', path: r'$.geo.style', warnings: warnings)];
  }

  final sourcesJson = json['sources'];
  if (sourcesJson is List) {
    children['sources'] = [
      for (var index = 0; index < sourcesJson.length; index++)
        _decodeSource(
          _asMap(sourcesJson[index]) ?? const <String, dynamic>{},
          id: '$id-source-$index',
          path:
              r'$.geo.sources['
              '$index]',
          warnings: warnings,
        ),
    ];
  }
  return Node(id: id, typeId: TypeIds.geo, fields: fields, childrenBySlot: children);
}

Node _decodeStyle(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(json, const {'color', 'isDashed'}, path, warnings);
  return Node(
    id: id,
    typeId: TypeIds.geoStyle,
    fields: {'color': json['color'] ?? '', 'isDashed': json['isDashed'] ?? false},
  );
}

Node _decodeSource(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(json, const {'name', 'icon', 'style', 'view', 'rule'}, path, warnings);
  final fields = <String, Object?>{};
  for (final key in const ['name', 'icon', 'view']) {
    if (json.containsKey(key)) {
      fields[key] = json[key];
    }
  }

  final children = <String, List<Node>>{};
  if (json.containsKey('style')) {
    children['style'] = [
      _decodeStyle(
        _asMap(json['style']) ?? const <String, dynamic>{},
        id: '$id-style',
        path: '$path.style',
        warnings: warnings,
      ),
    ];
  }
  if (json.containsKey('rule')) {
    final ruleJson = _asMap(json['rule']) ?? const <String, dynamic>{};
    _warnUnknown(ruleJson, const {'operator', 'property', 'value'}, '$path.rule', warnings);
    children['rule'] = [
      Node(
        id: '$id-rule',
        typeId: TypeIds.geoRule,
        fields: {
          'operator': ruleJson['operator'] ?? '',
          'property': ruleJson['property'] ?? '',
          'value': ruleJson['value'] ?? '',
        },
      ),
    ];
  }
  return Node(id: id, typeId: TypeIds.geoSource, fields: fields, childrenBySlot: children);
}

Node? _firstChild(Node node, String slot) {
  final children = node.childrenBySlot[slot];
  return children == null || children.isEmpty ? null : children.first;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

void _warnUnknown(Map<String, dynamic> json, Set<String> known, String path, List<ImportWarning> warnings) {
  for (final key in json.keys.where((key) => !known.contains(key))) {
    warnings.add(ImportWarning(file: 'layer.json', message: 'Unknown key "$key" at $path was dropped.'));
  }
}
