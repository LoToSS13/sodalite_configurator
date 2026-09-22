import 'package:sodalite_configurator/schema/ids.dart';

const filterOperatorValues = <String>[
  'eq',
  'noteq',
  'like',
  'notlike',
  'gt',
  'lt',
  'gte',
  'lte',
  'in',
  'notin',
  'empty',
  'notempty',
  'and',
  'or',
];

String filterTypeForOperator(String operator) {
  return switch (operator) {
    'and' || 'or' => TypeIds.searchFilterGroup,
    'in' || 'notin' => TypeIds.searchFilterList,
    'empty' || 'notempty' => TypeIds.searchFilterEmpty,
    _ => TypeIds.searchFilterScalar,
  };
}
