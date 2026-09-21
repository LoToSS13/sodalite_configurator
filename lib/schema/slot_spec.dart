import 'package:flutter/foundation.dart';

enum SlotCardinality { one, optionalOne, list }

@immutable
class SlotSpec {
  final String key;
  final SlotCardinality cardinality;
  final List<String> allowedTypeIds;
  final bool required;

  const SlotSpec({required this.key, required this.cardinality, required this.allowedTypeIds, this.required = false});
}
