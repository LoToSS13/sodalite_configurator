import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';

void main() {
  test('editorSectionOf maps nodes to file tabs', () {
    var id = 0;
    final root = newModuleBundle(slug: 'land_v2', id: () => 'node-${id++}');
    final app = root.childrenBySlot['app']!.single;
    final geo = root.childrenBySlot['baseLayer']!.single.childrenBySlot['geo']!.single;

    expect(editorSectionOf(root, root.id), EditorSection.app);
    expect(editorSectionOf(root, app.id), EditorSection.app);
    expect(editorSectionOf(root, geo.id), EditorSection.baseLayer);
  });
}
