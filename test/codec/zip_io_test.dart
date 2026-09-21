import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/zip_io.dart';

void main() {
  test('zip contains three json files under apps/slug', () {
    final bytes = buildModuleZip(
      ModuleFiles(
        slug: 'land_v2',
        app: {'title': 'T', 'subtitle': 'S'},
        baseLayer: {
          'geo': {'alias': 'L', 'hasMarkers': true, 'showTagInCluster': true},
        },
        additionalLayers: const [],
      ),
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, {'apps/land_v2/app.json', 'apps/land_v2/base_layer.json', 'apps/land_v2/additional_layers.json'});
  });

  test('zip writes pretty UTF-8 JSON and includes optional files', () {
    final archive = ZipDecoder().decodeBytes(
      buildModuleZip(
        ModuleFiles(
          slug: 'land',
          app: {'title': 'Земля', 'subtitle': 'S'},
          baseLayer: const {'geo': {}},
          additionalLayers: const [],
          objectCreation: const {'xsdPath': 'object.xsd'},
          search: const {'xsdPath': 'search.xsd'},
        ),
      ),
    );

    final files = {for (final file in archive.files) file.name: utf8.decode(file.content)};
    expect(files['apps/land/app.json'], '{\n  "title": "Земля",\n  "subtitle": "S"\n}');
    expect(files['apps/land/additional_layers.json'], '[]');
    expect(files, contains('apps/land/object_creation.json'));
    expect(files, contains('apps/land/search.json'));
  });

  test('parses a generated module zip', () {
    final original = ModuleFiles(
      slug: 'land',
      app: const {'title': 'T', 'subtitle': 'S'},
      baseLayer: const {
        'geo': {'alias': 'L'},
      },
      additionalLayers: const [
        {
          'geo': {'alias': 'A'},
        },
      ],
      objectCreation: const {'xsdPath': 'object.xsd'},
    );

    final parsed = parseModuleZip(buildModuleZip(original));

    expect(parsed.files.slug, original.slug);
    expect(parsed.files.app, original.app);
    expect(parsed.files.baseLayer, original.baseLayer);
    expect(parsed.files.additionalLayers, original.additionalLayers);
    expect(parsed.files.objectCreation, original.objectCreation);
    expect(parsed.files.search, isNull);
    expect(parsed.warnings, isEmpty);
  });
}
