import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';

@immutable
class NodeType {
  final String id;
  final String labelRu;
  final List<FieldSpec> fields;
  final List<SlotSpec> slots;

  const NodeType({required this.id, required this.labelRu, this.fields = const [], this.slots = const []});
}
