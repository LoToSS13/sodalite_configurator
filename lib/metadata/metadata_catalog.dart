import 'dart:convert';

const metadataCatalogTypes = {'LogicalTable', 'Directory', 'File', 'LogicalView'};

const metadataTypeTitles = <String, String>{
  'LogicalTable': 'Карточка',
  'Directory': 'Справочник',
  'File': 'Файл',
  'LogicalView': 'Реестр',
};

String metadataTypeTitle(String type) => metadataTypeTitles[type] ?? type;

String metadataCountLabel(int count, {required bool cards}) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final form = mod10 == 1 && mod100 != 11
      ? 0
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 1
      : 2;
  const cardForms = ['карточка', 'карточки', 'карточек'];
  const fieldForms = ['поле', 'поля', 'полей'];
  return '$count ${cards ? cardForms[form] : fieldForms[form]}';
}

class MetadataField {
  const MetadataField({
    required this.alias,
    required this.name,
    this.column,
    this.domain,
    this.reference,
    this.section,
    this.required = false,
    this.hidden = false,
  });

  final String alias;
  final String name;
  final String? column;
  final String? domain;
  final String? reference;
  final String? section;
  final bool required;
  final bool hidden;

  Map<String, Object?> toJson() => _compact({
    'alias': alias,
    'name': name,
    'column': column,
    'domain': domain,
    'reference': reference,
    'section': section,
    'required': required,
    'hidden': hidden,
  });

  static MetadataField decode(Object? json) {
    if (json is! Map) {
      throw const FormatException('Сохранённые метаданные повреждены.');
    }
    return MetadataField(
      alias: json['alias'] as String? ?? '',
      name: json['name'] as String? ?? '',
      column: json['column'] as String?,
      domain: json['domain'] as String?,
      reference: json['reference'] as String?,
      section: json['section'] as String?,
      required: json['required'] == true,
      hidden: json['hidden'] == true,
    );
  }
}

class MetadataCard {
  const MetadataCard({required this.alias, required this.type, required this.name, required this.fields, this.table});

  final String alias;
  final String type;
  final String name;
  final String? table;
  final List<MetadataField> fields;

  Map<String, Object?> toJson() => _compact({
    'alias': alias,
    'type': type,
    'name': name,
    'table': table,
    'fields': [for (final field in fields) field.toJson()],
  });

  static MetadataCard decode(Object? json) {
    if (json is! Map) {
      throw const FormatException('Сохранённые метаданные повреждены.');
    }
    final fields = json['fields'];
    return MetadataCard(
      alias: json['alias'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      table: json['table'] as String?,
      fields: [
        if (fields is List)
          for (final field in fields)
            if (field is Map && (field['alias'] as String? ?? '').isNotEmpty) MetadataField.decode(field),
      ],
    );
  }
}

class MetadataCatalog {
  MetadataCatalog({required this.fileName, required this.importedAt, required List<MetadataCard> cards})
    : cards = List.unmodifiable(cards),
      byAlias = {for (final card in cards) card.alias: card};

  final String fileName;
  final DateTime importedAt;
  final List<MetadataCard> cards;
  final Map<String, MetadataCard> byAlias;

  MetadataCard? card(String alias) => byAlias[alias];

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'cards': [for (final card in cards) card.toJson()],
  };

  static MetadataCatalog decode(String text) {
    final json = jsonDecode(text);
    if (json is! Map) {
      throw const FormatException('Сохранённые метаданные повреждены.');
    }
    final cards = json['cards'];
    final imported = DateTime.tryParse(json['importedAt'] as String? ?? '');
    return MetadataCatalog(
      fileName: json['fileName'] as String? ?? 'gmfull',
      importedAt: imported ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      cards: [
        if (cards is List)
          for (final card in cards)
            if (card is Map && (card['alias'] as String? ?? '').isNotEmpty) MetadataCard.decode(card),
      ],
    );
  }
}

Map<String, Object?> _compact(Map<String, Object?> raw) {
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value == null || value == false) continue;
    if (value is String && value.isEmpty) continue;
    result[entry.key] = value;
  }
  return result;
}
