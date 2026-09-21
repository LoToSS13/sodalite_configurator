import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/ui/app.dart';
import 'package:sodalite_configurator/ui/editor/json_preview.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/ui/strings.dart';

void main() {
  testWidgets('json preview has no TextField and does not enable export', (tester) async {
    final controller = DocumentController(
      catalog: Catalog.modulePack(),
      root: newModuleBundle(slug: 'land_v2', id: _ids()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(ConfiguratorApp(controller: controller, download: _unusedDownload));

    expect(tester.widget<FilledButton>(find.byKey(const Key('exportZip'))).onPressed, isNull);
    expect(find.byType(JsonPreview), findsNothing);

    await tester.tap(find.text(UiStrings.jsonPreview));
    await tester.pump();

    expect(find.byType(JsonPreview), findsOneWidget);
    expect(find.descendant(of: find.byType(JsonPreview), matching: find.byType(TextField)), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('exportZip'))).onPressed, isNull);
    expect(find.text(UiStrings.issuesCount(controller.issues.length)), findsOneWidget);
    expect(find.textContaining('"app.json"'), findsOneWidget);
  });
}

String Function() _ids() {
  var next = 0;
  return () => 'node-${next++}';
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
