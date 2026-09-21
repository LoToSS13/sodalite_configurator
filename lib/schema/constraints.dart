import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/placeholders.dart';

List<Issue> extraConstraints(Node node, Catalog catalog) {
  switch (node.typeId) {
    case TypeIds.geoSource:
      final view = node.fields['view'];
      final hasView = view is String && view.trim().isNotEmpty;
      final hasRule = (node.childrenBySlot['rule'] ?? const <Node>[]).any((child) => child.typeId == TypeIds.geoRule);
      if (!hasView && !hasRule) {
        return [Issue(nodeId: node.id, path: 'view', message: 'A non-empty view or a rule child is required')];
      }
    case TypeIds.geoRule:
      final operator = node.fields['operator'];
      if (operator == 'eq' || operator == 'noteq' || operator == 'notin') {
        final value = node.fields['value'];
        if (value is! String || value.trim().isEmpty) {
          return [Issue(nodeId: node.id, path: 'value', message: 'A non-empty value is required for $operator')];
        }
      }
    case TypeIds.info:
      return _validateInfo(node);
    case TypeIds.imageSection:
      return _validateNonEmptySources(node);
    case TypeIds.attachmentSection:
      return [..._validateNonEmptySources(node), ..._validateExtensions(node)];
  }

  return const [];
}

List<Issue> _validateInfo(Node info) {
  final issues = <Issue>[];
  final paths = info.fields['paths'];
  final pathKeys = paths is Map ? paths.keys.whereType<String>().toSet() : const <String>{};

  final invalidMediaCollections = info.fields['_invalidMediaCollections'];
  if (invalidMediaCollections is List) {
    for (final collection in invalidMediaCollections.whereType<String>()) {
      issues.add(
        Issue(
          nodeId: info.id,
          path: collection,
          message: 'Imported media collection had the wrong type and was dropped',
        ),
      );
    }
  }

  for (final key in const ['titleContent', 'subtitleContent', 'statusContent']) {
    _validatePlaceholders(info, key, pathKeys, issues);
  }

  for (final section in info.childrenBySlot['infoSections'] ?? const <Node>[]) {
    for (final field in section.childrenBySlot['fields'] ?? const <Node>[]) {
      _validatePlaceholders(field, 'content', pathKeys, issues);
      _validatePlaceholders(field, 'url', pathKeys, issues);
    }
  }

  for (final images in info.childrenBySlot['images'] ?? const <Node>[]) {
    _validateMediaSources(images, pathKeys, 'Image_', issues);
  }
  for (final attachments in info.childrenBySlot['attachments'] ?? const <Node>[]) {
    _validateMediaSources(attachments, pathKeys, 'Attachments_', issues);
  }

  return issues;
}

void _validatePlaceholders(Node node, String field, Set<String> pathKeys, List<Issue> issues) {
  final value = node.fields[field];
  if (value is! String) {
    return;
  }
  for (final placeholder in extractPlaceholders(value).toSet()) {
    if (!pathKeys.contains(placeholder)) {
      issues.add(
        Issue(nodeId: node.id, path: field, message: 'Placeholder "$placeholder" is not defined in info.paths'),
      );
    }
  }
}

void _validateMediaSources(Node node, Set<String> pathKeys, String prefix, List<Issue> issues) {
  final sources = node.fields['sources'];
  if (sources is! List) {
    return;
  }
  for (final source in sources.whereType<String>()) {
    if (!pathKeys.contains(source) || !source.startsWith(prefix)) {
      issues.add(
        Issue(
          nodeId: node.id,
          path: 'sources',
          message: 'Source "$source" must be an info.paths key starting with $prefix',
        ),
      );
    }
  }
}

List<Issue> _validateNonEmptySources(Node node) {
  final sources = node.fields['sources'];
  if (sources is List && sources.isEmpty) {
    return [Issue(nodeId: node.id, path: 'sources', message: 'At least one source is required')];
  }
  return const [];
}

List<Issue> _validateExtensions(Node node) {
  final extensions = node.fields['extensions'];
  if (extensions is! List) {
    return const [];
  }
  return [
    for (final extension in extensions.whereType<String>())
      if (extension.trim().toLowerCase().isEmpty)
        Issue(nodeId: node.id, path: 'extensions', message: 'Extension must not be empty'),
  ];
}
