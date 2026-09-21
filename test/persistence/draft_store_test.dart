import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

void main() {
  late Map<String, String> storage;
  late DraftStore store;

  setUp(() {
    storage = <String, String>{};
    store = MemoryDraftStore(storage, clock: () => DateTime.utc(2026, 9, 21, 12));
  });

  test('save/load round-trips the internal tree, not Consul JSON', () async {
    const root = Node(
      id: 'bundle',
      typeId: TypeIds.moduleBundle,
      fields: {'slug': 'land_v2'},
      childrenBySlot: {
        'app': [
          Node(id: 'app', typeId: TypeIds.app, fields: {'title': 'Земля', 'subtitle': 'Карта'}),
        ],
      },
    );

    await store.save(root);
    final loaded = await store.load('land_v2');

    expect(loaded, isNotNull);
    expect(loaded!.id, 'bundle');
    expect(loaded.typeId, TypeIds.moduleBundle);
    expect(loaded.fields['slug'], 'land_v2');
    expect(loaded.childrenBySlot['app']!.single.fields['title'], 'Земля');
    expect(storage.keys.single, 'sodalite-configurator.draft.land_v2');
    expect(storage.values.single, contains('"typeId"'));
    expect(storage.values.single, contains('"childrenBySlot"'));
    expect(storage.values.single, contains('"fields"'));

    final listed = await store.list();
    expect(listed, hasLength(1));
    expect(listed.single.slug, 'land_v2');
    expect(listed.single.title, 'Земля');
    expect(listed.single.updatedAt, DateTime.utc(2026, 9, 21, 12));
  });

  test('corrupt load returns null', () async {
    storage['sodalite-configurator.draft.broken'] = '{not-json';
    expect(await store.load('broken'), isNull);

    storage['sodalite-configurator.draft.also'] = '{"updatedAt":"2026-01-01T00:00:00.000Z","tree":[]}';
    expect(await store.load('also'), isNull);

    final listed = await store.list();
    expect(listed, isEmpty);
  });

  test('delete removes a draft', () async {
    await store.save(const Node(id: 'b', typeId: TypeIds.moduleBundle, fields: {'slug': 'land'}));
    await store.delete('land');
    expect(await store.load('land'), isNull);
    expect(await store.list(), isEmpty);
  });
}
