import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:sodalite_configurator/codec/import_result.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';

export 'package:sodalite_configurator/codec/import_result.dart';

ImportResult importZip(List<int> bytes, {required String Function() id}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (error) {
    return ImportResult(errors: ['zip: $error']);
  }

  final fileNames = [
    for (final file in archive.files)
      if (file.isFile) file.name,
  ];
  final slugs = _slugsIn(fileNames);
  if (slugs.length > 1) {
    return ImportResult(errors: ['Multiple module folders found: ${slugs.join(', ')}']);
  }

  if (slugs.length == 1) {
    final slug = slugs.single;
    final prefix = 'apps/$slug';
    final contents = <String, String>{};
    for (final file in archive.files.where((file) => file.isFile)) {
      if (!file.name.startsWith('$prefix/')) {
        continue;
      }
      final relative = file.name.substring(prefix.length + 1);
      if (kModulePackFileNames.contains(relative)) {
        contents[relative] = utf8.decode(file.content as List<int>);
      }
    }
    return importLooseFiles(
      contents,
      slug: slug,
      id: id,
      extraWarnings: zipExtraFileWarnings(fileNames, prefix: prefix),
    );
  }

  final contents = <String, String>{};
  for (final file in archive.files.where((file) => file.isFile)) {
    contents[file.name] = utf8.decode(file.content as List<int>);
  }
  return importLooseFiles(contents, id: id);
}

ImportResult importLooseFiles(
  Map<String, String> nameToContent, {
  String? slug,
  required String Function() id,
  List<ImportWarning> extraWarnings = const [],
}) {
  final warnings = [...extraWarnings];
  final errors = <String>[];
  final byName = <String, String>{};
  for (final entry in nameToContent.entries) {
    final name = moduleFileName(entry.key);
    if (kModulePackFileNames.contains(name)) {
      byName[name] = entry.value;
    } else {
      warnings.add(ImportWarning(file: name, message: 'Unknown extra file "$name" was ignored.'));
    }
  }

  final app = _decodeObject('app.json', byName['app.json'], errors) ?? const <String, dynamic>{};
  final baseLayer = _decodeObject('base_layer.json', byName['base_layer.json'], errors) ?? const <String, dynamic>{};
  final additionalLayers = _decodeAdditional(byName['additional_layers.json'], errors);
  final objectCreation = byName.containsKey('object_creation.json')
      ? _decodeObject('object_creation.json', byName['object_creation.json'], errors)
      : null;
  final search = byName.containsKey('search.json') ? _decodeObject('search.json', byName['search.json'], errors) : null;

  final files = ModuleFiles(
    slug: slug ?? 'imported',
    app: app,
    baseLayer: baseLayer,
    additionalLayers: additionalLayers,
    objectCreation: objectCreation,
    search: search,
  );
  final decoded = decodeModule(files, id: id);
  warnings.addAll(decoded.warnings);

  return ImportResult(bundle: decoded.bundle, warnings: warnings, errors: errors);
}

Set<String> _slugsIn(Iterable<String> names) {
  final slugs = <String>{};
  final pattern = RegExp(r'^apps/([^/]+)/');
  for (final name in names) {
    final match = pattern.firstMatch(name);
    if (match != null) {
      slugs.add(match.group(1)!);
    }
  }
  return slugs;
}

Map<String, dynamic>? _decodeObject(String file, String? content, List<String> errors) {
  if (content == null) {
    return null;
  }
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    errors.add('$file: expected a JSON object');
  } catch (error) {
    errors.add('$file: $error');
  }
  return null;
}

Object _decodeAdditional(String? content, List<String> errors) {
  if (content == null) {
    return const [];
  }
  try {
    return jsonDecode(content);
  } catch (error) {
    errors.add('additional_layers.json: $error');
    return const [];
  }
}
