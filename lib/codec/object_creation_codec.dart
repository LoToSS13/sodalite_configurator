import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

Map<String, dynamic> encodeObjectCreation(Node creation) {
  final encoded = <String, dynamic>{'xsdPath': creation.fields['xsdPath'] ?? ''};
  final geometryTypes = [
    for (final child in creation.childrenBySlot['geometryTypes'] ?? const <Node>[]) _encodeGeometryType(child),
  ];
  if (geometryTypes.isNotEmpty) {
    encoded['geometryTypes'] = geometryTypes;
  }
  encoded['requireDateWatermark'] = creation.fields['requireDateWatermark'] ?? true;
  encoded['saveToGallery'] = creation.fields['saveToGallery'] ?? false;

  final style = <String, dynamic>{};
  final color = creation.fields['color'];
  if (color is String && color.isNotEmpty) {
    style['color'] = color;
  }
  final iconPath = creation.fields['iconPath'];
  if (iconPath is String && iconPath.isNotEmpty) {
    style['iconPath'] = iconPath;
  }
  if (style.isNotEmpty) {
    encoded['style'] = style;
  }
  return encoded;
}

({Node node, List<ImportWarning> warnings}) decodeObjectCreation(Map<String, dynamic> json, {required String id}) {
  final warnings = <ImportWarning>[];
  _warnUnknown(json, const {'xsdPath', 'geometryTypes', 'requireDateWatermark', 'saveToGallery', 'style'}, warnings);

  final fields = <String, Object?>{
    'xsdPath': json['xsdPath'] ?? '',
    'requireDateWatermark': json['requireDateWatermark'] is bool ? json['requireDateWatermark'] as bool : true,
    'saveToGallery': json['saveToGallery'] is bool ? json['saveToGallery'] as bool : false,
  };

  final style = json['style'];
  if (style is Map) {
    final styleMap = Map<String, dynamic>.from(style);
    _warnUnknown(styleMap, const {'color', 'iconPath'}, warnings, path: 'style');
    if (styleMap['color'] is String) {
      fields['color'] = styleMap['color'];
    }
    if (styleMap['iconPath'] is String) {
      fields['iconPath'] = styleMap['iconPath'];
    }
  } else if (style != null) {
    warnings.add(
      const ImportWarning(file: 'object_creation.json', message: 'style must be an object and was dropped.'),
    );
  }

  final children = <String, List<Node>>{};
  final geometryJson = json['geometryTypes'];
  if (geometryJson is List) {
    final geometryTypes = <Node>[];
    for (var index = 0; index < geometryJson.length; index++) {
      final item = geometryJson[index];
      if (item is! Map) {
        warnings.add(
          ImportWarning(
            file: 'object_creation.json',
            message: 'geometryTypes[$index] must be an object and was dropped.',
          ),
        );
        continue;
      }
      geometryTypes.add(
        _decodeGeometryType(Map<String, dynamic>.from(item), id: '$id-geometry-$index', warnings: warnings),
      );
    }
    if (geometryTypes.isNotEmpty) {
      children['geometryTypes'] = geometryTypes;
    }
  } else if (geometryJson != null) {
    warnings.add(
      const ImportWarning(file: 'object_creation.json', message: 'geometryTypes must be an array and was dropped.'),
    );
  }

  return (
    node: Node(id: id, typeId: TypeIds.objectCreation, fields: fields, childrenBySlot: children),
    warnings: warnings,
  );
}

Map<String, dynamic> _encodeGeometryType(Node node) {
  final encoded = <String, dynamic>{'type': node.fields['type'] ?? ''};
  if (node.fields['autoMode'] == true) {
    encoded['autoMode'] = true;
  }
  return encoded;
}

Node _decodeGeometryType(Map<String, dynamic> json, {required String id, required List<ImportWarning> warnings}) {
  _warnUnknown(json, const {'type', 'autoMode'}, warnings);
  return Node(
    id: id,
    typeId: TypeIds.geometryType,
    fields: {'type': json['type'] ?? '', if (json['autoMode'] is bool) 'autoMode': json['autoMode'] as bool},
  );
}

void _warnUnknown(Map<String, dynamic> json, Set<String> known, List<ImportWarning> warnings, {String path = r'$'}) {
  for (final key in json.keys.where((key) => !known.contains(key))) {
    warnings.add(ImportWarning(file: 'object_creation.json', message: 'Unknown key "$key" at $path was dropped.'));
  }
}
