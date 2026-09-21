import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/ui/app.dart';

void main() {
  late DocumentController incompleteController;
  late DocumentController completeController;

  setUp(() {
    incompleteController = _controller();
    completeController = _controller();
    final app = completeController.root.childrenBySlot['app']!.single;
    final geo = completeController.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    completeController.setField(app.id, 'title', 'Land');
    completeController.setField(app.id, 'subtitle', 'Map');
    completeController.setField(geo.id, 'alias', 'land');
  });

  tearDown(() {
    incompleteController.dispose();
    completeController.dispose();
  });

  testWidgets('export button disabled until complete', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(controller: incompleteController, download: _unusedDownload));

    expect(tester.widget<FilledButton>(find.byKey(const Key('exportZip'))).onPressed, isNull);

    await tester.pumpWidget(ConfiguratorApp(controller: completeController, download: _unusedDownload));

    expect(tester.widget<FilledButton>(find.byKey(const Key('exportZip'))).onPressed, isNotNull);
  });

  testWidgets('field labels and issues are in Russian', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(controller: incompleteController, download: _unusedDownload));

    expect(find.text('title'), findsNothing);
    expect(find.text('Заголовок'), findsWidgets);
    expect(find.text('Подзаголовок'), findsOneWidget);
    expect(find.text('Required field is missing'), findsNothing);
    expect(find.text('Приложение · Заголовок'), findsOneWidget);
    expect(find.text('Обязательное поле не заполнено'), findsWidgets);
  });

  testWidgets('invalid integer input drops the model value and blocks export', (tester) async {
    final geo = completeController.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    completeController.setField(geo.id, 'visibilityThreshold', 16);
    expect(completeController.canExport, isTrue);

    await tester.pumpWidget(ConfiguratorApp(controller: completeController, download: _unusedDownload));

    final field = find.byKey(ValueKey('${geo.id}-visibilityThreshold'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'abc');
    await tester.pump();

    final updatedGeo = completeController.root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;
    expect(updatedGeo.fields['visibilityThreshold'], isNot(16));
    expect(completeController.canExport, isFalse);
    expect(tester.widget<FilledButton>(find.byKey(const Key('exportZip'))).onPressed, isNull);
  });
}

DocumentController _controller() {
  var id = 0;
  return DocumentController(
    catalog: Catalog.modulePack(),
    root: newModuleBundle(slug: 'land_v2', id: () => 'node-${id++}'),
  );
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
