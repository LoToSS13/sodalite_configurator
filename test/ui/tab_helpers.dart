import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';

Future<void> openEditorTab(WidgetTester tester, EditorSection section) async {
  final tab = find.byKey(Key('editor-tab-${section.name}'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
