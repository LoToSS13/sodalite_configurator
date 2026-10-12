import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/ids.dart';

abstract final class UiStrings {
  static const appCard = 'Карточка модуля';
  static const createModule = 'Создать модуль';
  static const openZip = 'Открыть ZIP';
  static const openJson = 'Открыть JSON';
  static const downloadZip = 'Скачать ZIP';
  static const importFailed = 'Не удалось открыть модуль';
  static const importNotesHeading = 'Проверьте данные после импорта';
  static const enableObjectCreation = 'Включить создание объектов';
  static const enableSearch = 'Включить поиск';
  static const confirmDisableFeature = 'Удалить раздел?';
  static const confirmDisableFeatureBody =
      'Раздел и\u00a0его настройки будут удалены из\u00a0модуля. Сразу после удаления их\u00a0можно вернуть';
  static const cancel = 'Отмена';
  static const confirm = 'Удалить раздел';
  static const addEntry = 'Добавить путь';
  static const addValue = 'Добавить значение';
  static const slugTaken = 'Черновик с таким идентификатором уже есть';
  static const moveUp = 'Переместить выше';
  static const moveDown = 'Переместить ниже';
  static const addAdditionalLayer = 'Добавить слой';
  static const addFile = 'Добавить раздел';
  static const copyJson = 'Копировать';
  static const copied = 'JSON скопирован';
  static const duplicateLayer = 'Дублировать слой';
  static const undo = 'Вернуть';
  static const removed = 'Блок удалён';
  static const collapse = 'Свернуть';
  static const expand = 'Развернуть';
  static const addCriterion = 'Добавить критерий';
  static const addFilterGroup = 'Добавить группу';
  static const tabApp = 'О модуле';
  static const tabBaseLayer = 'Базовый слой';
  static const tabAdditionalLayers = 'Дополнительные слои';
  static const jsonPreview = 'JSON';
  static const draftsHeading = 'Черновики';
  static const deleteDraft = 'Удалить';
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
    'info': 'Карточка объекта',
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
    'type': 'Тип геометрии',
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
    'style': 'Оформление',
    'sources': 'Источники',
    'rule': 'Правило',
    'typeId': 'Тип',
  };

  static String pathLabel(String key) => pathLabels[key] ?? key;

  static const Map<String, String> enumLabels = {
    'eq': 'равно',
    'noteq': 'не равно',
    'like': 'содержит',
    'notlike': 'не содержит',
    'gt': 'больше',
    'lt': 'меньше',
    'gte': 'не меньше',
    'lte': 'не больше',
    'in': 'в списке',
    'notin': 'не в списке',
    'empty': 'пусто',
    'notempty': 'не пусто',
    'and': 'и',
    'or': 'или',
    'isnull': 'пусто',
    'isnotnull': 'не пусто',
    'point': 'точка',
    'line': 'линия',
    'polygon': 'полигон',
  };

  static String enumLabel(String value) => enumLabels[value] ?? value;

  static String issueHeadline(Issue issue, Catalog catalog, Node root) {
    final node = root.find(issue.nodeId);
    var typeLabel = '';
    if (node != null) {
      try {
        typeLabel = node.typeId == TypeIds.app ? appCard : catalog.type(node.typeId).labelRu;
      } on StateError {
        typeLabel = node.typeId;
      }
    }
    return '$typeLabel · ${pathLabel(issue.path)}';
  }

  static String issueReason(String message) {
    if (message == 'Required field is missing') {
      return 'Заполните обязательное поле';
    }
    if (message == 'Value has the wrong type') {
      return 'Неверный тип значения';
    }
    if (message == 'Required field must not be blank') {
      return 'Заполните обязательное поле';
    }
    if (message.startsWith('Value must be at least')) {
      return 'Минимальное значение — ${message.split(' ').last}';
    }
    if (message.startsWith('Value must be at most')) {
      return 'Максимальное значение — ${message.split(' ').last}';
    }
    if (message == 'Value is not in the allowed values') {
      return 'Выберите значение из\u00a0списка';
    }
    if (message == 'Value must be a hexadecimal color') {
      return 'Укажите цвет в\u00a0формате #RRGGBB или\u00a0#RRGGBBAA';
    }
    if (message == 'Value does not match the required pattern') {
      return 'Значение не соответствует формату';
    }
    if (message == 'Slot has invalid cardinality') {
      return 'Проверьте количество блоков в\u00a0этом разделе';
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
    if (message == 'Map key must not be blank') {
      return 'Ключ не может быть пустым';
    }
    if (message == 'Map key is duplicated') {
      return 'Такой ключ уже есть';
    }
    return message;
  }
}
