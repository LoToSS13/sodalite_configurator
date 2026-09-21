import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

export 'package:sodalite_configurator/codec/json_format.dart' show ImportWarning;

Map<String, dynamic> encodeLayer(Node layer) {
  final geo = _firstChild(layer, 'geo');
  final encoded = <String, dynamic>{'geo': _encodeGeo(geo)};
  final info = _firstChild(layer, 'info');
  if (info != null) {
    encoded['info'] = _encodeInfo(info);
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
    children['info'] = [_decodeInfo(infoJson, id: '$id-info', warnings: warnings)];
  }

  return (layer: Node(id: id, typeId: TypeIds.layer, childrenBySlot: children), warnings: warnings);
}

Map<String, dynamic> _encodeInfo(Node info) {
  final fields = info.fields;
  final encoded = <String, dynamic>{'alias': fields['alias'] ?? ''};
  final paths = fields['paths'];
  if (paths is Map && paths.isNotEmpty) {
    encoded['paths'] = paths;
  }

  final titleContent = fields['titleContent'];
  if (titleContent is String && titleContent.isNotEmpty) {
    encoded['title'] = {'content': titleContent};
  }
  if (fields.containsKey('subtitleContent')) {
    encoded['subtitle'] = {'content': fields['subtitleContent'] ?? ''};
  }
  if (fields.containsKey('statusContent')) {
    encoded['status'] = {'content': fields['statusContent'] ?? ''};
  }
  if (fields.containsKey('additionalTitle')) {
    encoded['additionalTitle'] = fields['additionalTitle'];
  }

  _encodeChildren(info, 'infoSections', encoded, _encodeInfoSection);
  _encodeChildren(info, 'images', encoded, _encodeImageSection);
  _encodeChildren(info, 'attachments', encoded, _encodeAttachmentSection);
  _encodeChildren(info, 'inspectionView', encoded, _encodeInspectionTab);
  _encodeChildren(info, 'actions', encoded, _encodeAction);
  return encoded;
}

void _encodeChildren(
  Node parent,
  String slot,
  Map<String, dynamic> encoded,
  Map<String, dynamic> Function(Node) encode,
) {
  final children = parent.childrenBySlot[slot] ?? const <Node>[];
  if (children.isNotEmpty) {
    encoded[slot] = children.map(encode).toList();
  }
}

Map<String, dynamic> _encodeInfoSection(Node section) {
  final encoded = <String, dynamic>{};
  if (section.fields.containsKey('title')) {
    encoded['title'] = section.fields['title'];
  }
  encoded['fields'] = (section.childrenBySlot['fields'] ?? const <Node>[]).map(_encodeFieldRow).toList();
  return encoded;
}

Map<String, dynamic> _encodeFieldRow(Node field) {
  final encoded = <String, dynamic>{'name': field.fields['name'] ?? '', 'content': field.fields['content'] ?? ''};
  for (final key in const ['separator', 'url', 'ifTrue', 'ifFalse']) {
    if (field.fields.containsKey(key)) {
      encoded[key] = field.fields[key];
    }
  }
  return encoded;
}

Map<String, dynamic> _encodeImageSection(Node section) {
  final encoded = <String, dynamic>{};
  if (section.fields.containsKey('title')) {
    encoded['title'] = section.fields['title'];
  }
  encoded['sources'] = section.fields['sources'] ?? const <String>[];
  return encoded;
}

Map<String, dynamic> _encodeAttachmentSection(Node section) {
  final encoded = _encodeImageSection(section);
  if (section.fields.containsKey('extensions')) {
    encoded['extensions'] = section.fields['extensions'];
  }
  return encoded;
}

Map<String, dynamic> _encodeInspectionTab(Node tab) {
  final encoded = <String, dynamic>{};
  for (final key in const ['tabName', 'processName']) {
    if (tab.fields.containsKey(key)) {
      encoded[key] = tab.fields[key];
    }
  }
  encoded['objects'] = {
    for (final object in tab.childrenBySlot['objects'] ?? const <Node>[])
      object.fields['pathKey'] ?? '': _encodeInspectionObject(object),
  };
  final creation = _firstChild(tab, 'creation');
  if (creation != null) {
    encoded['creation'] = _encodeInspectionCreation(creation);
  }
  return encoded;
}

Map<String, dynamic> _encodeInspectionObject(Node object) {
  final fields = object.fields;
  final encoded = <String, dynamic>{
    'endpoints': fields['endpoints'] ?? const <String, String>{},
    'title': {'content': fields['titleContent'] ?? ''},
  };
  if (fields.containsKey('subtitleContent')) {
    encoded['subtitle'] = {'content': fields['subtitleContent']};
  }

  final tag = <String, dynamic>{};
  for (final entry in const {'tagColor': 'color', 'tagContent': 'content', 'tagIfTrue': 'ifTrue'}.entries) {
    if (fields.containsKey(entry.key)) {
      tag[entry.value] = fields[entry.key];
    }
  }
  if (tag.isNotEmpty) {
    encoded['tag'] = tag;
  }

  _encodeChildren(object, 'fields', encoded, _encodeFieldRow);
  if (fields.containsKey('imagesSource')) {
    encoded['images'] = {'source': fields['imagesSource']};
  }
  if (fields.containsKey('attachmentsSource')) {
    final attachments = <String, dynamic>{'source': fields['attachmentsSource']};
    if (fields.containsKey('extensions')) {
      attachments['extensions'] = fields['extensions'];
    }
    encoded['attachments'] = attachments;
  }
  return encoded;
}

Map<String, dynamic> _encodeInspectionCreation(Node creation) {
  final fields = creation.fields;
  final encoded = <String, dynamic>{
    'title': fields['title'] ?? '',
    'xsdPath': fields['xsdPath'] ?? '',
    'relateToObjectKey': fields['relateToObjectKey'] ?? '',
  };
  if (fields.containsKey('condition')) {
    encoded['condition'] = fields['condition'];
  }
  encoded['requireDateWatermark'] = fields['requireDateWatermark'] ?? true;
  encoded['saveToGallery'] = fields['saveToGallery'] ?? false;
  return encoded;
}

Map<String, dynamic> _encodeAction(Node action) {
  final encoded = <String, dynamic>{};
  switch (action.typeId) {
    case TypeIds.actionInformationChange:
      encoded['type'] = 'informationChange';
      encoded['xsdPath'] = action.fields['xsdPath'] ?? '';
    case TypeIds.actionGeometryChange:
      encoded['type'] = 'geometryChange';
      encoded['xsdPath'] = action.fields['xsdPath'] ?? '';
      encoded['geometryTypes'] = action.fields['geometryTypes'] ?? const <String>[];
    case TypeIds.actionUnknown:
      encoded['type'] = action.fields['rawType'] ?? '';
  }
  return encoded;
}

Node _decodeInfo(Map<String, dynamic> json, {required String id, required List<ImportWarning> warnings}) {
  _warnUnknown(
    json,
    const {
      'alias',
      'paths',
      'title',
      'subtitle',
      'status',
      'additionalTitle',
      'infoSections',
      'images',
      'attachments',
      'inspectionView',
      'actions',
      'fields',
      'preview',
      'acceptance',
    },
    r'$.info',
    warnings,
  );

  final fields = <String, Object?>{'alias': json['alias'] ?? ''};
  if (json.containsKey('paths')) {
    fields['paths'] = json['paths'];
  }
  _decodeContentField(json, 'title', 'titleContent', fields);
  _decodeContentField(json, 'subtitle', 'subtitleContent', fields);
  _decodeContentField(json, 'status', 'statusContent', fields);
  if (json.containsKey('additionalTitle')) {
    fields['additionalTitle'] = json['additionalTitle'];
  }

  final children = <String, List<Node>>{};
  final sections = _decodeInfoSections(json['infoSections'], id: id, warnings: warnings);
  if (json['fields'] is List) {
    final legacyFields = _decodeFieldRows(
      json['fields'],
      id: '$id-legacy-section',
      path: r'$.info.fields',
      warnings: warnings,
    );
    sections.insert(
      0,
      Node(
        id: '$id-legacy-section',
        typeId: TypeIds.infoSection,
        fields: const {'title': ''},
        childrenBySlot: {'fields': legacyFields},
      ),
    );
    warnings.add(const ImportWarning(file: 'layer.json', message: 'legacy fields converted'));
  } else if (json.containsKey('fields')) {
    warnings.add(const ImportWarning(file: 'layer.json', message: 'legacy fields dropped: expected a list'));
  }
  if (sections.isNotEmpty) {
    children['infoSections'] = sections;
  }

  final invalidMediaCollections = <String>[];
  final images = _decodeInfoMediaCollection(
    json,
    key: 'images',
    id: '$id-images',
    typeId: TypeIds.imageSection,
    path: r'$.info.images',
    warnings: warnings,
    invalidCollections: invalidMediaCollections,
  );
  if (images.isNotEmpty) {
    children['images'] = images;
  }
  final attachments = _decodeInfoMediaCollection(
    json,
    key: 'attachments',
    id: '$id-attachments',
    typeId: TypeIds.attachmentSection,
    path: r'$.info.attachments',
    warnings: warnings,
    invalidCollections: invalidMediaCollections,
  );
  if (attachments.isNotEmpty) {
    children['attachments'] = attachments;
  }
  final inspectionView = _decodeInspectionView(json['inspectionView'], id: id, warnings: warnings);
  if (inspectionView.isNotEmpty) {
    children['inspectionView'] = inspectionView;
  }
  final actions = _decodeActions(json['actions'], id: id, warnings: warnings);
  if (actions.isNotEmpty) {
    children['actions'] = actions;
  }
  if (invalidMediaCollections.isNotEmpty) {
    fields['_invalidMediaCollections'] = invalidMediaCollections;
  }

  if (json.containsKey('preview')) {
    warnings.add(const ImportWarning(file: 'layer.json', message: 'preview dropped'));
  }
  if (json.containsKey('acceptance')) {
    warnings.add(const ImportWarning(file: 'layer.json', message: 'acceptance dropped'));
  }

  return Node(id: id, typeId: TypeIds.info, fields: fields, childrenBySlot: children);
}

void _decodeContentField(Map<String, dynamic> json, String jsonKey, String fieldKey, Map<String, Object?> fields) {
  if (!json.containsKey(jsonKey)) {
    return;
  }
  final content = _asMap(json[jsonKey]);
  fields[fieldKey] = content?['content'] ?? '';
}

List<Node> _decodeInfoSections(Object? value, {required String id, required List<ImportWarning> warnings}) {
  if (value is! List) {
    return [];
  }
  return [
    for (var index = 0; index < value.length; index++)
      _decodeInfoSection(
        _asMap(value[index]) ?? const <String, dynamic>{},
        id: '$id-section-$index',
        path:
            r'$.info.infoSections['
            '$index]',
        warnings: warnings,
      ),
  ];
}

Node _decodeInfoSection(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(json, const {'title', 'fields'}, path, warnings);
  final fields = <String, Object?>{};
  if (json.containsKey('title')) {
    fields['title'] = json['title'];
  }
  return Node(
    id: id,
    typeId: TypeIds.infoSection,
    fields: fields,
    childrenBySlot: {'fields': _decodeFieldRows(json['fields'], id: id, path: '$path.fields', warnings: warnings)},
  );
}

List<Node> _decodeFieldRows(
  Object? value, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  if (value is! List) {
    return [];
  }
  return [
    for (var index = 0; index < value.length; index++)
      _decodeFieldRow(
        _asMap(value[index]) ?? const <String, dynamic>{},
        id: '$id-field-$index',
        path: '$path[$index]',
        warnings: warnings,
      ),
  ];
}

Node _decodeFieldRow(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(json, const {'name', 'content', 'separator', 'url', 'ifTrue', 'ifFalse'}, path, warnings);
  final fields = <String, Object?>{'name': json['name'] ?? '', 'content': json['content'] ?? ''};
  for (final key in const ['separator', 'url', 'ifTrue', 'ifFalse']) {
    if (json.containsKey(key)) {
      fields[key] = json[key];
    }
  }
  return Node(id: id, typeId: TypeIds.fieldRow, fields: fields);
}

List<Node> _decodeInfoMediaCollection(
  Map<String, dynamic> json, {
  required String key,
  required String id,
  required String typeId,
  required String path,
  required List<ImportWarning> warnings,
  required List<String> invalidCollections,
}) {
  if (!json.containsKey(key)) {
    return [];
  }
  if (json[key] is! List) {
    warnings.add(ImportWarning(file: 'layer.json', message: '$key dropped: expected a list'));
    invalidCollections.add(key);
    return [];
  }
  return _decodeMediaSections(json[key], id: id, typeId: typeId, path: path, warnings: warnings);
}

List<Node> _decodeMediaSections(
  Object? value, {
  required String id,
  required String typeId,
  required String path,
  required List<ImportWarning> warnings,
}) {
  if (value is! List) {
    return [];
  }
  return [
    for (var index = 0; index < value.length; index++)
      _decodeMediaSection(
        _asMap(value[index]) ?? const <String, dynamic>{},
        id: '$id-$index',
        typeId: typeId,
        path: '$path[$index]',
        warnings: warnings,
      ),
  ];
}

Node _decodeMediaSection(
  Map<String, dynamic> json, {
  required String id,
  required String typeId,
  required String path,
  required List<ImportWarning> warnings,
}) {
  final known = typeId == TypeIds.attachmentSection
      ? const {'title', 'sources', 'extensions'}
      : const {'title', 'sources'};
  _warnUnknown(json, known, path, warnings);
  final fields = <String, Object?>{'sources': json['sources'] ?? const <String>[]};
  if (json.containsKey('title')) {
    fields['title'] = json['title'];
  }
  if (typeId == TypeIds.attachmentSection && json.containsKey('extensions')) {
    fields['extensions'] = json['extensions'];
  }
  return Node(id: id, typeId: typeId, fields: fields);
}

List<Node> _decodeInspectionView(Object? value, {required String id, required List<ImportWarning> warnings}) {
  if (value is! List) {
    return [];
  }
  return [
    for (var index = 0; index < value.length; index++)
      _decodeInspectionTab(
        _asMap(value[index]) ?? const <String, dynamic>{},
        id: '$id-inspection-$index',
        path:
            r'$.info.inspectionView['
            '$index]',
        warnings: warnings,
      ),
  ];
}

Node _decodeInspectionTab(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(json, const {'tabName', 'processName', 'objects', 'creation'}, path, warnings);
  final fields = <String, Object?>{};
  for (final key in const ['tabName', 'processName']) {
    if (json.containsKey(key)) {
      fields[key] = json[key];
    }
  }

  final children = <String, List<Node>>{};
  final objectsJson = _asMap(json['objects']);
  if (objectsJson != null) {
    final entries = objectsJson.entries.toList();
    children['objects'] = [
      for (var index = 0; index < entries.length; index++)
        _decodeInspectionObject(
          _asMap(entries[index].value) ?? const <String, dynamic>{},
          id: '$id-object-$index',
          pathKey: entries[index].key,
          path: '$path.objects.${entries[index].key}',
          warnings: warnings,
        ),
    ];
  }
  if (json.containsKey('creation')) {
    children['creation'] = [
      _decodeInspectionCreation(
        _asMap(json['creation']) ?? const <String, dynamic>{},
        id: '$id-creation',
        path: '$path.creation',
        warnings: warnings,
      ),
    ];
  }
  return Node(id: id, typeId: TypeIds.inspectionTab, fields: fields, childrenBySlot: children);
}

Node _decodeInspectionObject(
  Map<String, dynamic> json, {
  required String id,
  required String pathKey,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(
    json,
    const {'endpoints', 'title', 'subtitle', 'tag', 'fields', 'images', 'attachments'},
    path,
    warnings,
  );
  final fields = <String, Object?>{
    'pathKey': pathKey,
    'endpoints': json['endpoints'] ?? const <String, String>{},
    'titleContent': _asMap(json['title'])?['content'] ?? '',
  };
  if (json.containsKey('subtitle')) {
    fields['subtitleContent'] = _asMap(json['subtitle'])?['content'] ?? '';
  }

  final tag = _asMap(json['tag']);
  if (tag != null) {
    for (final entry in const {'color': 'tagColor', 'content': 'tagContent', 'ifTrue': 'tagIfTrue'}.entries) {
      if (tag.containsKey(entry.key)) {
        fields[entry.value] = tag[entry.key];
      }
    }
  }
  final images = _asMap(json['images']);
  if (images != null && images.containsKey('source')) {
    fields['imagesSource'] = images['source'];
  }
  final attachments = _asMap(json['attachments']);
  if (attachments != null) {
    if (attachments.containsKey('source')) {
      fields['attachmentsSource'] = attachments['source'];
    }
    if (attachments.containsKey('extensions')) {
      fields['extensions'] = attachments['extensions'];
    }
  }

  final children = <String, List<Node>>{};
  final fieldRows = _decodeFieldRows(json['fields'], id: id, path: '$path.fields', warnings: warnings);
  if (fieldRows.isNotEmpty) {
    children['fields'] = fieldRows;
  }
  return Node(id: id, typeId: TypeIds.inspectionObject, fields: fields, childrenBySlot: children);
}

Node _decodeInspectionCreation(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  _warnUnknown(
    json,
    const {'title', 'xsdPath', 'relateToObjectKey', 'condition', 'requireDateWatermark', 'saveToGallery'},
    path,
    warnings,
  );
  final fields = <String, Object?>{
    'title': json['title'] ?? '',
    'xsdPath': json['xsdPath'] ?? '',
    'relateToObjectKey': json['relateToObjectKey'] ?? '',
    'requireDateWatermark': json['requireDateWatermark'] ?? true,
    'saveToGallery': json['saveToGallery'] ?? false,
  };
  if (json.containsKey('condition')) {
    fields['condition'] = json['condition'];
  }
  return Node(id: id, typeId: TypeIds.inspectionCreation, fields: fields);
}

List<Node> _decodeActions(Object? value, {required String id, required List<ImportWarning> warnings}) {
  if (value is! List) {
    return [];
  }
  return [
    for (var index = 0; index < value.length; index++)
      _decodeAction(
        _asMap(value[index]) ?? const <String, dynamic>{},
        id: '$id-action-$index',
        path:
            r'$.info.actions['
            '$index]',
        warnings: warnings,
      ),
  ];
}

Node _decodeAction(
  Map<String, dynamic> json, {
  required String id,
  required String path,
  required List<ImportWarning> warnings,
}) {
  final rawType = json['type'];
  switch (rawType) {
    case 'informationChange':
      _warnUnknown(json, const {'type', 'xsdPath'}, path, warnings);
      return Node(id: id, typeId: TypeIds.actionInformationChange, fields: {'xsdPath': json['xsdPath'] ?? ''});
    case 'geometryChange':
      _warnUnknown(json, const {'type', 'xsdPath', 'geometryTypes'}, path, warnings);
      return Node(
        id: id,
        typeId: TypeIds.actionGeometryChange,
        fields: {'xsdPath': json['xsdPath'] ?? '', 'geometryTypes': json['geometryTypes'] ?? const <String>[]},
      );
    default:
      _warnUnknown(json, const {'type'}, path, warnings);
      final typeName = rawType is String ? rawType : '';
      warnings.add(
        ImportWarning(
          file: 'layer.json',
          message: 'Unknown action type "$typeName" was imported as an invalid action.',
        ),
      );
      return Node(id: id, typeId: TypeIds.actionUnknown, fields: {'rawType': typeName});
  }
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
