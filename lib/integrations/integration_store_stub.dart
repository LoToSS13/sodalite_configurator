import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/integration_store.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';

IntegrationStore createIntegrationStore() => _MemoryIntegrationStore();

class _MemoryIntegrationStore implements IntegrationStore {
  final DraftKeyValueStore _kv = MapDraftKeyValueStore({});

  @override
  IntegrationSettings read() => IntegrationSettings.decode(_kv.read(integrationStorageKey));

  @override
  void write(IntegrationSettings settings) => _kv.write(integrationStorageKey, settings.encode());
}
