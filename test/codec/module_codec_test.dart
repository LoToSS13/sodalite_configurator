import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/schema/ids.dart';

void main() {
  test('normalizes one additional layer object to a one-layer list', () {
    final decoded = decodeModule(
      ModuleFiles(
        slug: 'land',
        app: const {'title': 'Land', 'subtitle': 'Objects'},
        baseLayer: const {
          'geo': {'alias': 'base'},
        },
        additionalLayers: const [
          {
            'geo': {'alias': 'additional'},
          },
        ],
      ),
      id: _ids(),
    );

    final layers = decoded.bundle.childrenBySlot['additionalLayers']!;
    final geo = layers.single.childrenBySlot['geo']!.single;

    expect(layers, hasLength(1));
    expect(geo.fields['alias'], 'additional');
    expect(geo.fields['hasMarkers'], isFalse);
    expect(geo.fields['showTagInCluster'], isFalse);
  });

  test('ModuleFiles accepts a single additional layer object', () {
    final files = ModuleFiles(
      slug: 'land',
      app: const {'title': 'Land', 'subtitle': 'Objects'},
      baseLayer: const {
        'geo': {'alias': 'base'},
      },
      additionalLayers: const {
        'geo': {'alias': 'additional'},
      },
    );

    expect(files.additionalLayers, hasLength(1));
  });

  test('encodes module layers with additional layers as an array', () {
    final decoded = decodeModule(
      ModuleFiles(
        slug: 'land',
        app: const {'title': 'Land', 'subtitle': 'Objects'},
        baseLayer: const {
          'geo': {'alias': 'base'},
        },
        additionalLayers: const [
          {
            'geo': {'alias': 'additional'},
          },
        ],
      ),
      id: _ids(),
    );

    final encoded = encodeModule(decoded.bundle);

    expect(encoded.slug, 'land');
    expect(encoded.additionalLayers, hasLength(1));
    expect(encoded.additionalLayers, isA<List<Map<String, dynamic>>>());
  });

  test('pretty prints JSON with two-space indentation', () {
    expect(
      encodeJson({
        'geo': {'alias': 'land'},
      }),
      '{\n  "geo": {\n    "alias": "land"\n  }\n}',
    );
  });

  test('decoded module uses the supplied id generator for document nodes', () {
    final decoded = decodeModule(
      ModuleFiles(
        slug: 'land',
        app: const {'title': 'Land', 'subtitle': 'Objects'},
        baseLayer: const {
          'geo': {'alias': 'base'},
        },
        additionalLayers: const [],
      ),
      id: _ids(),
    );

    expect(decoded.bundle.typeId, TypeIds.moduleBundle);
    expect(decoded.bundle.id, 'id-0');
    expect(decoded.bundle.childrenBySlot['app']!.single.id, 'id-1');
    expect(decoded.bundle.childrenBySlot['baseLayer']!.single.id, 'id-2');
  });
}

String Function() _ids() {
  var next = 0;
  return () => 'id-${next++}';
}
