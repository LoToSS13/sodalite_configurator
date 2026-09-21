import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/object_creation_codec.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  late Catalog catalog;

  setUp(() {
    catalog = Catalog.modulePack();
  });

  test('zip omits object_creation.json when the feature is off', () {
    final controller = _completeModule();
    addTearDown(controller.dispose);

    final names = ZipDecoder().decodeBytes(controller.exportZip()).files.map((file) => file.name).toSet();
    expect(names, {'apps/land_v2/app.json', 'apps/land_v2/base_layer.json', 'apps/land_v2/additional_layers.json'});
    expect(encodeModule(controller.root).objectCreation, isNull);
  });

  test('enabled object creation without xsdPath cannot export', () {
    final controller = _completeModule();
    addTearDown(controller.dispose);

    controller.enableObjectCreation();

    expect(controller.canExport, isFalse);
    expect(controller.issues.any((issue) => issue.path == 'xsdPath'), isTrue);
  });

  test('autoMode is invalid on a line geometry type', () {
    const node = Node(id: 'line', typeId: TypeIds.geometryType, fields: {'type': 'line', 'autoMode': true});

    final issues = validate(node, catalog);
    expect(issues.any((issue) => issue.path == 'autoMode'), isTrue);
  });

  test('encodes and decodes object creation with geometry types and style', () {
    const creation = Node(
      id: 'creation',
      typeId: TypeIds.objectCreation,
      fields: {
        'xsdPath': 'apps/land/create.xsd',
        'requireDateWatermark': true,
        'saveToGallery': false,
        'color': '#112233',
        'iconPath': 'apps/land/a.svg',
      },
      childrenBySlot: {
        'geometryTypes': [
          Node(id: 'point', typeId: TypeIds.geometryType, fields: {'type': 'point', 'autoMode': true}),
          Node(id: 'line', typeId: TypeIds.geometryType, fields: {'type': 'line'}),
        ],
      },
    );

    expect(encodeObjectCreation(creation), {
      'xsdPath': 'apps/land/create.xsd',
      'geometryTypes': [
        {'type': 'point', 'autoMode': true},
        {'type': 'line'},
      ],
      'requireDateWatermark': true,
      'saveToGallery': false,
      'style': {'color': '#112233', 'iconPath': 'apps/land/a.svg'},
    });

    final decoded = decodeObjectCreation(encodeObjectCreation(creation), id: 'decoded');
    expect(decoded.warnings, isEmpty);
    expect(validate(decoded.node, catalog), isEmpty);
    expect(encodeObjectCreation(decoded.node), encodeObjectCreation(creation));
  });

  test('omits empty geometryTypes and empty style', () {
    const creation = Node(
      id: 'creation',
      typeId: TypeIds.objectCreation,
      fields: {'xsdPath': 'create.xsd', 'requireDateWatermark': true, 'saveToGallery': false},
    );

    expect(encodeObjectCreation(creation), {
      'xsdPath': 'create.xsd',
      'requireDateWatermark': true,
      'saveToGallery': false,
    });
  });
}

DocumentController _completeModule() {
  var id = 0;
  final controller = DocumentController(
    catalog: Catalog.modulePack(),
    root: newModuleBundle(slug: 'land_v2', id: () => 'node-${id++}'),
  );
  final app = controller.root.childrenBySlot['app']!.single;
  final geo = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
  controller.setField(app.id, 'title', 'Land');
  controller.setField(app.id, 'subtitle', 'Map');
  controller.setField(geo.id, 'alias', 'land');
  return controller;
}
