import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/schema/node.dart';

/// A complete module that shows how paths, `{keys}`, search, and object
/// creation fit together. Search result titles stay plain text.
ModuleFiles exampleModuleFiles() {
  return ModuleFiles(
    slug: 'city_objects',
    app: const {'title': 'Городские объекты', 'subtitle': 'Камеры и опоры'},
    baseLayer: const {
      'geo': {
        'alias': 'cameras',
        'name': 'Cameras',
        'visibilityThreshold': 16,
        'hasMarkers': true,
        'showTagInCluster': true,
        'style': {'color': '#0075FF', 'isDashed': false},
        'sources': [
          {'name': 'Все камеры', 'icon': 'apps/city_objects/camera.svg', 'view': 'cameras_view'},
          {
            'name': 'Только рабочие',
            'rule': {'operator': 'eq', 'property': 'status', 'value': 'active'},
          },
        ],
      },
      'info': {
        'alias': 'camera',
        'paths': {'name': 'name', 'address': 'address', 'Image_Photo': 'photo', 'Attachments_Docs': 'documents'},
        'title': {'content': '{name}'},
        'subtitle': {'content': '{address}'},
        'status': {'content': '{name}'},
        'additionalTitle': 'Паспорт',
        'infoSections': [
          {
            'title': 'Основное',
            'fields': [
              {
                'name': 'Адрес',
                'content': '{address}',
                'separator': ', ',
                'url': '/cameras/{name}',
                'ifTrue': 'Есть',
                'ifFalse': 'Нет',
              },
            ],
          },
        ],
        'images': [
          {
            'title': 'Фото',
            'sources': ['Image_Photo'],
          },
        ],
        'attachments': [
          {
            'title': 'Документы',
            'sources': ['Attachments_Docs'],
            'extensions': ['pdf'],
          },
        ],
        'inspectionView': [
          {
            'tabName': 'Осмотр',
            'processName': 'inspection',
            'objects': {
              'name': {
                'endpoints': {'date': 'date', 'author': 'author', 'Image': 'photo', 'Files': 'files'},
                'title': {'content': '{date}'},
                'subtitle': {'content': '{author}'},
                'tag': {'color': '#40C267', 'content': '{date}', 'ifTrue': 'Пройден'},
                'fields': [
                  {'name': 'Автор', 'content': '{author}'},
                ],
                'images': {'source': 'Image'},
                'attachments': {
                  'source': 'Files',
                  'extensions': ['pdf'],
                },
              },
            },
            'creation': {
              'title': 'Новый осмотр',
              'xsdPath': 'xsd/inspection',
              'relateToObjectKey': 'name',
              'condition': '{name}',
              'requireDateWatermark': true,
              'saveToGallery': false,
            },
          },
        ],
        'actions': [
          {'type': 'informationChange', 'xsdPath': 'xsd/information'},
          {
            'type': 'geometryChange',
            'xsdPath': 'xsd/geometry',
            'geometryTypes': ['point'],
          },
        ],
      },
    },
    additionalLayers: const [
      {
        'geo': {
          'alias': 'poles',
          'name': 'Poles',
          'hasMarkers': false,
          'showTagInCluster': false,
          'sources': [
            {'name': 'Опоры', 'view': 'poles_view'},
          ],
        },
      },
    ],
    objectCreation: const {
      'xsdPath': 'apps/city_objects/create.xsd',
      'geometryTypes': [
        {'type': 'point', 'autoMode': true},
      ],
      'requireDateWatermark': true,
      'saveToGallery': false,
      'style': {'color': '#0075FF', 'iconPath': 'apps/city_objects/camera.svg'},
    },
    search: const {
      'placeholder': 'Найти камеру',
      'searchObjects': [
        {
          'alias': 'camera',
          'objectKeyFieldPath': 'id',
          'paths': {'name': 'name', 'address': 'address'},
          'attribute': 'name',
          'resultView': {'title': 'Камера', 'subtitle1': 'Адрес'},
          'filter': {
            'operator': 'and',
            'criterions': [
              {'operator': 'eq', 'alias': 'status', 'value': 'active'},
            ],
          },
        },
      ],
    },
  );
}

({Node root, List<ImportWarning> warnings}) createExampleModule({String Function()? id}) {
  final decoded = decodeModule(exampleModuleFiles(), id: id ?? newNodeId);
  return (root: decoded.bundle, warnings: decoded.warnings);
}
