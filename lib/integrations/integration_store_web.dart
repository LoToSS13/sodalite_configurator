import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/integration_store.dart';
import 'package:web/web.dart';

IntegrationStore createIntegrationStore() => _LocalIntegrationStore();

class _LocalIntegrationStore implements IntegrationStore {
  @override
  IntegrationCatalog read() => IntegrationCatalog.decode(window.localStorage.getItem(integrationStorageKey));

  @override
  void write(IntegrationCatalog catalog) {
    window.localStorage.setItem(integrationStorageKey, catalog.encode());
  }
}
