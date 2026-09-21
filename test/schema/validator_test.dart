import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/node_type.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
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

  test('unknown typeId is an issue', () {
    const node = Node(id: 'unknown-node', typeId: 'missing');

    final issues = validate(node, Catalog.empty());

    expect(issues, hasLength(1));
    expect(issues.single.nodeId, 'unknown-node');
    expect(issues.single.path, 'typeId');
  });

  group('integer bounds', () {
    final integerCatalog = Catalog({
      'bounded': NodeType(
        id: 'bounded',
        labelRu: 'Ограниченное число',
        fields: const [FieldSpec(key: 'count', kind: FieldKind.integer, min: 1, max: 3)],
      ),
    });

    test('integer below min is an issue', () {
      const node = Node(id: 'below-min', typeId: 'bounded', fields: {'count': 0});

      expect(validate(node, integerCatalog).single.path, 'count');
    });

    test('integer above max is an issue', () {
      const node = Node(id: 'above-max', typeId: 'bounded', fields: {'count': 4});

      expect(validate(node, integerCatalog).single.path, 'count');
    });
  });

  test('enumeration value outside enumValues is an issue', () {
    final enumerationCatalog = Catalog({
      'choice': NodeType(
        id: 'choice',
        labelRu: 'Выбор',
        fields: const [
          FieldSpec(key: 'mode', kind: FieldKind.enumeration, enumValues: ['compact', 'full']),
        ],
      ),
    });
    const node = Node(id: 'bad-choice', typeId: 'choice', fields: {'mode': 'other'});

    expect(validate(node, enumerationCatalog).single.path, 'mode');
  });

  test('invalid hexadecimal color is an issue', () {
    final colorCatalog = Catalog({
      'color': NodeType(
        id: 'color',
        labelRu: 'Цвет',
        fields: const [FieldSpec(key: 'accent', kind: FieldKind.color)],
      ),
    });
    const node = Node(id: 'bad-color', typeId: 'color', fields: {'accent': '#12345G'});

    expect(validate(node, colorCatalog).single.path, 'accent');
  });

  test('value that does not match pattern is an issue', () {
    final patternCatalog = Catalog({
      'patterned': NodeType(
        id: 'patterned',
        labelRu: 'Шаблон',
        fields: const [FieldSpec(key: 'code', kind: FieldKind.string, pattern: r'^MOD-\d+$')],
      ),
    });
    const node = Node(id: 'bad-pattern', typeId: 'patterned', fields: {'code': 'OTHER'});

    expect(validate(node, patternCatalog).single.path, 'code');
  });

  group('slot cardinality', () {
    const leafType = NodeType(id: 'leaf', labelRu: 'Лист');

    test('one slot with no child is an issue', () {
      final slotCatalog = Catalog({
        'parent': NodeType(
          id: 'parent',
          labelRu: 'Родитель',
          slots: const [
            SlotSpec(key: 'content', cardinality: SlotCardinality.one, allowedTypeIds: ['leaf']),
          ],
        ),
        'leaf': leafType,
      });
      const node = Node(id: 'parent', typeId: 'parent');

      expect(validate(node, slotCatalog).single.path, 'content');
    });

    test('optionalOne accepts zero or one child', () {
      final slotCatalog = Catalog({
        'parent': NodeType(
          id: 'parent',
          labelRu: 'Родитель',
          slots: const [
            SlotSpec(key: 'content', cardinality: SlotCardinality.optionalOne, allowedTypeIds: ['leaf']),
          ],
        ),
        'leaf': leafType,
      });
      const empty = Node(id: 'empty-parent', typeId: 'parent');
      const filled = Node(
        id: 'filled-parent',
        typeId: 'parent',
        childrenBySlot: {
          'content': [Node(id: 'leaf', typeId: 'leaf')],
        },
      );

      expect(validate(empty, slotCatalog), isEmpty);
      expect(validate(filled, slotCatalog), isEmpty);
    });

    test('optionalOne with two children is an issue', () {
      final slotCatalog = Catalog({
        'parent': NodeType(
          id: 'parent',
          labelRu: 'Родитель',
          slots: const [
            SlotSpec(key: 'content', cardinality: SlotCardinality.optionalOne, allowedTypeIds: ['leaf']),
          ],
        ),
        'leaf': leafType,
      });
      const node = Node(
        id: 'parent',
        typeId: 'parent',
        childrenBySlot: {
          'content': [Node(id: 'leaf-1', typeId: 'leaf'), Node(id: 'leaf-2', typeId: 'leaf')],
        },
      );

      expect(validate(node, slotCatalog).single.path, 'content');
    });

    test('required list with no children is an issue', () {
      final slotCatalog = Catalog({
        'parent': NodeType(
          id: 'parent',
          labelRu: 'Родитель',
          slots: const [
            SlotSpec(key: 'items', cardinality: SlotCardinality.list, allowedTypeIds: ['leaf'], required: true),
          ],
        ),
        'leaf': leafType,
      });
      const node = Node(id: 'parent', typeId: 'parent');

      expect(validate(node, slotCatalog).single.path, 'items');
    });
  });

  test("recursively validates a child node's required field", () {
    final recursiveCatalog = Catalog({
      'parent': NodeType(
        id: 'parent',
        labelRu: 'Родитель',
        slots: const [
          SlotSpec(key: 'content', cardinality: SlotCardinality.one, allowedTypeIds: ['child']),
        ],
      ),
      'child': NodeType(
        id: 'child',
        labelRu: 'Ребёнок',
        fields: const [FieldSpec(key: 'title', kind: FieldKind.nonEmptyString, required: true)],
      ),
    });
    const node = Node(
      id: 'parent',
      typeId: 'parent',
      childrenBySlot: {
        'content': [
          Node(id: 'child', typeId: 'child', fields: {'title': ''}),
        ],
      },
    );

    final issues = validate(node, recursiveCatalog);

    expect(issues, hasLength(1));
    expect(issues.single.nodeId, 'child');
    expect(issues.single.path, 'title');
  });
}
