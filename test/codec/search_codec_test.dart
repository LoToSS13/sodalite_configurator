import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/search_codec.dart';
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

  test('search with zero objects is invalid', () {
    const search = Node(id: 'search', typeId: TypeIds.search);
    expect(validate(search, catalog).any((issue) => issue.path == 'searchObjects'), isTrue);
  });

  test('attribute with a slash is invalid', () {
    const object = Node(
      id: 'object',
      typeId: TypeIds.searchObject,
      fields: {
        'alias': 'Parcel',
        'objectKeyFieldPath': 'KeyField',
        'attribute': 'a/b',
        'paths': {'Name': 'name'},
        'title': 'Parcel',
      },
    );
    expect(validate(object, catalog).any((issue) => issue.path == 'attribute'), isTrue);
  });

  test('zip omits search.json when the feature is off', () {
    final controller = _completeModule();
    addTearDown(controller.dispose);
    final names = ZipDecoder().decodeBytes(controller.exportZip()).files.map((file) => file.name).toSet();
    expect(names.contains('apps/land_v2/search.json'), isFalse);
    expect(encodeModule(controller.root).search, isNull);
  });

  test('filter root must be a group, not a leaf', () {
    final decoded = decodeSearch({
      'searchObjects': [
        {
          'alias': 'Parcel',
          'objectKeyFieldPath': 'KeyField',
          'paths': {'Name': 'name'},
          'attribute': 'Name',
          'resultView': {'title': 'Parcel'},
          'filter': {'operator': 'eq', 'alias': 'Status', 'value': 'active'},
        },
      ],
    }, id: 'search');

    final filter = decoded.node.childrenBySlot['searchObjects']!.single.childrenBySlot['filter']!.single;
    expect(filter.typeId, TypeIds.searchFilterInvalid);
    expect(validate(decoded.node, catalog), isNotEmpty);
  });

  test('rejects Consul leaf that uses Jasper property instead of alias', () {
    final decoded = decodeSearch({
      'searchObjects': [
        {
          'alias': 'Parcel',
          'objectKeyFieldPath': 'KeyField',
          'paths': {'Name': 'name'},
          'attribute': 'Name',
          'resultView': {'title': 'Parcel'},
          'filter': {
            'operator': 'and',
            'criterions': [
              {
                'operator': 'eq',
                'property': {'alias': 'Status', 'type': 'field'},
                'value': 'active',
              },
            ],
          },
        },
      ],
    }, id: 'search');

    final criterion = decoded
        .node
        .childrenBySlot['searchObjects']!
        .single
        .childrenBySlot['filter']!
        .single
        .childrenBySlot['criterions']!
        .single;
    expect(criterion.typeId, TypeIds.searchFilterInvalid);
    expect(decoded.warnings, isNotEmpty);
  });

  test('round-trips and/or groups with eq and in leaves in Consul shape', () {
    const search = Node(
      id: 'search',
      typeId: TypeIds.search,
      fields: {'placeholder': 'Найти'},
      childrenBySlot: {
        'searchObjects': [
          Node(
            id: 'object',
            typeId: TypeIds.searchObject,
            fields: {
              'alias': 'Parcel',
              'objectKeyFieldPath': 'KeyField',
              'attribute': 'Name',
              'paths': {'Name': 'name'},
              'title': 'Parcel {Name}',
              'subtitle1': 'Code',
              'aopJetAlias': 'jet',
              'aopKeyField': 'KeyField',
            },
            childrenBySlot: {
              'filter': [
                Node(
                  id: 'root',
                  typeId: TypeIds.searchFilterGroup,
                  fields: {'operator': 'and'},
                  childrenBySlot: {
                    'criterions': [
                      Node(
                        id: 'eq',
                        typeId: TypeIds.searchFilterScalar,
                        fields: {'operator': 'eq', 'alias': 'Status', 'value': 'active'},
                      ),
                      Node(
                        id: 'or',
                        typeId: TypeIds.searchFilterGroup,
                        fields: {'operator': 'or'},
                        childrenBySlot: {
                          'criterions': [
                            Node(
                              id: 'in',
                              typeId: TypeIds.searchFilterList,
                              fields: {
                                'operator': 'in',
                                'alias': 'Type',
                                'value': ['a', 'b'],
                              },
                            ),
                          ],
                        },
                      ),
                    ],
                  },
                ),
              ],
            },
          ),
        ],
      },
    );

    expect(encodeSearch(search), {
      'placeholder': 'Найти',
      'searchObjects': [
        {
          'alias': 'Parcel',
          'objectKeyFieldPath': 'KeyField',
          'paths': {'Name': 'name'},
          'attribute': 'Name',
          'resultView': {'title': 'Parcel {Name}', 'subtitle1': 'Code'},
          'alternativePositionObject': {'jetAlias': 'jet', 'keyField': 'KeyField'},
          'filter': {
            'operator': 'and',
            'criterions': [
              {'operator': 'eq', 'alias': 'Status', 'value': 'active'},
              {
                'operator': 'or',
                'criterions': [
                  {
                    'operator': 'in',
                    'alias': 'Type',
                    'value': ['a', 'b'],
                  },
                ],
              },
            ],
          },
        },
      ],
    });

    final decoded = decodeSearch(encodeSearch(search), id: 'decoded');
    expect(decoded.warnings, isEmpty);
    expect(validate(decoded.node, catalog), isEmpty);
    expect(encodeSearch(decoded.node), encodeSearch(search));
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
