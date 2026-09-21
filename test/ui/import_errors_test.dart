import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/ui/app.dart';
import 'package:sodalite_configurator/ui/strings.dart';

void main() {
  testWidgets('failed import shows a dialog and stays on home', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(download: _unusedDownload, pickZipBytes: () async => _twoSlugZip()));

    await tester.tap(find.text(UiStrings.openZip));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('one'), findsWidgets);
    expect(find.text(UiStrings.createModule), findsOneWidget);
    expect(find.byKey(const Key('exportZip')), findsNothing);
  });

  testWidgets('import with extra file opens the editor with a warnings banner', (tester) async {
    await tester.pumpWidget(ConfiguratorApp(download: _unusedDownload, pickZipBytes: () async => _zipWithReadme()));

    await tester.tap(find.text(UiStrings.openZip));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('exportZip')), findsOneWidget);
    expect(find.byKey(const Key('importWarningsBanner')), findsOneWidget);
    expect(find.textContaining('readme.txt'), findsOneWidget);
  });

  testWidgets('broken search.json still opens the editor', (tester) async {
    await tester.pumpWidget(
      ConfiguratorApp(download: _unusedDownload, pickZipBytes: () async => _zipWithBrokenSearch()),
    );

    await tester.tap(find.text(UiStrings.openZip));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exportZip')), findsOneWidget);
    expect(find.textContaining('search.json'), findsOneWidget);
    expect(find.textContaining('base'), findsWidgets);
  });

  testWidgets('open json files loads a module', (tester) async {
    await tester.pumpWidget(
      ConfiguratorApp(
        download: _unusedDownload,
        pickJsonFiles: () async => {
          'app.json': '{"title":"Land","subtitle":"Map"}',
          'base_layer.json': '{"geo":{"alias":"base"}}',
        },
      ),
    );

    await tester.tap(find.text(UiStrings.openJson));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exportZip')), findsOneWidget);
    expect(find.text('Land'), findsWidgets);
  });

  testWidgets('create module refuses a slug that already has a draft', (tester) async {
    var id = 0;
    final drafts = MemoryDraftStore({});
    await drafts.save(newModuleBundle(slug: 'taken', id: () => 'taken-${id++}'));

    await tester.pumpWidget(ConfiguratorApp(download: _unusedDownload, drafts: drafts));

    await tester.tap(find.text(UiStrings.createModule));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'taken');
    await tester.pump();

    expect(find.text(UiStrings.slugTaken), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'OK')).onPressed, isNull);
  });
}

List<int> _twoSlugZip() {
  final archive = Archive()
    ..add(ArchiveFile.string('apps/one/app.json', '{"title":"A","subtitle":"S"}'))
    ..add(ArchiveFile.string('apps/two/app.json', '{"title":"B","subtitle":"S"}'));
  return ZipEncoder().encodeBytes(archive);
}

List<int> _zipWithReadme() {
  final archive = Archive()
    ..add(ArchiveFile.string('apps/land/app.json', '{"title":"Land","subtitle":"Map"}'))
    ..add(ArchiveFile.string('apps/land/base_layer.json', '{"geo":{"alias":"base"}}'))
    ..add(ArchiveFile.string('apps/land/additional_layers.json', '[]'))
    ..add(ArchiveFile.string('apps/land/readme.txt', 'notes'));
  return ZipEncoder().encodeBytes(archive);
}

List<int> _zipWithBrokenSearch() {
  final archive = Archive()
    ..add(ArchiveFile.string('apps/land/app.json', '{"title":"Land","subtitle":"Map"}'))
    ..add(ArchiveFile.string('apps/land/base_layer.json', '{"geo":{"alias":"base"}}'))
    ..add(ArchiveFile.string('apps/land/additional_layers.json', '[]'))
    ..add(ArchiveFile.string('apps/land/search.json', '{not-json'));
  return ZipEncoder().encodeBytes(archive);
}

void _unusedDownload({required String filename, required List<int> bytes}) {}
