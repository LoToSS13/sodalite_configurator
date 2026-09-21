import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/app.dart';

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

  testWidgets('sources slot add menu does not offer app', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    final geo = controller.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    final addSources = find.byKey(Key('slot-add-${geo.id}-sources'));
    await tester.ensureVisible(addSources);
    await tester.tap(addSources);
    await tester.pumpAndSettle();

    final items = tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>));
    expect(items.map((item) => item.value), [TypeIds.geoSource]);
    expect(items.map((item) => item.value), isNot(contains(TypeIds.app)));
  });
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
