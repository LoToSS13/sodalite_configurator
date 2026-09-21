import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/layer_codec.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  const geo = Node(id: 'geo', typeId: 'geo', fields: {'alias': 'land', 'hasMarkers': true, 'showTagInCluster': true});

  test('encodes and decodes inspection tabs with keyed objects and creation', () {
    const layer = Node(
      id: 'layer',
      typeId: 'layer',
      childrenBySlot: {
        'geo': [geo],
        'info': [
          Node(
            id: 'info',
            typeId: 'info',
            fields: {
              'alias': 'parcel',
              'paths': {'Parcel': 'parcel'},
            },
            childrenBySlot: {
              'inspectionView': [
                Node(
                  id: 'tab',
                  typeId: 'inspectionTab',
                  fields: {'tabName': 'Осмотр', 'processName': 'inspection'},
                  childrenBySlot: {
                    'objects': [
                      Node(
                        id: 'object',
                        typeId: 'inspectionObject',
                        fields: {
                          'pathKey': 'Parcel',
                          'endpoints': {'Name': 'name', 'Image': 'photo', 'Files': 'files'},
                          'titleContent': '{Name}',
                          'subtitleContent': 'Объект {Name}',
                          'tagColor': '#123456',
                          'tagContent': '{Name}',
                          'tagIfTrue': 'Да',
                          'imagesSource': 'Image',
                          'attachmentsSource': 'Files',
                          'extensions': ['pdf'],
                        },
                        childrenBySlot: {
                          'fields': [
                            Node(
                              id: 'field',
                              typeId: 'fieldRow',
                              fields: {'name': 'Название', 'content': '{Name}', 'url': '/objects/{Name}'},
                            ),
                          ],
                        },
                      ),
                    ],
                    'creation': [
                      Node(
                        id: 'creation',
                        typeId: 'inspectionCreation',
                        fields: {
                          'title': 'Создать осмотр',
                          'xsdPath': 'xsd/inspection',
                          'relateToObjectKey': 'Parcel',
                          'condition': '{Name}',
                          'requireDateWatermark': true,
                          'saveToGallery': false,
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

    final encoded = encodeLayer(layer);
    final info = encoded['info']! as Map<String, dynamic>;

    expect(info['inspectionView'], [
      {
        'tabName': 'Осмотр',
        'processName': 'inspection',
        'objects': {
          'Parcel': {
            'endpoints': {'Name': 'name', 'Image': 'photo', 'Files': 'files'},
            'title': {'content': '{Name}'},
            'subtitle': {'content': 'Объект {Name}'},
            'tag': {'color': '#123456', 'content': '{Name}', 'ifTrue': 'Да'},
            'fields': [
              {'name': 'Название', 'content': '{Name}', 'url': '/objects/{Name}'},
            ],
            'images': {'source': 'Image'},
            'attachments': {
              'source': 'Files',
              'extensions': ['pdf'],
            },
          },
        },
        'creation': {
          'title': 'Создать осмотр',
          'xsdPath': 'xsd/inspection',
          'relateToObjectKey': 'Parcel',
          'condition': '{Name}',
          'requireDateWatermark': true,
          'saveToGallery': false,
        },
      },
    ]);

    final decoded = decodeLayer(encoded, id: 'decoded', isBase: true);
    final decodedTab = decoded.layer.childrenBySlot['info']!.single.childrenBySlot['inspectionView']!.single;
    final decodedObject = decodedTab.childrenBySlot['objects']!.single;
    final decodedCreation = decodedTab.childrenBySlot['creation']!.single;

    expect(decoded.warnings, isEmpty);
    expect(decodedTab.fields, {'tabName': 'Осмотр', 'processName': 'inspection'});
    expect(
      decodedObject.fields,
      layer
          .childrenBySlot['info']!
          .single
          .childrenBySlot['inspectionView']!
          .single
          .childrenBySlot['objects']!
          .single
          .fields,
    );
    expect(decodedObject.childrenBySlot['fields']!.single.fields, {
      'name': 'Название',
      'content': '{Name}',
      'url': '/objects/{Name}',
    });
    expect(decodedCreation.fields, {
      'title': 'Создать осмотр',
      'xsdPath': 'xsd/inspection',
      'relateToObjectKey': 'Parcel',
      'condition': '{Name}',
      'requireDateWatermark': true,
      'saveToGallery': false,
    });
  });

  test('accepts object placeholders defined by endpoints and a pathKey from info paths', () {
    const info = Node(
      id: 'info',
      typeId: 'info',
      fields: {
        'alias': 'parcel',
        'paths': {'Parcel': 'parcel'},
      },
      childrenBySlot: {
        'inspectionView': [
          Node(
            id: 'tab',
            typeId: 'inspectionTab',
            childrenBySlot: {
              'objects': [
                Node(
                  id: 'object',
                  typeId: 'inspectionObject',
                  fields: {
                    'pathKey': 'Parcel',
                    'endpoints': {'Name': 'name'},
                    'titleContent': '{Name}',
                    'subtitleContent': '{Name}',
                    'tagContent': '{Name}',
                  },
                  childrenBySlot: {
                    'fields': [
                      Node(
                        id: 'field',
                        typeId: 'fieldRow',
                        fields: {'name': 'Name', 'content': '{Name}', 'url': '/{Name}'},
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

    expect(validate(info, Catalog.modulePack()), isEmpty);
  });

  test('rejects empty tabs, unknown path keys, endpoints, and object placeholders', () {
    const info = Node(
      id: 'info',
      typeId: 'info',
      fields: {
        'alias': 'parcel',
        'paths': {'Known': 'known'},
      },
      childrenBySlot: {
        'inspectionView': [
          Node(id: 'empty-tab', typeId: 'inspectionTab'),
          Node(
            id: 'tab',
            typeId: 'inspectionTab',
            childrenBySlot: {
              'objects': [
                Node(
                  id: 'object',
                  typeId: 'inspectionObject',
                  fields: {
                    'pathKey': 'Missing',
                    'endpoints': <String, String>{},
                    'titleContent': '{MissingTitle}',
                    'subtitleContent': '{MissingSubtitle}',
                    'tagContent': '{MissingTag}',
                  },
                  childrenBySlot: {
                    'fields': [
                      Node(
                        id: 'field',
                        typeId: 'fieldRow',
                        fields: {'name': 'Name', 'content': '{MissingContent}', 'url': '/{MissingUrl}'},
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

    final issues = validate(info, Catalog.modulePack());

    expect(issues.where((issue) => issue.nodeId == 'empty-tab').map((issue) => issue.path), contains('objects'));
    expect(
      issues.where((issue) => issue.nodeId == 'object').map((issue) => issue.path),
      containsAll(['pathKey', 'endpoints', 'titleContent', 'subtitleContent', 'tagContent']),
    );
    expect(
      issues.where((issue) => issue.nodeId == 'field').map((issue) => issue.path),
      containsAll(['content', 'url']),
    );
  });

  test('round-trips information and geometry actions', () {
    const layer = Node(
      id: 'layer',
      typeId: 'layer',
      childrenBySlot: {
        'geo': [geo],
        'info': [
          Node(
            id: 'info',
            typeId: 'info',
            fields: {'alias': 'parcel'},
            childrenBySlot: {
              'actions': [
                Node(
                  id: 'information-action',
                  typeId: 'actionInformationChange',
                  fields: {'xsdPath': 'xsd/information'},
                ),
                Node(
                  id: 'geometry-action',
                  typeId: 'actionGeometryChange',
                  fields: {
                    'xsdPath': 'xsd/geometry',
                    'geometryTypes': ['point', 'line', 'polygon'],
                  },
                ),
              ],
            },
          ),
        ],
      },
    );

    final encoded = encodeLayer(layer);
    final info = encoded['info']! as Map<String, dynamic>;
    final decoded = decodeLayer(encoded, id: 'decoded', isBase: true);
    final actions = decoded.layer.childrenBySlot['info']!.single.childrenBySlot['actions']!;

    expect(info['actions'], [
      {'type': 'informationChange', 'xsdPath': 'xsd/information'},
      {
        'type': 'geometryChange',
        'xsdPath': 'xsd/geometry',
        'geometryTypes': ['point', 'line', 'polygon'],
      },
    ]);
    expect(decoded.warnings, isEmpty);
    expect(actions.map((action) => action.typeId), ['actionInformationChange', 'actionGeometryChange']);
    expect(actions.map((action) => action.fields), [
      {'xsdPath': 'xsd/information'},
      {
        'xsdPath': 'xsd/geometry',
        'geometryTypes': ['point', 'line', 'polygon'],
      },
    ]);
  });

  test('rejects missing, empty, and unsupported geometry types', () {
    final catalog = Catalog.modulePack();
    const missing = Node(id: 'missing', typeId: 'actionGeometryChange', fields: {'xsdPath': 'xsd/geometry'});
    const empty = Node(
      id: 'empty',
      typeId: 'actionGeometryChange',
      fields: {'xsdPath': 'xsd/geometry', 'geometryTypes': <String>[]},
    );
    const unsupported = Node(
      id: 'unsupported',
      typeId: 'actionGeometryChange',
      fields: {
        'xsdPath': 'xsd/geometry',
        'geometryTypes': ['circle'],
      },
    );

    expect(validate(missing, catalog).map((issue) => issue.path), contains('geometryTypes'));
    expect(validate(empty, catalog).map((issue) => issue.path), contains('geometryTypes'));
    expect(validate(unsupported, catalog).map((issue) => issue.path), contains('geometryTypes'));
  });

  test('imports an unknown action as an invalid actionUnknown node', () {
    final decoded = decodeLayer(
      {
        'geo': {'alias': 'land'},
        'info': {
          'alias': 'parcel',
          'actions': [
            {'type': 'futureChange', 'xsdPath': 'xsd/future'},
          ],
        },
      },
      id: 'layer',
      isBase: true,
    );
    final action = decoded.layer.childrenBySlot['info']!.single.childrenBySlot['actions']!.single;
    final issues = validate(decoded.layer, Catalog.modulePack());

    expect(action.typeId, 'actionUnknown');
    expect(action.fields['rawType'], 'futureChange');
    expect(
      decoded.warnings.map((warning) => warning.message),
      contains('Unknown action type "futureChange" was imported as an invalid action.'),
    );
    expect(issues.where((issue) => issue.nodeId == action.id && issue.path == 'rawType'), hasLength(1));
  });

  test('catalog exposes real inspection and action types with Russian labels', () {
    final catalog = Catalog.modulePack();
    final info = catalog.type('info');

    expect(info.slots.singleWhere((slot) => slot.key == 'inspectionView').allowedTypeIds, ['inspectionTab']);
    expect(info.slots.singleWhere((slot) => slot.key == 'actions').allowedTypeIds, [
      'actionInformationChange',
      'actionGeometryChange',
      'actionUnknown',
    ]);
    for (final typeId in const [
      'inspectionTab',
      'inspectionObject',
      'inspectionCreation',
      'actionInformationChange',
      'actionGeometryChange',
      'actionUnknown',
    ]) {
      expect(catalog.type(typeId).labelRu, isNotEmpty);
    }
  });
}
