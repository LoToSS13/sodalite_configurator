import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/node_type.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';

class Catalog {
  final Map<String, NodeType> types;

  const Catalog(this.types);

  NodeType type(String id) {
    final nodeType = types[id];
    if (nodeType == null) {
      throw StateError('Unknown node type: $id');
    }
    return nodeType;
  }

  static Catalog empty() => const Catalog({});

  factory Catalog.modulePack() {
    return Catalog({
      TypeIds.moduleBundle: const NodeType(
        id: TypeIds.moduleBundle,
        labelRu: 'Пакет модуля',
        fields: [
          FieldSpec(key: 'slug', kind: FieldKind.nonEmptyString, required: true, pattern: r'^[a-z0-9][a-z0-9_-]*$'),
        ],
        slots: [
          SlotSpec(key: 'app', cardinality: SlotCardinality.one, allowedTypeIds: [TypeIds.app], required: true),
          SlotSpec(key: 'baseLayer', cardinality: SlotCardinality.one, allowedTypeIds: [TypeIds.layer], required: true),
          SlotSpec(key: 'additionalLayers', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.layer]),
          SlotSpec(key: 'objectCreation', cardinality: SlotCardinality.optionalOne, allowedTypeIds: ['objectCreation']),
          SlotSpec(key: 'search', cardinality: SlotCardinality.optionalOne, allowedTypeIds: ['search']),
        ],
      ),
      TypeIds.app: const NodeType(id: TypeIds.app, labelRu: 'Приложение'),
      TypeIds.layer: const NodeType(
        id: TypeIds.layer,
        labelRu: 'Слой',
        slots: [
          SlotSpec(key: 'geo', cardinality: SlotCardinality.one, allowedTypeIds: [TypeIds.geo], required: true),
          SlotSpec(key: 'info', cardinality: SlotCardinality.optionalOne, allowedTypeIds: ['info']),
        ],
      ),
      TypeIds.geo: const NodeType(
        id: TypeIds.geo,
        labelRu: 'Геоданные',
        fields: [
          FieldSpec(key: 'alias', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'name', kind: FieldKind.string),
          FieldSpec(key: 'visibilityThreshold', kind: FieldKind.integer, min: 15, max: 17),
          FieldSpec(key: 'hasMarkers', kind: FieldKind.boolean, required: true, defaultValue: true),
          FieldSpec(key: 'showTagInCluster', kind: FieldKind.boolean, required: true, defaultValue: true),
        ],
        slots: [
          SlotSpec(key: 'style', cardinality: SlotCardinality.optionalOne, allowedTypeIds: [TypeIds.geoStyle]),
          SlotSpec(key: 'sources', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.geoSource]),
        ],
      ),
      TypeIds.geoStyle: const NodeType(
        id: TypeIds.geoStyle,
        labelRu: 'Стиль геоданных',
        fields: [
          FieldSpec(key: 'color', kind: FieldKind.color, required: true),
          FieldSpec(key: 'isDashed', kind: FieldKind.boolean, required: true),
        ],
      ),
      TypeIds.geoSource: const NodeType(
        id: TypeIds.geoSource,
        labelRu: 'Источник геоданных',
        fields: [
          FieldSpec(key: 'name', kind: FieldKind.string),
          FieldSpec(key: 'icon', kind: FieldKind.string),
          FieldSpec(key: 'view', kind: FieldKind.string),
        ],
        slots: [
          SlotSpec(key: 'style', cardinality: SlotCardinality.optionalOne, allowedTypeIds: [TypeIds.geoStyle]),
          SlotSpec(key: 'rule', cardinality: SlotCardinality.optionalOne, allowedTypeIds: [TypeIds.geoRule]),
        ],
      ),
      TypeIds.geoRule: const NodeType(
        id: TypeIds.geoRule,
        labelRu: 'Правило геоданных',
        fields: [
          FieldSpec(
            key: 'operator',
            kind: FieldKind.enumeration,
            required: true,
            enumValues: ['eq', 'noteq', 'isnotnull', 'isnull', 'notin'],
          ),
          FieldSpec(key: 'property', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'value', kind: FieldKind.string),
        ],
      ),
      'info': const NodeType(
        id: 'info',
        labelRu: 'Информация',
        fields: [FieldSpec(key: 'alias', kind: FieldKind.nonEmptyString, required: true)],
      ),
      'objectCreation': const NodeType(
        id: 'objectCreation',
        labelRu: 'Создание объектов',
        fields: [FieldSpec(key: 'xsdPath', kind: FieldKind.nonEmptyString, required: true)],
      ),
      'search': const NodeType(
        id: 'search',
        labelRu: 'Поиск',
        fields: [FieldSpec(key: 'xsdPath', kind: FieldKind.nonEmptyString, required: true)],
      ),
    });
  }
}

Node newModuleBundle({required String slug, required String Function() id}) {
  return Node(
    id: id(),
    typeId: TypeIds.moduleBundle,
    fields: {'slug': slug},
    childrenBySlot: {
      'app': [Node(id: id(), typeId: TypeIds.app)],
      'baseLayer': [
        Node(
          id: id(),
          typeId: TypeIds.layer,
          childrenBySlot: {
            'geo': [
              Node(id: id(), typeId: TypeIds.geo, fields: {'hasMarkers': true, 'showTagInCluster': true}),
            ],
          },
        ),
      ],
    },
  );
}
