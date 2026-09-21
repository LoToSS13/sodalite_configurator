import 'package:sodalite_configurator/persistence/draft_store.dart';

DraftStore createDraftStore() => MemoryDraftStore(<String, String>{});
