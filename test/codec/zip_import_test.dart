import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/import_files.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/zip_io.dart';
import 'package:sodalite_configurator/schema/ids.dart';

void main() {
  test('round-trips a generated module zip', () {
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

    final result = importZip(buildModuleZip(original), id: _ids());

    expect(result.errors, isEmpty);
    expect(result.bundle, isNotNull);
    expect(result.bundle!.fields['slug'], 'land');
    expect(result.bundle!.typeId, TypeIds.moduleBundle);

    final encoded = encodeModule(result.bundle!);
    expect(encoded.app, original.app);
    expect(encoded.baseLayer['geo']['alias'], 'L');
    expect(encoded.additionalLayers.single['geo']['alias'], 'A');
    expect(encoded.objectCreation, isNotNull);
  });

  test('broken JSON in search.json does not drop base_layer', () {
    final result = importZip(
      _zip('land', {
        'app.json': '{"title":"Land","subtitle":"Map"}',
        'base_layer.json': '{"geo":{"alias":"base"}}',
        'additional_layers.json': '[]',
        'search.json': '{not-json',
      }),
      id: _ids(),
    );

    expect(result.bundle, isNotNull);
    expect(result.errors, isNotEmpty);
    expect(result.errors.single, contains('search.json'));
    expect(result.errors.single, contains('FormatException'));

    final geo = result.bundle!.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    expect(geo.fields['alias'], 'base');
    expect(result.bundle!.childrenBySlot['search'], isNull);
  });

  test('extra readme.txt warns', () {
    final result = importZip(
      _zip('land', {
        'app.json': '{"title":"Land","subtitle":"Map"}',
        'base_layer.json': '{"geo":{"alias":"base"}}',
        'additional_layers.json': '[]',
        'readme.txt': 'notes',
      }),
      id: _ids(),
    );

    expect(result.bundle, isNotNull);
    expect(result.errors, isEmpty);
    expect(result.warnings.map((warning) => warning.message).join('\n'), contains('readme.txt'));
  });

  test('additional_layers as object becomes one layer', () {
    final result = importZip(
      _zip('land', {
        'app.json': '{"title":"Land","subtitle":"Map"}',
        'base_layer.json': '{"geo":{"alias":"base"}}',
        'additional_layers.json': '{"geo":{"alias":"extra"}}',
      }),
      id: _ids(),
    );

    expect(result.errors, isEmpty);
    expect(result.bundle, isNotNull);
    final layers = result.bundle!.childrenBySlot['additionalLayers']!;
    expect(layers, hasLength(1));
    expect(layers.single.childrenBySlot['geo']!.single.fields['alias'], 'extra');
  });

  test('missing app.json still builds a module', () {
    final result = importZip(
      _zip('land', {'base_layer.json': '{"geo":{"alias":"base"}}', 'additional_layers.json': '[]'}),
      id: _ids(),
    );

    expect(result.bundle, isNotNull);
    expect(result.bundle!.childrenBySlot['app']!.single.fields['title'], '');
    expect(result.bundle!.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single.fields['alias'], 'base');
  });

  test('multiple slugs fail without a bundle', () {
    final archive = Archive()
      ..add(ArchiveFile.string('apps/one/app.json', '{"title":"A","subtitle":"S"}'))
      ..add(ArchiveFile.string('apps/one/base_layer.json', '{}'))
      ..add(ArchiveFile.string('apps/one/additional_layers.json', '[]'))
      ..add(ArchiveFile.string('apps/two/app.json', '{"title":"B","subtitle":"S"}'))
      ..add(ArchiveFile.string('apps/two/base_layer.json', '{}'))
      ..add(ArchiveFile.string('apps/two/additional_layers.json', '[]'));

    final result = importZip(ZipEncoder().encodeBytes(archive), id: _ids());

    expect(result.bundle, isNull);
    expect(result.errors, isNotEmpty);
  });

  test('importLooseFiles uses imported slug when none is given', () {
    final result = importLooseFiles({
      'app.json': '{"title":"Land","subtitle":"Map"}',
      'base_layer.json': '{"geo":{"alias":"base"}}',
    }, id: _ids());

    expect(result.bundle, isNotNull);
    expect(result.bundle!.fields['slug'], 'imported');
    expect(result.bundle!.childrenBySlot['app']!.single.fields['title'], 'Land');
  });
}

List<int> _zip(String slug, Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.string('apps/$slug/${entry.key}', entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

String Function() _ids() {
  var next = 0;
  return () => 'id-${next++}';
}
