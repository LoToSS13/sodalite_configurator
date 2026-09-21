import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/app.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';
import 'package:sodalite_configurator/ui/editor/json_preview.dart';
import 'package:sodalite_configurator/ui/strings.dart';

import 'tab_helpers.dart';

void main() {
  late DocumentController controller;

  setUp(() {
    var id = 0;
    controller = DocumentController(
      catalog: Catalog.modulePack(),
      root: newModuleBundle(slug: 'land_v2', id: () => 'node-${id++}'),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('string map editor can add a path entry', (tester) async {
    final layer = controller.root.childrenBySlot['baseLayer']!.single;
    controller.addChild(parentId: layer.id, slot: 'info', typeId: TypeIds.info);
    final info = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['info']!.single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);

    final add = find.byKey(ValueKey('${info.id}-paths-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();

    await tester.enterText(find.byKey(ValueKey('${info.id}-paths-key-0')), 'Name');
    await tester.enterText(find.byKey(ValueKey('${info.id}-paths-value-0')), 'name');
    await tester.pump();

    expect(info.fields['paths'], isNull);
    expect(
      controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['info']!.single.fields['paths'],
      containsPair('Name', 'name'),
    );
  });

  testWidgets('string list editor can add an extension', (tester) async {
    final layer = controller.root.childrenBySlot['baseLayer']!.single;
    controller.addChild(parentId: layer.id, slot: 'info', typeId: TypeIds.info);
    final info = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['info']!.single;
    controller.addChild(parentId: info.id, slot: 'attachments', typeId: TypeIds.attachmentSection);
    final attachments = controller
        .root
        .childrenBySlot['baseLayer']!
        .single
        .childrenBySlot['info']!
        .single
        .childrenBySlot['attachments']!
        .single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);

    final add = find.byKey(ValueKey('${attachments.id}-extensions-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    await tester.enterText(find.byKey(ValueKey('${attachments.id}-extensions-0')), 'pdf');
    await tester.pump();

    expect(
      controller
          .root
          .childrenBySlot['baseLayer']!
          .single
          .childrenBySlot['info']!
          .single
          .childrenBySlot['attachments']!
          .single
          .fields['extensions'],
      ['pdf'],
    );
  });

  testWidgets('required text fields show an error on the card', (tester) async {
    final app = controller.root.childrenBySlot['app']!.single;
    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    final titleField = find.byKey(ValueKey('${app.id}-title'));
    expect(
      find.descendant(of: titleField, matching: find.text(UiStrings.issueReason('Required field is missing'))),
      findsOneWidget,
    );
  });

  testWidgets('disabling search asks for confirmation', (tester) async {
    controller.enableSearch();
    final search = controller.root.childrenBySlot['search']!.single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.search);

    final remove = find.descendant(of: find.byKey(Key('node-${search.id}')), matching: find.byTooltip('Удалить'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.confirmDisableFeature), findsOneWidget);
    await tester.tap(find.text(UiStrings.cancel));
    await tester.pumpAndSettle();
    expect(controller.root.childrenBySlot['search'], isNotNull);

    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text(UiStrings.confirm));
    await tester.pumpAndSettle();
    expect(controller.root.childrenBySlot['search'], isNull);
  });

  testWidgets('color field shows a swatch', (tester) async {
    final geo = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    controller.addChild(parentId: geo.id, slot: 'style', typeId: TypeIds.geoStyle);

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.baseLayer);

    expect(find.text('точка'), findsNothing);
    final style = controller
        .root
        .childrenBySlot['baseLayer']!
        .single
        .childrenBySlot['geo']!
        .single
        .childrenBySlot['style']!
        .single;
    expect(find.byKey(ValueKey('${style.id}-color-swatch')), findsOneWidget);
  });

  testWidgets('geometry type enum is labeled in Russian', (tester) async {
    controller.enableObjectCreation();
    final creation = controller.root.childrenBySlot['objectCreation']!.single;
    controller.addChild(parentId: creation.id, slot: 'geometryTypes', typeId: TypeIds.geometryType);
    final geometry = controller.root.childrenBySlot['objectCreation']!.single.childrenBySlot['geometryTypes']!.single;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.objectCreation);

    final dropdown = find.byKey(ValueKey('${geometry.id}-type'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    expect(find.text('точка').hitTestable(), findsWidgets);
    expect(find.text('point').hitTestable(), findsNothing);
  });

  testWidgets('narrow viewport stacks the json preview under the form', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    final form = tester.getRect(find.byKey(Key('node-${controller.root.id}')));
    final panel = tester.getRect(find.byType(JsonPreview));
    expect(panel.top, greaterThan(form.top));
  });

  testWidgets('list slot children can be reordered', (tester) async {
    controller.addChild(parentId: controller.root.id, slot: 'additionalLayers', typeId: TypeIds.layer);
    controller.addChild(parentId: controller.root.id, slot: 'additionalLayers', typeId: TypeIds.layer);
    final second = controller.root.childrenBySlot['additionalLayers']!.last;

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));
    await openEditorTab(tester, EditorSection.additionalLayers);

    final moveUp = find.byKey(Key('move-up-${second.id}'));
    await tester.ensureVisible(moveUp);
    await tester.tap(moveUp);
    await tester.pump();

    expect(controller.root.childrenBySlot['additionalLayers']!.first.id, second.id);
  });
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
