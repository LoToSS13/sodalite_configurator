import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/zip_io.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/schema/validator.dart';

class DocumentController extends ChangeNotifier {
  DocumentController({required this.catalog, required Node root}) : _root = root {
    _revalidate();
  }

  final Catalog catalog;

  Node _root;
  String? _selectedId;
  List<Issue> _issues = const [];

  Node get root => _root;
  String? get selectedId => _selectedId;
  List<Issue> get issues => _issues;
  bool get canExport => _issues.isEmpty;

  void select(String? id) {
    if (_selectedId == id) {
      return;
    }
    _selectedId = id;
    notifyListeners();
  }

  void setField(String nodeId, String key, Object? value) {
    final changed = _replaceNode(_root, nodeId, (node) {
      if (node.fields[key] == value && node.fields.containsKey(key)) {
        return node;
      }
      return node.copyWith(fields: {...node.fields, key: value});
    });
    if (changed == null || identical(changed, _root)) {
      return;
    }
    _commit(changed);
  }

  void addChild({required String parentId, required String slot, required String typeId}) {
    final parent = _root.find(parentId);
    if (parent == null) {
      throw ArgumentError.value(parentId, 'parentId', 'Parent node does not exist');
    }

    final slotSpec = catalog.type(parent.typeId).slots.where((candidate) => candidate.key == slot).firstOrNull;
    if (slotSpec == null) {
      throw ArgumentError.value(slot, 'slot', 'Slot does not exist on ${parent.typeId}');
    }
    if (!slotSpec.allowedTypeIds.contains(typeId)) {
      throw ArgumentError.value(typeId, 'typeId', 'Type is not allowed in slot $slot');
    }

    final currentChildren = parent.childrenBySlot[slot] ?? const <Node>[];
    if (slotSpec.cardinality != SlotCardinality.list && currentChildren.isNotEmpty) {
      return;
    }

    final child = _newChild(typeId, isAdditionalLayer: slot == 'additionalLayers' && typeId == TypeIds.layer);
    final changed = _replaceNode(
      _root,
      parentId,
      (node) => node.copyWith(
        childrenBySlot: {
          ...node.childrenBySlot,
          slot: [...currentChildren, child],
        },
      ),
    );
    if (changed != null) {
      _commit(changed);
    }
  }

  void removeNode(String nodeId) {
    if (nodeId == _root.id) {
      return;
    }
    final removed = _root.find(nodeId);
    if (removed == null) {
      return;
    }

    final changed = _removeDescendant(_root, nodeId);
    if (changed == null) {
      return;
    }
    if (_selectedId != null && removed.find(_selectedId!) != null) {
      _selectedId = null;
    }
    _commit(changed);
  }

  void enableObjectCreation() {
    addChild(parentId: _root.id, slot: 'objectCreation', typeId: TypeIds.objectCreation);
  }

  void disableObjectCreation() {
    final children = _root.childrenBySlot['objectCreation'];
    if (children != null && children.isNotEmpty) {
      removeNode(children.first.id);
    }
  }

  void enableSearch() {
    addChild(parentId: _root.id, slot: 'search', typeId: TypeIds.search);
  }

  void disableSearch() {
    final children = _root.childrenBySlot['search'];
    if (children != null && children.isNotEmpty) {
      removeNode(children.first.id);
    }
  }

  List<int> exportZip() {
    if (!canExport) {
      throw StateError('Cannot export a document with validation issues');
    }
    return buildModuleZip(encodeModule(_root));
  }

  Node _newChild(String typeId, {required bool isAdditionalLayer}) {
    if (typeId == TypeIds.layer) {
      return Node(
        id: newNodeId(),
        typeId: TypeIds.layer,
        childrenBySlot: {
          'geo': [
            Node(
              id: newNodeId(),
              typeId: TypeIds.geo,
              fields: {'hasMarkers': !isAdditionalLayer, 'showTagInCluster': !isAdditionalLayer},
            ),
          ],
        },
      );
    }

    final fields = <String, Object?>{
      for (final field in catalog.type(typeId).fields)
        if (field.defaultValue != null) field.key: field.defaultValue,
    };
    return Node(id: newNodeId(), typeId: typeId, fields: fields);
  }

  void _commit(Node root) {
    _root = root;
    _revalidate();
    notifyListeners();
  }

  void _revalidate() {
    _issues = List<Issue>.unmodifiable(validate(_root, catalog));
  }
}

Node? _replaceNode(Node node, String nodeId, Node Function(Node node) replace) {
  if (node.id == nodeId) {
    return replace(node);
  }

  for (final entry in node.childrenBySlot.entries) {
    for (var index = 0; index < entry.value.length; index++) {
      final changedChild = _replaceNode(entry.value[index], nodeId, replace);
      if (changedChild == null) {
        continue;
      }
      if (identical(changedChild, entry.value[index])) {
        return node;
      }
      final changedChildren = [...entry.value]..[index] = changedChild;
      return node.copyWith(childrenBySlot: {...node.childrenBySlot, entry.key: changedChildren});
    }
  }
  return null;
}

Node? _removeDescendant(Node node, String nodeId) {
  for (final entry in node.childrenBySlot.entries) {
    final directIndex = entry.value.indexWhere((child) => child.id == nodeId);
    if (directIndex != -1) {
      final changedChildren = [...entry.value]..removeAt(directIndex);
      final changedSlots = {...node.childrenBySlot};
      if (changedChildren.isEmpty) {
        changedSlots.remove(entry.key);
      } else {
        changedSlots[entry.key] = changedChildren;
      }
      return node.copyWith(childrenBySlot: changedSlots);
    }

    for (var index = 0; index < entry.value.length; index++) {
      final changedChild = _removeDescendant(entry.value[index], nodeId);
      if (changedChild == null) {
        continue;
      }
      final changedChildren = [...entry.value]..[index] = changedChild;
      return node.copyWith(childrenBySlot: {...node.childrenBySlot, entry.key: changedChildren});
    }
  }
  return null;
}
