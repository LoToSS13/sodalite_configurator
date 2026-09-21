import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  final catalog = Catalog.modulePack();

  test('AOP fields must be both present or both absent', () {
    const object = Node(
      id: 'object',
      typeId: TypeIds.searchObject,
      fields: {
        'alias': 'Parcel',
        'objectKeyFieldPath': 'KeyField',
        'attribute': 'Name',
        'paths': {'Name': 'name'},
        'title': 'Parcel',
        'aopJetAlias': 'jet',
      },
    );
    expect(validate(object, catalog).any((issue) => issue.path == 'aopKeyField'), isTrue);
  });

  test('list criterion requires a non-empty value list', () {
    const node = Node(
      id: 'in',
      typeId: TypeIds.searchFilterList,
      fields: {'operator': 'in', 'alias': 'Type', 'value': <String>[]},
    );
    expect(validate(node, catalog).any((issue) => issue.path == 'value'), isTrue);
  });

  test('empty criterion does not require a value', () {
    const node = Node(id: 'empty', typeId: TypeIds.searchFilterEmpty, fields: {'operator': 'empty', 'alias': 'Name'});
    expect(validate(node, catalog), isEmpty);
  });
}
