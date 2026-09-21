import 'package:flutter/foundation.dart';

enum FieldKind { string, nonEmptyString, boolean, integer, enumeration, color, stringMap, stringList }

@immutable
class FieldSpec {
  final String key;
  final FieldKind kind;
  final bool required;
  final List<String>? enumValues;
  final int? min;
  final int? max;
  final String? pattern;
  final Object? defaultValue;

  const FieldSpec({
    required this.key,
    required this.kind,
    this.required = false,
    this.enumValues,
    this.min,
    this.max,
    this.pattern,
    this.defaultValue,
  });
}
