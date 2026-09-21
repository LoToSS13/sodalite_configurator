import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:web/web.dart';

DraftStore createDraftStore() => MemoryDraftStore.from(_LocalStorageKvStore());

class _LocalStorageKvStore implements DraftKeyValueStore {
  @override
  String? read(String key) => window.localStorage.getItem(key);

  @override
  void write(String key, String value) => window.localStorage.setItem(key, value);

  @override
  void remove(String key) => window.localStorage.removeItem(key);

  @override
  Iterable<String> keys() {
    final storage = window.localStorage;
    return [for (var index = 0; index < storage.length; index++) storage.key(index)].whereType<String>();
  }
}
