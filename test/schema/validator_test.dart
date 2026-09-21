import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/node_type.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  final catalog = Catalog({
    'app': NodeType(
      id: 'app',
      labelRu: 'Карточка модуля',
      fields: const [
        FieldSpec(key: 'title', kind: FieldKind.nonEmptyString, required: true),
        FieldSpec(key: 'subtitle', kind: FieldKind.nonEmptyString, required: true),
      ],
    ),
  });

  test('blank required title is an issue', () {
    const node = Node(id: 'n1', typeId: 'app', fields: {'title': '', 'subtitle': 'x'});
    final issues = validate(node, catalog);
    expect(issues.single.path, 'title');
    expect(issues.single.nodeId, 'n1');
  });

  test('filled required fields produce no issues', () {
    const node = Node(id: 'n1', typeId: 'app', fields: {'title': 'A', 'subtitle': 'B'});
    expect(validate(node, catalog), isEmpty);
  });
}
