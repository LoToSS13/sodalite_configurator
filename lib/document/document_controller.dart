import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/codec/zip_io.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/filter_operator.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/schema/validator.dart';

class DocumentController extends ChangeNotifier {
  DocumentController({
    required this.catalog,
    required Node root,
    this.drafts,
    this.draftDebounce = const Duration(milliseconds: 300),
    List<ImportWarning> importWarnings = const [],
    List<String> importErrors = const [],
  }) : _root = root,
       importWarnings = List<ImportWarning>.unmodifiable(importWarnings),
       importErrors = List<String>.unmodifiable(importErrors) {
    _persistedDraftSlug = root.fields['slug'] as String?;
    _revalidate();
  }

  final Catalog catalog;
  final DraftStore? drafts;
  final Duration draftDebounce;
  final List<ImportWarning> importWarnings;
  final List<String> importErrors;

  Node _root;
  String? _selectedId;
  List<Issue> _issues = const [];
  Timer? _draftTimer;
  String? _persistedDraftSlug;
  final List<Node> _undo = [];
  int _undoEpoch = 0;

  Node get root => _root;
  String? get selectedId => _selectedId;
  List<Issue> get issues => _issues;
  bool get canExport => _issues.isEmpty;
  bool get hasImportNotes => importWarnings.isNotEmpty || importErrors.isNotEmpty;
  int get undoEpoch => _undoEpoch;

  void select(String? id) {
    if (_selectedId == id) {
      return;
    }
    _selectedId = id;
    notifyListeners();
  }

  void setField(String nodeId, String key, Object? value, {bool saveDraft = true}) {
    final changed = _replaceNode(_root, nodeId, (node) {
      if (node.fields[key] == value && node.fields.containsKey(key)) {
        return node;
      }
      return node.copyWith(fields: {...node.fields, key: value});
    });
    if (changed == null || identical(changed, _root)) {
      return;
    }
    _commit(changed, saveDraft: saveDraft);
  }

  Future<bool> trySetSlug(String slug) async {
    final trimmed = slug.trim();
    final old = _persistedDraftSlug ?? (_root.fields['slug'] as String? ?? '');
    if (trimmed == old) {
      setField(_root.id, 'slug', trimmed, saveDraft: false);
      return true;
    }
    if (drafts != null) {
      final existing = await drafts!.load(trimmed);
      if (existing != null && existing.id != _root.id) {
        setField(_root.id, 'slug', old, saveDraft: false);
        return false;
      }
    }
    setField(_root.id, 'slug', trimmed, saveDraft: false);
    if (drafts != null) {
      if (old.isNotEmpty) {
        await drafts!.delete(old);
      }
      await drafts!.save(_root);
      _persistedDraftSlug = trimmed;
    }
    return true;
  }

  void moveChild(String nodeId, {required int offset}) {
    if (offset == 0) {
      return;
    }
    final located = _locateChild(_root, nodeId);
    if (located == null) {
      return;
    }
    final nextIndex = located.index + offset;
    final children = located.parent.childrenBySlot[located.slot]!;
    if (nextIndex < 0 || nextIndex >= children.length) {
      return;
    }
    final reordered = [...children];
    final moved = reordered.removeAt(located.index);
    reordered.insert(nextIndex, moved);
    final changed = _replaceNode(
      _root,
      located.parent.id,
      (node) => node.copyWith(childrenBySlot: {...node.childrenBySlot, located.slot: reordered}),
    );
    if (changed != null) {
      _commit(changed);
    }
  }

  void duplicateLayer(String layerId) {
    final layer = _root.find(layerId);
    if (layer == null || layer.typeId != TypeIds.layer) {
      return;
    }
    final copy = _cloneNode(layer);
    final layers = [..._root.childrenBySlot['additionalLayers'] ?? const <Node>[], copy];
    final changed = _replaceNode(
      _root,
      _root.id,
      (node) => node.copyWith(childrenBySlot: {...node.childrenBySlot, 'additionalLayers': layers}),
    );
    if (changed != null) {
      _commit(changed);
    }
  }

  void addFilterCriterion(String parentId, {bool group = false}) {
    final parent = _root.find(parentId);
    if (parent == null || parent.typeId != TypeIds.searchFilterGroup) {
      return;
    }
    final child = group
        ? Node(id: newNodeId(), typeId: TypeIds.searchFilterGroup, fields: const {'operator': 'and'})
        : Node(
            id: newNodeId(),
            typeId: TypeIds.searchFilterScalar,
            fields: const {'operator': 'eq', 'alias': '', 'value': ''},
          );
    final current = parent.childrenBySlot['criterions'] ?? const <Node>[];
    final changed = _replaceNode(
      _root,
      parentId,
      (node) => node.copyWith(
        childrenBySlot: {
          ...node.childrenBySlot,
          'criterions': [...current, child],
        },
      ),
    );
    if (changed != null) {
      _commit(changed);
    }
  }

  void setFilterOperator(String nodeId, String operator) {
    final node = _root.find(nodeId);
    if (node == null) {
      return;
    }
    final nextType = filterTypeForOperator(operator);
    final criterions = node.childrenBySlot['criterions'] ?? const <Node>[];
    if (nextType != TypeIds.searchFilterGroup && criterions.isNotEmpty) {
      _remember();
    }
    final fields = <String, Object?>{'operator': operator};
    if (nextType != TypeIds.searchFilterGroup) {
      final alias = node.fields['alias'];
      fields['alias'] = alias is String ? alias : '';
    }
    if (nextType == TypeIds.searchFilterScalar || nextType == TypeIds.searchFilterList) {
      fields['value'] = _filterValue(node, nextType);
    }
    final changed = _replaceNode(
      _root,
      nodeId,
      (current) => Node(
        id: current.id,
        typeId: nextType,
        fields: fields,
        childrenBySlot: nextType == TypeIds.searchFilterGroup ? current.childrenBySlot : const {},
      ),
    );
    if (changed != null) {
      _commit(changed);
    }
  }

  void undo() {
    if (_undo.isEmpty) {
      return;
    }
    final previous = _undo.removeLast();
    _selectedId = null;
    _commit(previous);
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
    _remember();
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

  void _commit(Node root, {bool saveDraft = true}) {
    _root = root;
    _revalidate();
    if (saveDraft) {
      _scheduleDraftSave();
    }
    notifyListeners();
  }

  void _scheduleDraftSave() {
    if (drafts == null) {
      return;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDebounce, _flushDraft);
  }

  void _flushDraft() {
    _draftTimer?.cancel();
    _draftTimer = null;
    final drafts = this.drafts;
    if (drafts == null) {
      return;
    }
    final slug = _root.fields['slug'] as String? ?? '';
    if (slug.isEmpty) {
      return;
    }
    if (_persistedDraftSlug != null && _persistedDraftSlug != slug) {
      drafts.delete(_persistedDraftSlug!);
    }
    drafts.save(_root);
    _persistedDraftSlug = slug;
  }

  @override
  void dispose() {
    if (_draftTimer != null) {
      _flushDraft();
    }
    super.dispose();
  }

  void _revalidate() {
    _issues = List<Issue>.unmodifiable(validate(_root, catalog));
  }

  void _remember() {
    _undo.add(_root);
    if (_undo.length > 20) {
      _undo.removeAt(0);
    }
    _undoEpoch++;
  }
}

Node _cloneNode(Node node) {
  return Node(
    id: newNodeId(),
    typeId: node.typeId,
    fields: {for (final entry in node.fields.entries) entry.key: _cloneValue(entry.value)},
    childrenBySlot: {
      for (final entry in node.childrenBySlot.entries) entry.key: [for (final child in entry.value) _cloneNode(child)],
    },
  );
}

Object? _cloneValue(Object? value) {
  if (value is Map) {
    return {for (final entry in value.entries) entry.key: _cloneValue(entry.value)};
  }
  if (value is List) {
    return [for (final item in value) _cloneValue(item)];
  }
  return value;
}

Object _filterValue(Node node, String nextType) {
  final current = node.fields['value'];
  if (nextType == TypeIds.searchFilterList) {
    if (current is List) {
      return [
        for (final item in current)
          if (item is String) item,
      ];
    }
    if (current is String && current.trim().isNotEmpty) {
      return [current];
    }
    return <String>[];
  }
  if (current is String) {
    return current;
  }
  if (current is List) {
    for (final item in current) {
      if (item is String) {
        return item;
      }
    }
  }
  return '';
}

({Node parent, String slot, int index})? _locateChild(Node parent, String nodeId) {
  for (final entry in parent.childrenBySlot.entries) {
    final index = entry.value.indexWhere((child) => child.id == nodeId);
    if (index != -1) {
      return (parent: parent, slot: entry.key, index: index);
    }
    for (final child in entry.value) {
      final nested = _locateChild(child, nodeId);
      if (nested != null) {
        return nested;
      }
    }
  }
  return null;
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
