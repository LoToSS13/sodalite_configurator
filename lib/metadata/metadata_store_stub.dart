import 'package:sodalite_configurator/metadata/metadata_store.dart';

MetadataStore createMetadataStore() => _MemoryMetadataStore();

class _MemoryMetadataStore implements MetadataStore {
  String? _text;

  @override
  Future<String?> read() async => _text;

  @override
  Future<void> write(String text) async => _text = text;

  @override
  Future<void> clear() async => _text = null;
}
