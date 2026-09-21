import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/ui/app.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';
import 'package:sodalite_configurator/ui/strings.dart';

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

  testWidgets('default tabs are the required files plus add', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    expect(find.byKey(Key('editor-tab-${EditorSection.app.name}')), findsOneWidget);
    expect(find.byKey(Key('editor-tab-${EditorSection.baseLayer.name}')), findsOneWidget);
    expect(find.byKey(Key('editor-tab-${EditorSection.additionalLayers.name}')), findsOneWidget);
    expect(find.byKey(Key('editor-tab-${EditorSection.search.name}')), findsNothing);
    expect(find.byKey(const Key('add-file-tab')), findsOneWidget);
    expect(find.text('app.json'), findsOneWidget);
  });

  testWidgets('plus tab adds search and then disables when nothing remains', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    await tester.tap(find.byKey(const Key('add-file-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(UiStrings.pathLabel('search')));
    await tester.pumpAndSettle();

    expect(controller.root.childrenBySlot['search'], isNotNull);
    expect(find.byKey(Key('editor-tab-${EditorSection.search.name}')), findsOneWidget);
    expect(find.text('search.json'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-file-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(UiStrings.pathLabel('objectCreation')));
    await tester.pumpAndSettle();

    expect(controller.root.childrenBySlot['objectCreation'], isNotNull);
    expect(tester.widget<PopupMenuButton<EditorSection>>(find.byKey(const Key('add-file-tab'))).enabled, isFalse);
  });
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
