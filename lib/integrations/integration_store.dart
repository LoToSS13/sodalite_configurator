import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/integration_store_stub.dart'
    if (dart.library.html) 'package:sodalite_configurator/integrations/integration_store_web.dart'
    as impl;

const integrationStorageKey = 'sodalite-configurator.integrations';

abstract class IntegrationStore {
  IntegrationCatalog read();

  void write(IntegrationCatalog catalog);
}

IntegrationStore createIntegrationStore() => impl.createIntegrationStore();
