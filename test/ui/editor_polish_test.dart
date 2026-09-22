import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/app.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/strings.dart';

import 'tab_helpers.dart';

void main() {
  testWidgets('card header shows the alias and can collapse', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final geo = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    controller.setField(geo.id, 'alias', 'parcels');

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);

    expect(find.text('Геоданные · parcels'), findsOneWidget);

    await tester.tap(find.byKey(Key('collapse-${geo.id}')));
    await tester.pump();

    expect(find.byKey(ValueKey('${geo.id}-alias')), findsNothing);

    await tester.tap(find.byKey(Key('collapse-${geo.id}')));
    await tester.pump();
    expect(find.byKey(ValueKey('${geo.id}-alias')), findsOneWidget);
  });

  testWidgets('slug field returns to the saved value when the new slug is taken', (tester) async {
    final drafts = MemoryDraftStore({});
    var other = 0;
    await drafts.save(newModuleBundle(slug: 'taken', id: () => 'other-${other++}'));
    final controller = DocumentController(
      catalog: Catalog.modulePack(),
      root: newModuleBundle(slug: 'land_v2', id: _ids()),
      drafts: drafts,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    final slug = find.byKey(ValueKey('${controller.root.id}-slug'));
    await tester.enterText(slug, 'taken');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.root.fields['slug'], 'land_v2');
    final field = tester.widget<TextFormField>(find.descendant(of: slug, matching: find.byType(TextFormField)));
    expect(field.controller!.text, 'land_v2');
  });

  testWidgets('duplicate map keys stay visible and block a silent overwrite', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final layer = controller.root.childrenBySlot['baseLayer']!.single;
    controller.addChild(parentId: layer.id, slot: 'info', typeId: TypeIds.info);
    final info = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['info']!.single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);

    final add = find.byKey(ValueKey('${info.id}-paths-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
    await tester.enterText(find.byKey(ValueKey('${info.id}-paths-key-0')), 'Name');
    await tester.enterText(find.byKey(ValueKey('${info.id}-paths-key-1')), 'Name');
    await tester.pump();

    expect(find.text(UiStrings.issueReason('Map key is duplicated')), findsWidgets);
    final paths = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['info']!.single.fields['paths'];
    expect(paths, isA<List>());
    expect(controller.canExport, isFalse);
  });

  testWidgets('color palette writes a hex color', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final geo = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    controller.addChild(parentId: geo.id, slot: 'style', typeId: TypeIds.geoStyle);
    final style = controller
        .root
        .childrenBySlot['baseLayer']!
        .single
        .childrenBySlot['geo']!
        .single
        .childrenBySlot['style']!
        .single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);

    final swatch = find.byKey(ValueKey('${style.id}-color-palette-${colorPalette.first}'));
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pump();

    final color = controller
        .root
        .childrenBySlot['baseLayer']!
        .single
        .childrenBySlot['geo']!
        .single
        .childrenBySlot['style']!
        .single
        .fields['color'];
    expect(color, colorPalette.first);
    final field = tester.widget<TextFormField>(
      find.descendant(of: find.byKey(ValueKey('${style.id}-color')), matching: find.byType(TextFormField)),
    );
    expect(field.controller!.text, colorPalette.first);
  });

  testWidgets('copy puts the current file json on the clipboard', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.tap(find.byKey(const Key('copyJson')));
    await tester.pump();

    expect(find.text(UiStrings.copied), findsOneWidget);
    expect(copied, contains('"title"'));
  });

  testWidgets('duplicating a layer keeps the alias and can be undone after delete', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final layer = controller.root.childrenBySlot['baseLayer']!.single;
    final geo = layer.childrenBySlot['geo']!.single;
    controller.setField(geo.id, 'alias', 'base');

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);
    await tester.tap(find.byKey(Key('duplicate-${layer.id}')));
    await tester.pump();

    final copy = controller.root.childrenBySlot['additionalLayers']!.single;
    expect(copy.childrenBySlot['geo']!.single.fields['alias'], 'base');

    await openEditorTab(tester, EditorSection.additionalLayers);
    await tester.tap(find.descendant(of: find.byKey(Key('node-${copy.id}')), matching: find.byTooltip('Удалить')));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(UiStrings.removed), findsOneWidget);
    await tester.tap(find.text(UiStrings.undo));
    await tester.pump();
    expect(controller.root.find(copy.id), isNotNull);
  });

  testWidgets('filter criterion is one row of operator, alias, and value', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.enableSearch();
    final search = controller.root.childrenBySlot['search']!.single;
    controller.addChild(parentId: search.id, slot: 'searchObjects', typeId: TypeIds.searchObject);
    final object = controller.root.childrenBySlot['search']!.single.childrenBySlot['searchObjects']!.single;
    controller.addChild(parentId: object.id, slot: 'filter', typeId: TypeIds.searchFilterGroup);
    final group = controller
        .root
        .childrenBySlot['search']!
        .single
        .childrenBySlot['searchObjects']!
        .single
        .childrenBySlot['filter']!
        .single;
    controller.addFilterCriterion(group.id);
    final criterion = controller
        .root
        .childrenBySlot['search']!
        .single
        .childrenBySlot['searchObjects']!
        .single
        .childrenBySlot['filter']!
        .single
        .childrenBySlot['criterions']!
        .single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.search);

    expect(find.byKey(Key('node-${criterion.id}')), findsNothing);
    final alias = find.byKey(ValueKey('${criterion.id}-filter-alias'));
    await tester.ensureVisible(alias);
    await tester.enterText(alias, 'status');
    await tester.enterText(find.byKey(ValueKey('${criterion.id}-filter-value')), 'open');
    await tester.pump();

    final stored = controller
        .root
        .childrenBySlot['search']!
        .single
        .childrenBySlot['searchObjects']!
        .single
        .childrenBySlot['filter']!
        .single
        .childrenBySlot['criterions']!
        .single;
    expect(stored.fields['operator'], 'eq');
    expect(stored.fields['alias'], 'status');
    expect(stored.fields['value'], 'open');
    expect(find.text('равно'), findsWidgets);
  });

  testWidgets('draft list shows a calendar time instead of a raw timestamp', (tester) async {
    final drafts = MemoryDraftStore({}, clock: () => DateTime.now());
    var id = 0;
    await drafts.save(newModuleBundle(slug: 'land_v2', id: () => 'draft-${id++}'));

    await tester.pumpWidget(ConfiguratorApp(download: _unusedDownload, drafts: drafts));
    await tester.pumpAndSettle();

    expect(find.textContaining('сегодня'), findsOneWidget);
    expect(find.textContaining(':'), findsWidgets);
    expect(find.textContaining('.000'), findsNothing);
  });
}

DocumentController _controller() {
  return DocumentController(
    catalog: Catalog.modulePack(),
    root: newModuleBundle(slug: 'land_v2', id: _ids()),
  );
}

String Function() _ids() {
  var next = 0;
  return () => 'node-${next++}';
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
