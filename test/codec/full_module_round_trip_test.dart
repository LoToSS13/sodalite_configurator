import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/zip_io.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  test('golden module round-trips through decode/encode and validates', () {
    final golden = _loadGolden();
    final original = _filesFrom(golden);
    final decoded = decodeModule(original, id: _ids());
    expect(decoded.warnings, isEmpty);
    expect(validate(decoded.bundle, Catalog.modulePack()), isEmpty);

    final encoded = encodeModule(decoded.bundle);
    expect(_asJson(encoded.app), golden['app.json']);
    expect(_asJson(encoded.baseLayer), golden['base_layer.json']);
    expect(_asJson(encoded.additionalLayers), golden['additional_layers.json']);
    expect(_asJson(encoded.objectCreation), golden['object_creation.json']);
    expect(_asJson(encoded.search), golden['search.json']);
    expect(encoded.slug, golden['slug']);

    final roundTripped = encodeModule(decodeModule(encoded, id: _ids()).bundle);
    expect(_asJson(roundTripped.app), _asJson(encoded.app));
    expect(_asJson(roundTripped.baseLayer), _asJson(encoded.baseLayer));
    expect(_asJson(roundTripped.additionalLayers), _asJson(encoded.additionalLayers));
    expect(_asJson(roundTripped.objectCreation), _asJson(encoded.objectCreation));
    expect(_asJson(roundTripped.search), _asJson(encoded.search));
    expect(roundTripped.slug, encoded.slug);

    final archive = ZipDecoder().decodeBytes(buildModuleZip(encoded));
    expect(archive.files.map((file) => file.name).toSet(), {
      'apps/land_v2/app.json',
      'apps/land_v2/base_layer.json',
      'apps/land_v2/additional_layers.json',
      'apps/land_v2/object_creation.json',
      'apps/land_v2/search.json',
    });
  });
}

Map<String, dynamic> _loadGolden() {
  return jsonDecode(File('test/codec/goldens/full_module.json').readAsStringSync()) as Map<String, dynamic>;
}

ModuleFiles _filesFrom(Map<String, dynamic> golden) {
  return ModuleFiles(
    slug: golden['slug'] as String,
    app: Map<String, dynamic>.from(golden['app.json'] as Map),
    baseLayer: Map<String, dynamic>.from(golden['base_layer.json'] as Map),
    additionalLayers: golden['additional_layers.json'] as List,
    objectCreation: Map<String, dynamic>.from(golden['object_creation.json'] as Map),
    search: Map<String, dynamic>.from(golden['search.json'] as Map),
  );
}

Object? _asJson(Object? value) => jsonDecode(jsonEncode(value));

String Function() _ids() {
  var next = 0;
  return () => 'id-${next++}';
}
