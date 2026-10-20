import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/integration_store.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';

IntegrationStore createIntegrationStore() => _MemoryIntegrationStore();

class _MemoryIntegrationStore implements IntegrationStore {
  final DraftKeyValueStore _kv = MapDraftKeyValueStore({});

  @override
  IntegrationCatalog read() => IntegrationCatalog.decode(_kv.read(integrationStorageKey));

  @override
  void write(IntegrationCatalog catalog) => _kv.write(integrationStorageKey, catalog.encode());
}
