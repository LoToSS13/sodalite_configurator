import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/codec/app_codec.dart';
import 'package:sodalite_configurator/codec/layer_codec.dart';
import 'package:sodalite_configurator/codec/object_creation_codec.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

export 'package:sodalite_configurator/codec/json_format.dart' show ImportWarning;

@immutable
class ModuleFiles {
  final String slug;
  final Map<String, dynamic> app;
  final Map<String, dynamic> baseLayer;
  final List<Map<String, dynamic>> additionalLayers;
  final Map<String, dynamic>? objectCreation;
  final Map<String, dynamic>? search;

  ModuleFiles({
    required this.slug,
    required this.app,
    required this.baseLayer,
    required Object additionalLayers,
    this.objectCreation,
    this.search,
  }) : additionalLayers = _normalizeAdditionalLayers(additionalLayers);
}

ModuleFiles encodeModule(Node bundle) {
  final app = _firstChild(bundle, 'app') ?? const Node(id: '', typeId: TypeIds.app);
  final baseLayer = _firstChild(bundle, 'baseLayer') ?? const Node(id: '', typeId: TypeIds.layer);
  final additionalLayers = bundle.childrenBySlot['additionalLayers'] ?? const <Node>[];
  final objectCreation = _firstChild(bundle, 'objectCreation');
  final search = _firstChild(bundle, 'search');

  return ModuleFiles(
    slug: bundle.fields['slug'] as String? ?? '',
    app: encodeApp(app),
    baseLayer: encodeLayer(baseLayer),
    additionalLayers: additionalLayers.map(encodeLayer).toList(),
    objectCreation: objectCreation == null ? null : encodeObjectCreation(objectCreation),
    search: search == null ? null : _encodeStub(search),
  );
}

({Node bundle, List<ImportWarning> warnings}) decodeModule(ModuleFiles files, {required String Function() id}) {
  final warnings = <ImportWarning>[];
  _warnUnknownApp(files.app, warnings);

  final bundleId = id();
  final app = decodeApp(files.app, id: id());
  final baseResult = decodeLayer(files.baseLayer, id: id(), isBase: true);
  warnings.addAll(_forFile(baseResult.warnings, 'base_layer.json'));

  final additionalLayers = <Node>[];
  for (final layerJson in files.additionalLayers) {
    final result = decodeLayer(layerJson, id: id(), isBase: false);
    additionalLayers.add(result.layer);
    warnings.addAll(_forFile(result.warnings, 'additional_layers.json'));
  }

  final children = <String, List<Node>>{
    'app': [app],
    'baseLayer': [baseResult.layer],
    if (additionalLayers.isNotEmpty) 'additionalLayers': additionalLayers,
  };
  if (files.objectCreation != null) {
    final decoded = decodeObjectCreation(files.objectCreation!, id: id());
    children['objectCreation'] = [decoded.node];
    warnings.addAll(decoded.warnings);
  }
  if (files.search != null) {
    children['search'] = [
      _decodeStub(files.search!, id: id(), typeId: 'search', file: 'search.json', warnings: warnings),
    ];
  }

  return (
    bundle: Node(id: bundleId, typeId: TypeIds.moduleBundle, fields: {'slug': files.slug}, childrenBySlot: children),
    warnings: warnings,
  );
}

List<Map<String, dynamic>> _normalizeAdditionalLayers(Object value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (value is Map) {
    return [Map<String, dynamic>.from(value)];
  }
  return [];
}

Map<String, dynamic> _encodeStub(Node node) => {'xsdPath': node.fields['xsdPath'] ?? ''};

Node _decodeStub(
  Map<String, dynamic> json, {
  required String id,
  required String typeId,
  required String file,
  required List<ImportWarning> warnings,
}) {
  for (final key in json.keys.where((key) => key != 'xsdPath')) {
    warnings.add(ImportWarning(file: file, message: 'Unknown key "$key" at \$ was dropped.'));
  }
  return Node(id: id, typeId: typeId, fields: {'xsdPath': json['xsdPath'] ?? ''});
}

void _warnUnknownApp(Map<String, dynamic> json, List<ImportWarning> warnings) {
  for (final key in json.keys.where((key) => key != 'title' && key != 'subtitle')) {
    warnings.add(ImportWarning(file: 'app.json', message: 'Unknown key "$key" at \$ was dropped.'));
  }
}

Iterable<ImportWarning> _forFile(List<ImportWarning> warnings, String file) {
  return warnings.map((warning) => ImportWarning(file: file, message: warning.message));
}

Node? _firstChild(Node node, String slot) {
  final children = node.childrenBySlot[slot];
  return children == null || children.isEmpty ? null : children.first;
}
