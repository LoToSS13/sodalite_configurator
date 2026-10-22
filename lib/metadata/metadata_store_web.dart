import 'dart:async';
import 'dart:js_interop';

import 'package:sodalite_configurator/metadata/metadata_store.dart';
import 'package:web/web.dart';

const _databaseName = 'sodalite-configurator.metadata';
const _storeName = 'catalog';
const _recordKey = 'current';

MetadataStore createMetadataStore() => _IndexedDbMetadataStore();

class _IndexedDbMetadataStore implements MetadataStore {
  IDBDatabase? _db;

  Future<IDBDatabase> _database() async {
    final existing = _db;
    if (existing != null) return existing;
    final request = window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((Event _) {
      final db = request.result as IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;
    final db = await _asDatabase(request);
    _db = db;
    return db;
  }

  @override
  Future<String?> read() async {
    final db = await _database();
    final tx = db.transaction(_storeName.toJS, 'readonly');
    final result = await _request(tx.objectStore(_storeName).get(_recordKey.toJS));
    if (result == null || result.isUndefinedOrNull) return null;
    if (result.isA<JSString>()) return (result as JSString).toDart;
    return null;
  }

  @override
  Future<void> write(String text) async {
    final db = await _database();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    await _request(tx.objectStore(_storeName).put(text.toJS, _recordKey.toJS));
    await _done(tx);
  }

  @override
  Future<void> clear() async {
    final db = await _database();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    await _request(tx.objectStore(_storeName).delete(_recordKey.toJS));
    await _done(tx);
  }
}

Future<IDBDatabase> _asDatabase(IDBOpenDBRequest request) async {
  final result = await _request(request);
  return result as IDBDatabase;
}

Future<JSAny?> _request(IDBRequest request) {
  final done = Completer<JSAny?>();
  request.onsuccess = ((Event _) {
    if (!done.isCompleted) done.complete(request.result);
  }).toJS;
  request.onerror = ((Event _) {
    if (!done.isCompleted) {
      final message = request.error?.message;
      done.completeError(
        FormatException(message == null || message.isEmpty ? 'Не удалось обратиться к хранилищу метаданных.' : message),
      );
    }
  }).toJS;
  return done.future;
}

Future<void> _done(IDBTransaction transaction) {
  final done = Completer<void>();
  transaction.oncomplete = ((Event _) {
    if (!done.isCompleted) done.complete();
  }).toJS;
  transaction.onabort = ((Event _) {
    if (!done.isCompleted) {
      done.completeError(const FormatException('Не удалось сохранить метаданные в браузере.'));
    }
  }).toJS;
  transaction.onerror = ((Event _) {
    if (!done.isCompleted) {
      done.completeError(const FormatException('Не удалось сохранить метаданные в браузере.'));
    }
  }).toJS;
  return done.future;
}
