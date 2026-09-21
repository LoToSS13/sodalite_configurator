import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/persistence/draft_store_stub.dart'
    if (dart.library.html) 'package:sodalite_configurator/persistence/draft_store_web.dart'
    as impl;
import 'package:sodalite_configurator/schema/node.dart';

const draftKeyPrefix = 'sodalite-configurator.draft.';

DraftStore createDraftStore() => impl.createDraftStore();

String draftStorageKey(String slug) => '$draftKeyPrefix$slug';

@immutable
class DraftMeta {
  final String slug;
  final String title;
  final DateTime updatedAt;

  const DraftMeta({required this.slug, required this.title, required this.updatedAt});
}

abstract class DraftStore {
  Future<void> save(Node root);
  Future<Node?> load(String slug);
  Future<List<DraftMeta>> list();
  Future<void> delete(String slug);
}

abstract class DraftKeyValueStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
  Iterable<String> keys();
}

class MapDraftKeyValueStore implements DraftKeyValueStore {
  MapDraftKeyValueStore(this.map);

  final Map<String, String> map;

  @override
  String? read(String key) => map[key];

  @override
  void write(String key, String value) => map[key] = value;

  @override
  void remove(String key) => map.remove(key);

  @override
  Iterable<String> keys() => map.keys;
}

class MemoryDraftStore implements DraftStore {
  MemoryDraftStore(Map<String, String> storage, {DateTime Function()? clock})
    : this.from(MapDraftKeyValueStore(storage), clock: clock);

  MemoryDraftStore.from(this._kv, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DraftKeyValueStore _kv;
  final DateTime Function() _clock;

  @override
  Future<void> save(Node root) async {
    final slug = root.fields['slug'];
    if (slug is! String || slug.isEmpty) {
      return;
    }
    _kv.write(draftStorageKey(slug), encodeDraftDocument(root, _clock().toUtc()));
  }

  @override
  Future<Node?> load(String slug) async {
    return decodeDraftDocument(_kv.read(draftStorageKey(slug)))?.tree;
  }

  @override
  Future<List<DraftMeta>> list() async {
    final drafts = <DraftMeta>[];
    for (final key in _kv.keys()) {
      if (!key.startsWith(draftKeyPrefix)) {
        continue;
      }
      final decoded = decodeDraftDocument(_kv.read(key));
      if (decoded == null) {
        continue;
      }
      drafts.add(
        DraftMeta(
          slug: key.substring(draftKeyPrefix.length),
          title: _titleOf(decoded.tree),
          updatedAt: decoded.updatedAt,
        ),
      );
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<void> delete(String slug) async {
    _kv.remove(draftStorageKey(slug));
  }
}

String encodeDraftDocument(Node root, DateTime updatedAt) {
  return jsonEncode({'updatedAt': updatedAt.toUtc().toIso8601String(), 'tree': nodeToJson(root)});
}

({Node tree, DateTime updatedAt})? decodeDraftDocument(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final json = jsonDecode(raw);
    if (json is! Map) {
      return null;
    }
    final tree = nodeFromJson(json['tree']);
    final updatedAt = DateTime.parse(json['updatedAt'] as String).toUtc();
    if (tree == null) {
      return null;
    }
    return (tree: tree, updatedAt: updatedAt);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> nodeToJson(Node node) {
  return {
    'id': node.id,
    'typeId': node.typeId,
    'fields': node.fields,
    'childrenBySlot': {
      for (final entry in node.childrenBySlot.entries) entry.key: [for (final child in entry.value) nodeToJson(child)],
    },
  };
}

Node? nodeFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  final map = Map<String, dynamic>.from(json);
  final id = map['id'];
  final typeId = map['typeId'];
  if (id is! String || typeId is! String) {
    return null;
  }
  return Node(
    id: id,
    typeId: typeId,
    fields: _decodeFields(map['fields']),
    childrenBySlot: _decodeChildren(map['childrenBySlot']),
  );
}

Map<String, Object?> _decodeFields(Object? json) {
  if (json is! Map) {
    return const {};
  }
  return {
    for (final entry in json.entries)
      if (entry.key is String) entry.key as String: _decodeValue(entry.value),
  };
}

Map<String, List<Node>> _decodeChildren(Object? json) {
  if (json is! Map) {
    return const {};
  }
  final children = <String, List<Node>>{};
  for (final entry in json.entries) {
    if (entry.key is! String || entry.value is! List) {
      continue;
    }
    final nodes = <Node>[];
    for (final item in entry.value as List) {
      final node = nodeFromJson(item);
      if (node != null) {
        nodes.add(node);
      }
    }
    if (nodes.isNotEmpty) {
      children[entry.key as String] = nodes;
    }
  }
  return children;
}

Object? _decodeValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: _decodeValue(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _decodeValue(item)];
  }
  return value;
}

String _titleOf(Node root) {
  final app = root.childrenBySlot['app'];
  if (app != null && app.isNotEmpty) {
    final title = app.first.fields['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title;
    }
  }
  return root.fields['slug'] as String? ?? '';
}
