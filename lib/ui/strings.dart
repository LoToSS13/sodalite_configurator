import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';

abstract final class UiStrings {
  static const createModule = 'Создать модуль';
  static const openZip = 'Открыть zip';
  static const downloadZip = 'Скачать zip';
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
    'name': 'Имя',
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
    return message;
  }
}
