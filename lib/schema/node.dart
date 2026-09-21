import 'package:flutter/foundation.dart';

@immutable
class Node {
  final String id;
  final String typeId;
  final Map<String, Object?> fields;
  final Map<String, List<Node>> childrenBySlot;

  const Node({required this.id, required this.typeId, this.fields = const {}, this.childrenBySlot = const {}});

  Node copyWith({Map<String, Object?>? fields, Map<String, List<Node>>? childrenBySlot}) {
    return Node(
      id: id,
      typeId: typeId,
      fields: fields ?? this.fields,
      childrenBySlot: childrenBySlot ?? this.childrenBySlot,
    );
  }

  Node? find(String nodeId) {
    if (id == nodeId) {
      return this;
    }

    for (final children in childrenBySlot.values) {
      for (final child in children) {
        final match = child.find(nodeId);
        if (match != null) {
          return match;
        }
      }
    }

    return null;
  }
}

int _nodeIdCounter = 0;

String newNodeId() => '${DateTime.now().microsecondsSinceEpoch}-${_nodeIdCounter++}';
