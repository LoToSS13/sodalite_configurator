import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';

abstract final class UiStrings {
  static const createModule = 'Создать модуль';
  static const openZip = 'Открыть zip';
  static const downloadZip = 'Скачать zip';
  static const importFailed = 'Не удалось открыть модуль';
  static const importNotesHeading = 'Предупреждения импорта';
  static const enableObjectCreation = 'Включить создание объектов';
  static const enableSearch = 'Включить поиск';
  static const addAdditionalLayer = '+ дополнительный слой';
  static const jsonPreview = 'JSON';
  static const issuesHeading = 'Замечания';
  static const noIssues = 'Нет замечаний';

  static String issuesCount(int n) => 'Замечания: $n';

  static const Map<String, String> pathLabels = {
    'slug': 'Идентификатор модуля',
    'title': 'Заголовок',
    'subtitle': 'Подзаголовок',
    'alias': 'Псевдоним',
    'paths': 'Пути',
    'titleContent': 'Содержимое заголовка',
    'subtitleContent': 'Содержимое подзаголовка',
    'statusContent': 'Содержимое статуса',
    'additionalTitle': 'Дополнительный заголовок',
    'name': 'Имя',
    'content': 'Содержимое',
    'separator': 'Разделитель',
    'url': 'Ссылка',
    'ifTrue': 'Текст, если истина',
    'ifFalse': 'Текст, если ложь',
    'extensions': 'Расширения файлов',
    'visibilityThreshold': 'Порог видимости',
    'hasMarkers': 'Маркеры',
    'showTagInCluster': 'Тег в кластере',
    'color': 'Цвет',
    'isDashed': 'Пунктир',
    'view': 'Представление',
    'icon': 'Иконка',
    'operator': 'Оператор',
    'property': 'Свойство',
    'value': 'Значение',
    'xsdPath': 'Путь к XSD',
    'app': 'Приложение',
    'baseLayer': 'Базовый слой',
    'additionalLayers': 'Дополнительные слои',
    'objectCreation': 'Создание объектов',
    'search': 'Поиск',
    'geo': 'Геоданные',
    'info': 'Информация',
    'infoSections': 'Разделы информации',
    'fields': 'Поля',
    'images': 'Изображения',
    'attachments': 'Вложения',
    'inspectionView': 'Представление инспекции',
    'actions': 'Действия',
    'tabName': 'Название вкладки',
    'processName': 'Название процесса',
    'objects': 'Объекты инспекции',
    'creation': 'Создание',
    'pathKey': 'Ключ пути',
    'endpoints': 'Конечные точки',
    'tagColor': 'Цвет метки',
    'tagContent': 'Содержимое метки',
    'tagIfTrue': 'Метка, если истина',
    'imagesSource': 'Источник изображений',
    'attachmentsSource': 'Источник вложений',
    'relateToObjectKey': 'Ключ связанного объекта',
    'condition': 'Условие',
    'requireDateWatermark': 'Добавлять дату на изображение',
    'saveToGallery': 'Сохранять в галерею',
    'geometryTypes': 'Типы геометрии',
    'iconPath': 'Путь к иконке',
    'autoMode': 'Автоматический режим',
    'placeholder': 'Подсказка поиска',
    'searchObjects': 'Объекты поиска',
    'objectKeyFieldPath': 'Путь ключа объекта',
    'attribute': 'Атрибут',
    'subtitle1': 'Подзаголовок 1',
    'subtitle2': 'Подзаголовок 2',
    'aopJetAlias': 'Jet-алиас позиции',
    'aopKeyField': 'Ключ позиции',
    'filter': 'Фильтр',
    'criterions': 'Критерии',
    'reason': 'Причина',
    'rawType': 'Неизвестный тип действия',
    'style': 'Стиль',
    'sources': 'Источники',
    'rule': 'Правило',
    'typeId': 'Тип',
  };

  static String pathLabel(String key) => pathLabels[key] ?? key;

  static String issueHeadline(Issue issue, Catalog catalog, Node root) {
    final node = root.find(issue.nodeId);
    var typeLabel = '';
    if (node != null) {
      try {
        typeLabel = catalog.type(node.typeId).labelRu;
      } on StateError {
        typeLabel = node.typeId;
      }
    }
    return '$typeLabel · ${pathLabel(issue.path)}';
  }

  static String issueReason(String message) {
    if (message == 'Required field is missing') {
      return 'Обязательное поле не заполнено';
    }
    if (message == 'Value has the wrong type') {
      return 'Неверный тип значения';
    }
    if (message == 'Required field must not be blank') {
      return 'Поле не должно быть пустым';
    }
    if (message.startsWith('Value must be at least')) {
      return 'Значение слишком маленькое';
    }
    if (message.startsWith('Value must be at most')) {
      return 'Значение слишком большое';
    }
    if (message == 'Value is not in the allowed values') {
      return 'Значение не из списка допустимых';
    }
    if (message == 'Value must be a hexadecimal color') {
      return 'Нужен цвет в формате #RRGGBB';
    }
    if (message == 'Value does not match the required pattern') {
      return 'Значение не соответствует формату';
    }
    if (message == 'Slot has invalid cardinality') {
      return 'Слот заполнен неверно';
    }
    if (message.startsWith('Child type')) {
      return 'Недопустимый тип блока';
    }
    if (message.startsWith('Unknown node type')) {
      return 'Неизвестный тип блока';
    }
    if (message.startsWith('A non-empty view or a rule')) {
      return 'Нужно представление или правило';
    }
    if (message.startsWith('A non-empty value is required')) {
      return 'Нужно непустое значение';
    }
    if (message.startsWith('autoMode is only allowed')) {
      return 'Автоматический режим доступен только для точки';
    }
    if (message.contains('must not contain /')) {
      return 'Атрибут не должен содержать /';
    }
    if (message.startsWith('alternativePositionObject')) {
      return 'Нужны оба поля альтернативной позиции';
    }
    if (message.startsWith('Invalid search filter')) {
      return 'Некорректный фильтр: исправьте или удалите';
    }
    if (message.startsWith('At least one path')) {
      return 'Нужен хотя бы один путь';
    }
    if (message.startsWith('At least one list value')) {
      return 'Нужно хотя бы одно значение списка';
    }
    return message;
  }
}
