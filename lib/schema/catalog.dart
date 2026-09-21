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
          SlotSpec(
            key: 'objectCreation',
            cardinality: SlotCardinality.optionalOne,
            allowedTypeIds: [TypeIds.objectCreation],
          ),
          SlotSpec(key: 'search', cardinality: SlotCardinality.optionalOne, allowedTypeIds: ['search']),
        ],
      ),
      TypeIds.app: const NodeType(
        id: TypeIds.app,
        labelRu: 'Приложение',
        fields: [
          FieldSpec(key: 'title', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'subtitle', kind: FieldKind.nonEmptyString, required: true),
        ],
      ),
      TypeIds.layer: const NodeType(
        id: TypeIds.layer,
        labelRu: 'Слой',
        slots: [
          SlotSpec(key: 'geo', cardinality: SlotCardinality.one, allowedTypeIds: [TypeIds.geo], required: true),
          SlotSpec(key: 'info', cardinality: SlotCardinality.optionalOne, allowedTypeIds: [TypeIds.info]),
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
      TypeIds.info: const NodeType(
        id: TypeIds.info,
        labelRu: 'Информация',
        fields: [
          FieldSpec(key: 'alias', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'paths', kind: FieldKind.stringMap),
          FieldSpec(key: 'titleContent', kind: FieldKind.string),
          FieldSpec(key: 'subtitleContent', kind: FieldKind.string),
          FieldSpec(key: 'statusContent', kind: FieldKind.string),
          FieldSpec(key: 'additionalTitle', kind: FieldKind.string),
        ],
        slots: [
          SlotSpec(key: 'infoSections', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.infoSection]),
          SlotSpec(key: 'images', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.imageSection]),
          SlotSpec(key: 'attachments', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.attachmentSection]),
          SlotSpec(key: 'inspectionView', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.inspectionTab]),
          SlotSpec(
            key: 'actions',
            cardinality: SlotCardinality.list,
            allowedTypeIds: [TypeIds.actionInformationChange, TypeIds.actionGeometryChange, TypeIds.actionUnknown],
          ),
        ],
      ),
      TypeIds.infoSection: const NodeType(
        id: TypeIds.infoSection,
        labelRu: 'Раздел информации',
        fields: [FieldSpec(key: 'title', kind: FieldKind.string)],
        slots: [
          SlotSpec(
            key: 'fields',
            cardinality: SlotCardinality.list,
            allowedTypeIds: [TypeIds.fieldRow],
            required: true,
          ),
        ],
      ),
      TypeIds.fieldRow: const NodeType(
        id: TypeIds.fieldRow,
        labelRu: 'Строка поля',
        fields: [
          FieldSpec(key: 'name', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'content', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'separator', kind: FieldKind.string),
          FieldSpec(key: 'url', kind: FieldKind.string),
          FieldSpec(key: 'ifTrue', kind: FieldKind.string),
          FieldSpec(key: 'ifFalse', kind: FieldKind.string),
        ],
      ),
      TypeIds.imageSection: const NodeType(
        id: TypeIds.imageSection,
        labelRu: 'Изображения',
        fields: [
          FieldSpec(key: 'title', kind: FieldKind.string),
          FieldSpec(key: 'sources', kind: FieldKind.stringList, required: true),
        ],
      ),
      TypeIds.attachmentSection: const NodeType(
        id: TypeIds.attachmentSection,
        labelRu: 'Вложения',
        fields: [
          FieldSpec(key: 'title', kind: FieldKind.string),
          FieldSpec(key: 'sources', kind: FieldKind.stringList, required: true),
          FieldSpec(key: 'extensions', kind: FieldKind.stringList),
        ],
      ),
      TypeIds.inspectionTab: const NodeType(
        id: TypeIds.inspectionTab,
        labelRu: 'Вкладка инспекции',
        fields: [
          FieldSpec(key: 'tabName', kind: FieldKind.string),
          FieldSpec(key: 'processName', kind: FieldKind.string),
        ],
        slots: [
          SlotSpec(
            key: 'objects',
            cardinality: SlotCardinality.list,
            allowedTypeIds: [TypeIds.inspectionObject],
            required: true,
          ),
          SlotSpec(
            key: 'creation',
            cardinality: SlotCardinality.optionalOne,
            allowedTypeIds: [TypeIds.inspectionCreation],
          ),
        ],
      ),
      TypeIds.inspectionObject: const NodeType(
        id: TypeIds.inspectionObject,
        labelRu: 'Объект инспекции',
        fields: [
          FieldSpec(key: 'pathKey', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'endpoints', kind: FieldKind.stringMap, required: true),
          FieldSpec(key: 'titleContent', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'subtitleContent', kind: FieldKind.string),
          FieldSpec(key: 'tagColor', kind: FieldKind.color),
          FieldSpec(key: 'tagContent', kind: FieldKind.string),
          FieldSpec(key: 'tagIfTrue', kind: FieldKind.string),
          FieldSpec(key: 'imagesSource', kind: FieldKind.string),
          FieldSpec(key: 'attachmentsSource', kind: FieldKind.string),
          FieldSpec(key: 'extensions', kind: FieldKind.stringList),
        ],
        slots: [
          SlotSpec(key: 'fields', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.fieldRow]),
        ],
      ),
      TypeIds.inspectionCreation: const NodeType(
        id: TypeIds.inspectionCreation,
        labelRu: 'Создание при инспекции',
        fields: [
          FieldSpec(key: 'title', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'xsdPath', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'relateToObjectKey', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'condition', kind: FieldKind.string),
          FieldSpec(key: 'requireDateWatermark', kind: FieldKind.boolean, required: true, defaultValue: true),
          FieldSpec(key: 'saveToGallery', kind: FieldKind.boolean, required: true, defaultValue: false),
        ],
      ),
      TypeIds.actionInformationChange: const NodeType(
        id: TypeIds.actionInformationChange,
        labelRu: 'Изменение информации',
        fields: [FieldSpec(key: 'xsdPath', kind: FieldKind.nonEmptyString, required: true)],
      ),
      TypeIds.actionGeometryChange: const NodeType(
        id: TypeIds.actionGeometryChange,
        labelRu: 'Изменение геометрии',
        fields: [
          FieldSpec(key: 'xsdPath', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'geometryTypes', kind: FieldKind.stringList, required: true),
        ],
      ),
      TypeIds.actionUnknown: const NodeType(
        id: TypeIds.actionUnknown,
        labelRu: 'Неизвестное действие',
        fields: [FieldSpec(key: 'rawType', kind: FieldKind.string, required: true)],
      ),
      TypeIds.objectCreation: const NodeType(
        id: TypeIds.objectCreation,
        labelRu: 'Создание объектов',
        fields: [
          FieldSpec(key: 'xsdPath', kind: FieldKind.nonEmptyString, required: true),
          FieldSpec(key: 'requireDateWatermark', kind: FieldKind.boolean, required: true, defaultValue: true),
          FieldSpec(key: 'saveToGallery', kind: FieldKind.boolean, required: true, defaultValue: false),
          FieldSpec(key: 'color', kind: FieldKind.color),
          FieldSpec(key: 'iconPath', kind: FieldKind.string),
        ],
        slots: [
          SlotSpec(key: 'geometryTypes', cardinality: SlotCardinality.list, allowedTypeIds: [TypeIds.geometryType]),
        ],
      ),
      TypeIds.geometryType: const NodeType(
        id: TypeIds.geometryType,
        labelRu: 'Тип геометрии',
        fields: [
          FieldSpec(key: 'type', kind: FieldKind.enumeration, required: true, enumValues: ['point', 'line', 'polygon']),
          FieldSpec(key: 'autoMode', kind: FieldKind.boolean, defaultValue: false),
        ],
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
