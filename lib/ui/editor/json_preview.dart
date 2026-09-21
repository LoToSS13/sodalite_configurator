import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/schema/node.dart';

class JsonPreview extends StatelessWidget {
  const JsonPreview({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    );
  }
}

String modulePreviewText(Node bundle) => encodeJson(modulePreviewMap(bundle));

Map<String, dynamic> modulePreviewMap(Node bundle) {
  final files = encodeModule(bundle);
  return {
    'app.json': files.app,
    'base_layer.json': files.baseLayer,
    'additional_layers.json': files.additionalLayers,
    if (files.objectCreation != null) 'object_creation.json': files.objectCreation,
    if (files.search != null) 'search.json': files.search,
  };
}
