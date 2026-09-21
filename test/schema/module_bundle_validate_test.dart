import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  test('new module without geo.alias cannot export', () {
    var n = 0;
    final catalog = Catalog.modulePack();
    final doc = newModuleBundle(slug: 'land_v2', id: () => 'id-${n++}');

    final issues = validate(doc, catalog);

    expect(issues.any((issue) => issue.path.endsWith('alias')), isTrue);
  });

  test('new module creates app and base layer geo with marker defaults', () {
    var n = 0;

    final doc = newModuleBundle(slug: 'land_v2', id: () => 'id-${n++}');
    final app = doc.childrenBySlot['app']!.single;
    final layer = doc.childrenBySlot['baseLayer']!.single;
    final geo = layer.childrenBySlot['geo']!.single;

    expect(doc.typeId, TypeIds.moduleBundle);
    expect(doc.fields['slug'], 'land_v2');
    expect(app.typeId, TypeIds.app);
    expect(layer.typeId, TypeIds.layer);
    expect(geo.typeId, TypeIds.geo);
    expect(geo.fields['hasMarkers'], isTrue);
    expect(geo.fields['showTagInCluster'], isTrue);
  });

  test('geo source without view and rule is an issue', () {
    const source = Node(id: 'source', typeId: TypeIds.geoSource, fields: {'view': ''});

    final issues = validate(source, Catalog.modulePack());

    expect(issues.any((issue) => issue.nodeId == 'source' && issue.path == 'view'), isTrue);
  });

  test('geo rule requiring a value rejects a blank value', () {
    const rule = Node(
      id: 'rule',
      typeId: TypeIds.geoRule,
      fields: {'operator': 'eq', 'property': 'status', 'value': '  '},
    );

    final issues = validate(rule, Catalog.modulePack());

    expect(issues.any((issue) => issue.nodeId == 'rule' && issue.path == 'value'), isTrue);
  });

  test('slug Land_Control is invalid', () {
    const node = Node(id: 'm', typeId: TypeIds.moduleBundle, fields: {'slug': 'Land_Control'});

    final issues = validate(node, Catalog.modulePack());

    expect(issues.any((issue) => issue.path == 'slug'), isTrue);
  });
}
