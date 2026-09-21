import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/layer_codec.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  const geo = Node(
    id: 'geo',
    typeId: TypeIds.geo,
    fields: {'alias': 'land', 'hasMarkers': true, 'showTagInCluster': true},
  );

  test('round-trips info titles, sections, and media in canonical key order', () {
    const layer = Node(
      id: 'layer',
      typeId: TypeIds.layer,
      childrenBySlot: {
        'geo': [geo],
        'info': [
          Node(
            id: 'info',
            typeId: TypeIds.info,
            fields: {
              'alias': 'parcel',
              'paths': {'Name': 'name', 'Image_Main': 'photo', 'Attachments_Docs': 'documents'},
              'titleContent': '{Name}',
              'subtitleContent': 'Details',
              'statusContent': '{Name}',
              'additionalTitle': 'Extra',
            },
            childrenBySlot: {
              'infoSections': [
                Node(
                  id: 'section',
                  typeId: TypeIds.infoSection,
                  fields: {'title': 'General'},
                  childrenBySlot: {
                    'fields': [
                      Node(
                        id: 'field',
                        typeId: TypeIds.fieldRow,
                        fields: {
                          'name': 'Owner',
                          'content': '{Name}',
                          'separator': ', ',
                          'url': '/owners/{Name}',
                          'ifTrue': 'Yes',
                          'ifFalse': 'No',
                        },
                      ),
                    ],
                  },
                ),
              ],
              'images': [
                Node(
                  id: 'images',
                  typeId: TypeIds.imageSection,
                  fields: {
                    'title': 'Photos',
                    'sources': ['Image_Main'],
                  },
                ),
              ],
              'attachments': [
                Node(
                  id: 'attachments',
                  typeId: TypeIds.attachmentSection,
                  fields: {
                    'title': 'Files',
                    'sources': ['Attachments_Docs'],
                    'extensions': ['pdf', 'docx'],
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
    final decodedInfo = decoded.layer.childrenBySlot['info']!.single;

    expect(info.keys, [
      'alias',
      'paths',
      'title',
      'subtitle',
      'status',
      'additionalTitle',
      'infoSections',
      'images',
      'attachments',
    ]);
    expect(info['title'], {'content': '{Name}'});
    expect((info['infoSections'] as List).single, {
      'title': 'General',
      'fields': [
        {
          'name': 'Owner',
          'content': '{Name}',
          'separator': ', ',
          'url': '/owners/{Name}',
          'ifTrue': 'Yes',
          'ifFalse': 'No',
        },
      ],
    });
    expect(decoded.warnings, isEmpty);
    expect(decodedInfo.fields, layer.childrenBySlot['info']!.single.fields);
    expect(decodedInfo.childrenBySlot['infoSections']!.single.fields, {'title': 'General'});
    expect(decodedInfo.childrenBySlot['infoSections']!.single.childrenBySlot['fields']!.single.fields, {
      'name': 'Owner',
      'content': '{Name}',
      'separator': ', ',
      'url': '/owners/{Name}',
      'ifTrue': 'Yes',
      'ifFalse': 'No',
    });
    expect(decodedInfo.childrenBySlot['images']!.single.fields, {
      'title': 'Photos',
      'sources': ['Image_Main'],
    });
    expect(decodedInfo.childrenBySlot['attachments']!.single.fields, {
      'title': 'Files',
      'sources': ['Attachments_Docs'],
      'extensions': ['pdf', 'docx'],
    });
  });

  test('omits paths, empty title, root fields, and empty slots', () {
    const layer = Node(
      id: 'layer',
      typeId: TypeIds.layer,
      childrenBySlot: {
        'geo': [geo],
        'info': [
          Node(
            id: 'info',
            typeId: TypeIds.info,
            fields: {'alias': 'parcel', 'paths': <String, String>{}, 'titleContent': ''},
            childrenBySlot: {'infoSections': [], 'images': [], 'attachments': [], 'inspectionView': [], 'actions': []},
          ),
        ],
      },
    );

    final info = encodeLayer(layer)['info']! as Map<String, dynamic>;

    expect(info, {'alias': 'parcel'});
    expect(info.containsKey('fields'), isFalse);
  });

  test('converts legacy root fields and drops preview and acceptance with warnings', () {
    final decoded = decodeLayer(
      {
        'geo': {'alias': 'land'},
        'info': {
          'alias': 'parcel',
          'fields': [
            {'name': 'Owner', 'content': '{Name}'},
          ],
          'preview': {'content': 'old'},
          'acceptance': {'content': 'old'},
        },
      },
      id: 'layer',
      isBase: true,
    );

    final info = decoded.layer.childrenBySlot['info']!.single;
    final section = info.childrenBySlot['infoSections']!.single;

    expect(section.typeId, TypeIds.infoSection);
    expect(section.fields['title'], '');
    expect(section.childrenBySlot['fields']!.single.fields, {'name': 'Owner', 'content': '{Name}'});
    expect(decoded.warnings.map((warning) => warning.message), contains('legacy fields converted'));
    expect(decoded.warnings.map((warning) => warning.message), contains('preview dropped'));
    expect(decoded.warnings.map((warning) => warning.message), contains('acceptance dropped'));
  });

  test('drops non-list legacy fields without creating a section', () {
    for (final invalidFields in <Object?>[null, <String, Object?>{}]) {
      final decoded = decodeLayer(
        {
          'geo': {'alias': 'land'},
          'info': {'alias': 'parcel', 'fields': invalidFields},
        },
        id: 'layer',
        isBase: true,
      );

      final info = decoded.layer.childrenBySlot['info']!.single;
      final messages = decoded.warnings.map((warning) => warning.message);

      expect(info.childrenBySlot.containsKey('infoSections'), isFalse);
      expect(messages, isNot(contains('legacy fields converted')));
      expect(messages, contains('legacy fields dropped: expected a list'));
    }
  });

  test('warns and blocks export when media collections have wrong types', () {
    final decoded = decodeLayer(
      {
        'geo': {'alias': 'land'},
        'info': {'alias': 'parcel', 'images': <String, Object?>{}, 'attachments': 'invalid'},
      },
      id: 'layer',
      isBase: true,
    );

    final info = decoded.layer.childrenBySlot['info']!.single;
    final messages = decoded.warnings.map((warning) => warning.message);
    final issues = validate(decoded.layer, Catalog.modulePack());

    expect(info.childrenBySlot.containsKey('images'), isFalse);
    expect(info.childrenBySlot.containsKey('attachments'), isFalse);
    expect(messages, contains('images dropped: expected a list'));
    expect(messages, contains('attachments dropped: expected a list'));
    expect(
      issues.where((issue) => issue.nodeId == info.id).map((issue) => issue.path),
      containsAll(['images', 'attachments']),
    );
  });

  test('catalog registers info fields, sections, media, and future slots', () {
    final catalog = Catalog.modulePack();
    final info = catalog.type(TypeIds.info);

    expect(info.fields.map((field) => field.key), [
      'alias',
      'paths',
      'titleContent',
      'subtitleContent',
      'statusContent',
      'additionalTitle',
    ]);
    expect(info.slots.map((slot) => slot.key), ['infoSections', 'images', 'attachments', 'inspectionView', 'actions']);
    expect(catalog.type(TypeIds.infoSection).slots.single.required, isTrue);
    expect(catalog.type(TypeIds.imageSection).fields.singleWhere((field) => field.key == 'sources').required, isTrue);
  });

  test('validates placeholders against info paths', () {
    const info = Node(
      id: 'info',
      typeId: TypeIds.info,
      fields: {
        'alias': 'parcel',
        'paths': {'Known': 'known'},
        'titleContent': '{MissingTitle}',
        'subtitleContent': '{MissingSubtitle}',
        'statusContent': '{MissingStatus}',
      },
      childrenBySlot: {
        'infoSections': [
          Node(
            id: 'section',
            typeId: TypeIds.infoSection,
            fields: {'title': ''},
            childrenBySlot: {
              'fields': [
                Node(
                  id: 'field',
                  typeId: TypeIds.fieldRow,
                  fields: {'name': 'Test', 'content': '{MissingContent}', 'url': '/{MissingUrl}'},
                ),
              ],
            },
          ),
        ],
      },
    );

    final issues = validate(info, Catalog.modulePack());

    expect(issues.map((issue) => issue.path), containsAll(['titleContent', 'subtitleContent', 'statusContent']));
    expect(
      issues.where((issue) => issue.nodeId == 'field').map((issue) => issue.path),
      containsAll(['content', 'url']),
    );
  });

  test('validates media source prefixes, path keys, and extension tokens', () {
    const info = Node(
      id: 'info',
      typeId: TypeIds.info,
      fields: {
        'alias': 'parcel',
        'paths': {'Plain': 'plain', 'Image_Main': 'photo', 'Attachments_Docs': 'documents'},
      },
      childrenBySlot: {
        'images': [
          Node(
            id: 'images',
            typeId: TypeIds.imageSection,
            fields: {
              'sources': ['Plain', 'MissingImage'],
            },
          ),
        ],
        'attachments': [
          Node(
            id: 'attachments',
            typeId: TypeIds.attachmentSection,
            fields: {
              'sources': ['Image_Main', 'MissingAttachment'],
              'extensions': ['pdf', '   '],
            },
          ),
        ],
      },
    );

    final issues = validate(info, Catalog.modulePack());

    expect(issues.where((issue) => issue.nodeId == 'images' && issue.path == 'sources'), hasLength(2));
    expect(issues.where((issue) => issue.nodeId == 'attachments' && issue.path == 'sources'), hasLength(2));
    expect(issues.where((issue) => issue.nodeId == 'attachments' && issue.path == 'extensions'), hasLength(1));
  });
}
