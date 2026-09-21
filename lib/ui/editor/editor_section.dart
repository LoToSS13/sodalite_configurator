import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
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

bool _has(Node root, String slot) => (root.childrenBySlot[slot] ?? const <Node>[]).isNotEmpty;

Node? _first(Node root, String slot) {
  final children = root.childrenBySlot[slot];
  if (children == null || children.isEmpty) {
    return null;
  }
  return children.first;
}
