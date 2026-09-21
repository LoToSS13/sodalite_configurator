import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/codec/zip_io.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';

void main() {
  late Catalog catalog;
  late Node initialRoot;
  late DocumentController controller;

  setUp(() {
    var id = 0;
    catalog = Catalog.modulePack();
    initialRoot = newModuleBundle(slug: 'land_v2', id: () => 'node-${id++}');
    controller = DocumentController(catalog: catalog, root: initialRoot);
  });

  tearDown(() {
    controller.dispose();
  });

  test('canExport stays false until all required fields are filled', () {
    final app = controller.root.childrenBySlot['app']!.single;
    final geo = _baseGeo(controller.root);

    expect(controller.canExport, isFalse);

    controller.setField(app.id, 'title', 'Land');
    expect(controller.canExport, isFalse);

    controller.setField(app.id, 'subtitle', 'Map');
    expect(controller.canExport, isFalse);

    controller.setField(geo.id, 'alias', 'land');
    expect(controller.issues, isEmpty);
    expect(controller.canExport, isTrue);
  });

  test('setField copies only the path from root to the changed node', () {
    final oldApp = initialRoot.childrenBySlot['app']!.single;
    final oldLayer = initialRoot.childrenBySlot['baseLayer']!.single;
    final oldGeo = oldLayer.childrenBySlot['geo']!.single;

    controller.setField(oldGeo.id, 'alias', 'land');

    final newLayer = controller.root.childrenBySlot['baseLayer']!.single;
    final newGeo = newLayer.childrenBySlot['geo']!.single;
    expect(controller.root, isNot(same(initialRoot)));
    expect(controller.root.childrenBySlot['app']!.single, same(oldApp));
    expect(newLayer, isNot(same(oldLayer)));
    expect(newGeo, isNot(same(oldGeo)));
    expect(newGeo.fields['alias'], 'land');
  });

  test('addChild rejects a type not allowed by the slot', () {
    final geo = _baseGeo(controller.root);

    expect(() => controller.addChild(parentId: geo.id, slot: 'sources', typeId: TypeIds.app), throwsArgumentError);
  });

  test('additional layer list appends layers with false geo defaults', () {
    controller.addChild(parentId: controller.root.id, slot: 'additionalLayers', typeId: TypeIds.layer);
    controller.addChild(parentId: controller.root.id, slot: 'additionalLayers', typeId: TypeIds.layer);

    final layers = controller.root.childrenBySlot['additionalLayers']!;
    expect(layers, hasLength(2));
    expect(layers.map((layer) => layer.id).toSet(), hasLength(2));
    for (final layer in layers) {
      final geo = layer.childrenBySlot['geo']!.single;
      expect(geo.fields['hasMarkers'], isFalse);
      expect(geo.fields['showTagInCluster'], isFalse);
    }
  });

  test('one and optionalOne slots do not add a second child', () {
    final originalApp = controller.root.childrenBySlot['app']!.single;
    final geo = _baseGeo(controller.root);

    controller.addChild(parentId: controller.root.id, slot: 'app', typeId: TypeIds.app);
    controller.addChild(parentId: geo.id, slot: 'style', typeId: TypeIds.geoStyle);
    final style = _baseGeo(controller.root).childrenBySlot['style']!.single;
    controller.addChild(parentId: geo.id, slot: 'style', typeId: TypeIds.geoStyle);

    expect(controller.root.childrenBySlot['app'], [same(originalApp)]);
    expect(_baseGeo(controller.root).childrenBySlot['style'], [same(style)]);
  });

  test('feature helpers insert one stub and remove it', () {
    controller.enableObjectCreation();
    controller.enableObjectCreation();
    controller.enableSearch();
    controller.enableSearch();

    expect(controller.root.childrenBySlot['objectCreation'], hasLength(1));
    expect(controller.root.childrenBySlot['objectCreation']!.single.typeId, 'objectCreation');
    expect(controller.root.childrenBySlot['search'], hasLength(1));
    expect(controller.root.childrenBySlot['search']!.single.typeId, 'search');

    controller.disableObjectCreation();
    controller.disableSearch();

    expect(controller.root.childrenBySlot['objectCreation'], isNull);
    expect(controller.root.childrenBySlot['search'], isNull);
  });

  test('removeNode removes a child and clears its selection', () {
    controller.enableSearch();
    final search = controller.root.childrenBySlot['search']!.single;
    controller.select(search.id);

    controller.removeNode(search.id);

    expect(controller.root.find(search.id), isNull);
    expect(controller.selectedId, isNull);
  });

  test('exportZip throws while document is incomplete', () {
    expect(controller.exportZip, throwsStateError);
  });

  test('exportZip creates bytes parseable by parseModuleZip', () {
    final app = controller.root.childrenBySlot['app']!.single;
    final geo = _baseGeo(controller.root);
    controller.setField(app.id, 'title', 'Land');
    controller.setField(app.id, 'subtitle', 'Map');
    controller.setField(geo.id, 'alias', 'land');

    final parsed = parseModuleZip(controller.exportZip());

    expect(parsed.files.slug, 'land_v2');
    expect(parsed.files.app, {'title': 'Land', 'subtitle': 'Map'});
    expect(parsed.files.baseLayer['geo'], containsPair('alias', 'land'));
  });

  test('saves drafts after mutations', () async {
    final storage = <String, String>{};
    var id = 0;
    final saving = DocumentController(
      catalog: catalog,
      root: newModuleBundle(slug: 'land_v2', id: () => 'draft-${id++}'),
      drafts: MemoryDraftStore(storage),
      draftDebounce: Duration.zero,
    );
    saving.setField(saving.root.childrenBySlot['app']!.single.id, 'title', 'Land');
    await Future<void>.delayed(Duration.zero);
    expect(storage.keys, ['sodalite-configurator.draft.land_v2']);
    saving.dispose();
  });

  test('moveChild reorders siblings in a list slot', () {
    controller.addChild(parentId: controller.root.id, slot: 'additionalLayers', typeId: TypeIds.layer);
    controller.addChild(parentId: controller.root.id, slot: 'additionalLayers', typeId: TypeIds.layer);
    final first = controller.root.childrenBySlot['additionalLayers']!.first;
    final second = controller.root.childrenBySlot['additionalLayers']!.last;

    controller.moveChild(second.id, offset: -1);

    expect(controller.root.childrenBySlot['additionalLayers']!.map((layer) => layer.id), [second.id, first.id]);
  });

  test('trySetSlug refuses a slug that already has another draft', () async {
    final storage = <String, String>{};
    final drafts = MemoryDraftStore(storage);
    var otherId = 0;
    await drafts.save(newModuleBundle(slug: 'taken', id: () => 'other-${otherId++}'));

    var id = 0;
    final renaming = DocumentController(
      catalog: catalog,
      root: newModuleBundle(slug: 'land_v2', id: () => 'draft-${id++}'),
      drafts: drafts,
      draftDebounce: Duration.zero,
    );

    expect(await renaming.trySetSlug('taken'), isFalse);
    expect(renaming.root.fields['slug'], 'land_v2');
    renaming.dispose();
  });

  test('trySetSlug migrates the draft key', () async {
    final storage = <String, String>{};
    final drafts = MemoryDraftStore(storage);
    var id = 0;
    final renaming = DocumentController(
      catalog: catalog,
      root: newModuleBundle(slug: 'land_v2', id: () => 'draft-${id++}'),
      drafts: drafts,
      draftDebounce: Duration.zero,
    );
    await drafts.save(renaming.root);

    expect(await renaming.trySetSlug('land_v3'), isTrue);
    expect(renaming.root.fields['slug'], 'land_v3');
    expect(await drafts.load('land_v2'), isNull);
    expect(await drafts.load('land_v3'), isNotNull);
    renaming.dispose();
  });
}

Node _baseGeo(Node root) {
  return root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
}
