import 'package:sodalite_configurator/metadata/metadata_store_stub.dart'
    if (dart.library.html) 'package:sodalite_configurator/metadata/metadata_store_web.dart'
    as impl;

abstract class MetadataStore {
  Future<String?> read();

  Future<void> write(String text);

  Future<void> clear();
}

MetadataStore createMetadataStore() => impl.createMetadataStore();
