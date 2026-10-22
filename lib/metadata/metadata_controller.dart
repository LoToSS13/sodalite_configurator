import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/metadata/gmfull_reader.dart';
import 'package:sodalite_configurator/metadata/metadata_catalog.dart';
import 'package:sodalite_configurator/metadata/metadata_store.dart';

class MetadataController extends ChangeNotifier {
  MetadataController({MetadataStore? store}) : _store = store ?? createMetadataStore();

  final MetadataStore _store;
  MetadataCatalog? catalog;
  var busy = false;
  String? error;
  int? bytesRead;
  int? bytesTotal;
  var _disposed = false;

  Future<void> restore() async {
    try {
      final text = await _store.read();
      if (_disposed) return;
      if (text == null || text.isEmpty) return;
      catalog = MetadataCatalog.decode(text);
      error = null;
    } on FormatException {
      catalog = null;
      error = 'Сохранённые метаданные не открылись. Загрузите gmfull ещё раз.';
      try {
        await _store.clear();
      } on FormatException {
        // The broken record can stay until the next successful import.
      }
    }
    _notify();
  }

  Future<void> importFile() async {
    if (busy) return;
    error = null;
    _notify();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gmfull'],
      withData: true,
    );
    if (_disposed || picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      error = 'Не удалось прочитать «${file.name}». Выберите его ещё раз.';
      _notify();
      return;
    }
    await importBytes(file.name, bytes);
  }

  Future<void> importBytes(String fileName, Uint8List bytes) async {
    if (_disposed) return;
    busy = true;
    error = null;
    bytesRead = 0;
    bytesTotal = bytes.length;
    _notify();
    await Future<void>.delayed(Duration.zero);
    try {
      final next = await readGmfull(
        bytes,
        fileName: fileName,
        onProgress: (read, total) {
          bytesRead = read;
          bytesTotal = total;
          _notify();
        },
      );
      if (_disposed) return;
      if (next.cards.isEmpty) {
        error = 'В файле нет карточек, справочников, файлов и реестров.';
      } else {
        try {
          await _store.write(next.encode());
          catalog = next;
          error = null;
        } on FormatException catch (failure) {
          catalog = next;
          error = failure.message;
        }
      }
    } on FormatException catch (failure) {
      error = failure.message;
    } finally {
      busy = false;
      bytesRead = null;
      bytesTotal = null;
      _notify();
    }
  }

  Future<void> clear() async {
    if (busy) return;
    try {
      await _store.clear();
    } on FormatException catch (failure) {
      error = failure.message;
      _notify();
      return;
    }
    if (_disposed) return;
    catalog = null;
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
