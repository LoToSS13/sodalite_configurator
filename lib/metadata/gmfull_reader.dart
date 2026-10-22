import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'metadata_catalog.dart';

final _plainAlias = RegExp(r'^[a-zA-Z_0-9]+$');
final _trailingAlias = RegExp(r'.*[^a-zA-Z_0-9]([a-zA-Z_0-9]+)$');

/// Reads a gmfull snapshot and keeps cards, directories, files, registries
/// and their fields. The rest of the project is discarded as it is parsed.
Future<MetadataCatalog> readGmfull(
  Uint8List bytes, {
  required String fileName,
  void Function(int read, int total)? onProgress,
}) async {
  if (bytes.isEmpty) {
    throw const FormatException('Файл пустой.');
  }
  final headLength = math.min(bytes.length, 512);
  final head = utf8.decode(Uint8List.sublistView(bytes, 0, headLength), allowMalformed: true);
  if (!head.contains('<DiffStore')) {
    throw const FormatException('Это не файл gmfull.');
  }

  final reader = _GmfullReader();
  try {
    await for (final events in _chunks(bytes, onProgress).transform(utf8.decoder).toXmlEvents()) {
      for (final event in events) {
        if (event is XmlStartElementEvent) {
          reader.start(event);
        } else if (event is XmlEndElementEvent && event.localName == 'Entity') {
          reader.finishEntity();
        }
      }
    }
  } on FormatException catch (error) {
    final message = error.message;
    if (message.startsWith('Это ') || message.startsWith('Файл ')) rethrow;
    throw const FormatException('Файл повреждён и не читается как gmfull.');
  } on XmlException {
    throw const FormatException('Файл повреждён и не читается как gmfull.');
  }
  if (reader.entityDepth != 0) {
    throw const FormatException('Файл повреждён и не читается как gmfull.');
  }

  final cards = reader.cards;
  cards.sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));
  return MetadataCatalog(fileName: fileName, importedAt: DateTime.now().toUtc(), cards: cards);
}

Stream<List<int>> _chunks(Uint8List bytes, void Function(int read, int total)? onProgress) async* {
  var start = 0;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    start = 3;
  }
  const size = 1024 * 1024;
  final total = bytes.length;
  while (start < total) {
    final end = math.min(start + size, total);
    yield Uint8List.sublistView(bytes, start, end);
    start = end;
    onProgress?.call(start, total);
    if (start < total) await Future<void>.delayed(Duration.zero);
  }
}

class _GmfullReader {
  final List<MetadataCard> cards = [];
  int entityDepth = 0;
  int skipUntil = -1;
  _Card? card;
  _Field? field;

  void start(XmlStartElementEvent event) {
    if (event.localName != 'Entity') {
      if (event.localName == 'Value' && skipUntil < 0) _value(event);
      return;
    }
    entityDepth++;
    final status = _attr(event, 'Status');
    final type = _attr(event, 'TypeAlias') ?? '';
    final alias = _attr(event, 'Alias') ?? '';
    if (skipUntil < 0) {
      if (status == 'Clear') {
        skipUntil = entityDepth;
      } else if (entityDepth == 1 && metadataCatalogTypes.contains(type)) {
        card = _Card(alias, type);
      } else if (entityDepth == 2 && card != null && type == 'Field') {
        field = _Field(alias);
      } else {
        skipUntil = entityDepth;
      }
    }
    if (event.isSelfClosing) finishEntity();
  }

  void finishEntity() {
    if (skipUntil == entityDepth) {
      skipUntil = -1;
    } else if (field != null && entityDepth == 2) {
      final built = field!.build();
      if (built.alias.isNotEmpty) card!.fields.add(built);
      field = null;
    } else if (card != null && entityDepth == 1) {
      final built = card!.build();
      if (built.alias.isNotEmpty) cards.add(built);
      card = null;
    }
    if (entityDepth > 0) entityDepth--;
  }

  void _value(XmlStartElementEvent event) {
    if (_attr(event, 'Status') == 'Clear') return;
    final attribute = _attr(event, 'Attribute');
    if (attribute == null || attribute.isEmpty) return;
    final text = _attr(event, 'StringValue');
    final reference = _cleanAlias(_attr(event, 'EntityValue'));
    final decimal = _attr(event, 'DecimalValue');
    if (field != null) {
      field!.take(attribute, text, reference, decimal);
    } else if (card != null && entityDepth == 1) {
      card!.take(attribute, text, reference);
    }
  }
}

class _Card {
  _Card(this.alias, this.type);

  final String alias;
  final String type;
  String name = '';
  String? table;
  final List<MetadataField> fields = [];

  void take(String attribute, String? text, String? reference) {
    switch (attribute) {
      case 'NAME':
        name = text?.trim() ?? '';
      case 'PHYSICAL_TABLE_KEY':
        table = reference;
    }
  }

  MetadataCard build() {
    fields.sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));
    return MetadataCard(alias: alias, type: type, name: name, table: table, fields: fields);
  }
}

class _Field {
  _Field(this.alias);

  final String alias;
  String name = '';
  String? column;
  String? domain;
  String? reference;
  String? section;
  bool required = false;
  bool hidden = false;

  void take(String attribute, String? text, String? reference, String? decimal) {
    switch (attribute) {
      case 'NAME':
        name = text?.trim() ?? '';
      case 'COLUMN_KEY':
        column = reference;
      case 'DOMAIN_KEY':
        domain = reference;
      case 'REF_LOGICAL_TABLE_KEY':
        this.reference = reference;
      case 'SECTION_KEY':
        section = reference;
      case 'IS_REQUIRED':
        required = _flag(decimal);
      case 'HIDE':
        hidden = _flag(decimal);
    }
  }

  MetadataField build() => MetadataField(
    alias: alias,
    name: name,
    column: column,
    domain: domain,
    reference: reference,
    section: section,
    required: required,
    hidden: hidden,
  );
}

String? _attr(XmlStartElementEvent event, String key) {
  for (final attribute in event.attributes) {
    if (attribute.localName == key) return attribute.value;
  }
  return null;
}

String? _cleanAlias(String? value) {
  if (value == null || value.isEmpty) return null;
  if (_plainAlias.hasMatch(value)) return value;
  return _trailingAlias.firstMatch(value)?.group(1) ?? value;
}

bool _flag(String? decimal) {
  if (decimal == null) return false;
  return num.tryParse(decimal) == 1;
}
