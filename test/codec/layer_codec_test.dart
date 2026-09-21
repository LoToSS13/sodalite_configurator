import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/layer_codec.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

void main() {
  test('round-trips geo style and view and rule sources', () {
    const layer = Node(
      id: 'layer',
      typeId: TypeIds.layer,
      childrenBySlot: {
        'geo': [
          Node(
            id: 'geo',
            typeId: TypeIds.geo,
            fields: {
              'alias': 'land',
              'name': 'Land',
              'visibilityThreshold': 16,
              'hasMarkers': true,
              'showTagInCluster': false,
            },
            childrenBySlot: {
              'style': [
                Node(id: 'geo-style', typeId: TypeIds.geoStyle, fields: {'color': '#123456', 'isDashed': true}),
              ],
              'sources': [
                Node(id: 'view-source', typeId: TypeIds.geoSource, fields: {'name': 'By view', 'view': 'land_view'}),
                Node(
                  id: 'rule-source',
                  typeId: TypeIds.geoSource,
                  childrenBySlot: {
                    'rule': [
                      Node(
                        id: 'rule',
                        typeId: TypeIds.geoRule,
                        fields: {'operator': 'eq', 'property': 'kind', 'value': 'parcel'},
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
    final geo = encoded['geo']! as Map<String, dynamic>;
    final decoded = decodeLayer(encoded, id: 'decoded', isBase: true);
    final decodedGeo = decoded.layer.childrenBySlot['geo']!.single;

    expect(geo.keys, ['alias', 'name', 'visibilityThreshold', 'hasMarkers', 'showTagInCluster', 'style', 'sources']);
    expect(decoded.warnings, isEmpty);
    expect(decodedGeo.fields, layer.childrenBySlot['geo']!.single.fields);
    expect(decodedGeo.childrenBySlot['style']!.single.fields, {'color': '#123456', 'isDashed': true});
    expect(decodedGeo.childrenBySlot['sources']![0].fields, {'name': 'By view', 'view': 'land_view'});
    expect(decodedGeo.childrenBySlot['sources']![1].childrenBySlot['rule']!.single.fields, {
      'operator': 'eq',
      'property': 'kind',
      'value': 'parcel',
    });
  });

  test('uses kind-specific marker defaults only when keys are omitted', () {
    final base = decodeLayer(
      {
        'geo': {'alias': 'base'},
      },
      id: 'base',
      isBase: true,
    );
    final additional = decodeLayer(
      {
        'geo': {'alias': 'additional', 'hasMarkers': true, 'showTagInCluster': true},
      },
      id: 'additional',
      isBase: false,
    );

    expect(base.layer.childrenBySlot['geo']!.single.fields['hasMarkers'], isTrue);
    expect(base.layer.childrenBySlot['geo']!.single.fields['showTagInCluster'], isTrue);
    expect(additional.layer.childrenBySlot['geo']!.single.fields['hasMarkers'], isTrue);
    expect(additional.layer.childrenBySlot['geo']!.single.fields['showTagInCluster'], isTrue);
  });

  test('writes an empty value for null-check rules', () {
    const layer = Node(
      id: 'layer',
      typeId: TypeIds.layer,
      childrenBySlot: {
        'geo': [
          Node(
            id: 'geo',
            typeId: TypeIds.geo,
            fields: {'alias': 'land', 'hasMarkers': false, 'showTagInCluster': false},
            childrenBySlot: {
              'sources': [
                Node(
                  id: 'source',
                  typeId: TypeIds.geoSource,
                  childrenBySlot: {
                    'rule': [
                      Node(id: 'rule', typeId: TypeIds.geoRule, fields: {'operator': 'isnull', 'property': 'owner'}),
                    ],
                  },
                ),
              ],
            },
          ),
        ],
      },
    );

    final sources = (encodeLayer(layer)['geo']! as Map<String, dynamic>)['sources']! as List<dynamic>;
    final rule = (sources.single as Map<String, dynamic>)['rule']! as Map<String, dynamic>;

    expect(rule['value'], '');
  });
}
