import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/app_codec.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

void main() {
  test('encodes app title and subtitle in schema order', () {
    const app = Node(id: 'app', typeId: TypeIds.app, fields: {'title': 'Land', 'subtitle': 'Land objects'});

    expect(encodeApp(app), {'title': 'Land', 'subtitle': 'Land objects'});
    expect(encodeApp(app).keys, ['title', 'subtitle']);
  });

  test('decodes a missing required title as an empty string', () {
    final app = decodeApp({'subtitle': 'Land objects'}, id: 'app');

    expect(app.typeId, TypeIds.app);
    expect(app.fields, {'title': '', 'subtitle': 'Land objects'});
  });

  test('warns about and drops an unknown app key', () {
    final decoded = decodeModule(
      ModuleFiles(
        slug: 'land',
        app: const {'title': 'Land', 'subtitle': 'Objects', 'foo': true},
        baseLayer: const {
          'geo': {'alias': 'land'},
        },
        additionalLayers: const [],
      ),
      id: _ids(),
    );

    expect(decoded.warnings, hasLength(1));
    expect(decoded.warnings.single.file, 'app.json');
    expect(decoded.warnings.single.message, contains('foo'));
    expect(decoded.bundle.childrenBySlot['app']!.single.fields.containsKey('foo'), isFalse);
  });
}

String Function() _ids() {
  var next = 0;
  return () => 'id-${next++}';
}
