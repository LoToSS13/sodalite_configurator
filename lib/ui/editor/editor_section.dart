import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/editor/node_summary.dart';
import 'package:sodalite_configurator/ui/strings.dart';

enum EditorSection { app, baseLayer, additionalLayers, objectCreation, search }

List<EditorSection> visibleEditorSections(Node root) {
  return [
    EditorSection.app,
    EditorSection.baseLayer,
    EditorSection.additionalLayers,
    if (_has(root, 'objectCreation')) EditorSection.objectCreation,
    if (_has(root, 'search')) EditorSection.search,
  ];
}

List<EditorSection> addableEditorSections(Node root) {
  return [
    if (!_has(root, 'objectCreation')) EditorSection.objectCreation,
    if (!_has(root, 'search')) EditorSection.search,
  ];
}

String editorSectionLabel(EditorSection section) {
  return switch (section) {
    EditorSection.app => UiStrings.tabApp,
    EditorSection.baseLayer => UiStrings.tabBaseLayer,
    EditorSection.additionalLayers => UiStrings.tabAdditionalLayers,
    EditorSection.objectCreation => UiStrings.pathLabel('objectCreation'),
    EditorSection.search => UiStrings.pathLabel('search'),
  };
}

String editorSectionFileName(EditorSection section) {
  return switch (section) {
    EditorSection.app => 'app.json',
    EditorSection.baseLayer => 'base_layer.json',
    EditorSection.additionalLayers => 'additional_layers.json',
    EditorSection.objectCreation => 'object_creation.json',
    EditorSection.search => 'search.json',
  };
}

String editorSectionPreviewText(Node root, EditorSection section) {
  final files = encodeModule(root);
  final value = switch (section) {
    EditorSection.app => files.app,
    EditorSection.baseLayer => files.baseLayer,
    EditorSection.additionalLayers => files.additionalLayers,
    EditorSection.objectCreation => files.objectCreation ?? const <String, dynamic>{},
    EditorSection.search => files.search ?? const <String, dynamic>{},
  };
  return encodeJson(value);
}

/// The selected editor node's location in the exported JSON for this section.
List<Object>? editorSectionPreviewPath(Node root, EditorSection section, String? nodeId) {
  if (nodeId == null) return null;
  final route = _nodeRoute(root, nodeId);
  if (route == null || route.isEmpty || route.first.slot != section.name) return null;

  final path = <Object>[if (section == EditorSection.additionalLayers) route.first.index];
  for (final step in route.skip(1)) {
    if (step.slot == 'objects') {
      path.addAll(['objects', step.child.fields['pathKey'] as String? ?? '']);
      continue;
    }
    if (step.slot == 'criterions' && step.child.typeId == TypeIds.searchFilterInvalid) break;
    path.add(step.slot);
    if (!_singleJsonSlots.contains(step.slot)) {
      final siblings = step.parent.childrenBySlot[step.slot] ?? const <Node>[];
      path.add(
        step.slot == 'criterions'
            ? siblings.take(step.index).where((node) => node.typeId != TypeIds.searchFilterInvalid).length
            : step.index,
      );
    }
  }
  return path;
}

const _singleJsonSlots = {'geo', 'info', 'style', 'rule', 'filter', 'creation'};

List<({Node parent, String slot, int index, Node child})>? _nodeRoute(Node node, String nodeId) {
  if (node.id == nodeId) return [];
  for (final entry in node.childrenBySlot.entries) {
    for (var index = 0; index < entry.value.length; index++) {
      final child = entry.value[index];
      final tail = _nodeRoute(child, nodeId);
      if (tail != null) return [(parent: node, slot: entry.key, index: index, child: child), ...tail];
    }
  }
  return null;
}

EditorSection editorSectionOf(Node root, String nodeId) {
  if (root.id == nodeId) {
    return EditorSection.app;
  }
  final app = _first(root, 'app');
  if (app != null && app.find(nodeId) != null) {
    return EditorSection.app;
  }
  final base = _first(root, 'baseLayer');
  if (base != null && base.find(nodeId) != null) {
    return EditorSection.baseLayer;
  }
  for (final layer in root.childrenBySlot['additionalLayers'] ?? const <Node>[]) {
    if (layer.find(nodeId) != null) {
      return EditorSection.additionalLayers;
    }
  }
  final creation = _first(root, 'objectCreation');
  if (creation != null && creation.find(nodeId) != null) {
    return EditorSection.objectCreation;
  }
  final search = _first(root, 'search');
  if (search != null && search.find(nodeId) != null) {
    return EditorSection.search;
  }
  return EditorSection.app;
}

int editorSectionIssueCount(Node root, List<Issue> issues, EditorSection section) {
  return issues.where((issue) => editorSectionOf(root, issue.nodeId) == section).length;
}

String? editorSelectionPath(Node root, EditorSection section, String? nodeId, Catalog catalog) {
  if (nodeId == null) return null;
  final chain = _nodeChain(root, nodeId);
  if (chain == null) return null;
  final nodes = chain.skip(
    section == EditorSection.baseLayer || section == EditorSection.objectCreation || section == EditorSection.search
        ? 2
        : 1,
  );
  final labels = <String>[
    editorSectionLabel(section),
    for (final node in nodes)
      nodeName(node) ?? (node.typeId == TypeIds.app ? UiStrings.appCard : catalog.type(node.typeId).labelRu),
  ];
  return labels.length > 1 ? labels.join(' › ') : null;
}

List<Node>? _nodeChain(Node node, String nodeId) {
  if (node.id == nodeId) return [node];
  for (final children in node.childrenBySlot.values) {
    for (final child in children) {
      final chain = _nodeChain(child, nodeId);
      if (chain != null) return [node, ...chain];
    }
  }
  return null;
}

bool _has(Node root, String slot) => (root.childrenBySlot[slot] ?? const <Node>[]).isNotEmpty;

Node? _first(Node root, String slot) {
  final children = root.childrenBySlot[slot];
  if (children == null || children.isEmpty) {
    return null;
  }
  return children.first;
}
