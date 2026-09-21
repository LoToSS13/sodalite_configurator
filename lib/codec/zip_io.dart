import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';

List<int> buildModuleZip(ModuleFiles files) {
  final archive = Archive();
  final prefix = 'apps/${files.slug}';

  archive.add(ArchiveFile.string('$prefix/app.json', encodeJson(files.app)));
  archive.add(ArchiveFile.string('$prefix/base_layer.json', encodeJson(files.baseLayer)));
  archive.add(ArchiveFile.string('$prefix/additional_layers.json', encodeJson(files.additionalLayers)));
  if (files.objectCreation != null) {
    archive.add(ArchiveFile.string('$prefix/object_creation.json', encodeJson(files.objectCreation!)));
  }
  if (files.search != null) {
    archive.add(ArchiveFile.string('$prefix/search.json', encodeJson(files.search!)));
  }

  return ZipEncoder().encodeBytes(archive);
}

({ModuleFiles files, List<ImportWarning> warnings}) parseModuleZip(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final entries = {for (final file in archive.files) file.name: file};
  final appPath = entries.keys.firstWhere(
    (name) => RegExp(r'^apps/[^/]+/app\.json$').hasMatch(name),
    orElse: () => throw const FormatException('Missing apps/{slug}/app.json'),
  );
  final prefix = appPath.substring(0, appPath.length - '/app.json'.length);
  final slug = prefix.substring('apps/'.length);

  Map<String, dynamic> readMap(String name) {
    final file = entries['$prefix/$name'];
    if (file == null) {
      throw FormatException('Missing $prefix/$name');
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(file.content)) as Map);
  }

  Map<String, dynamic>? readOptionalMap(String name) {
    final file = entries['$prefix/$name'];
    return file == null ? null : Map<String, dynamic>.from(jsonDecode(utf8.decode(file.content)) as Map);
  }

  final additionalFile = entries['$prefix/additional_layers.json'];
  if (additionalFile == null) {
    throw FormatException('Missing $prefix/additional_layers.json');
  }

  return (
    files: ModuleFiles(
      slug: slug,
      app: readMap('app.json'),
      baseLayer: readMap('base_layer.json'),
      additionalLayers: jsonDecode(utf8.decode(additionalFile.content)),
      objectCreation: readOptionalMap('object_creation.json'),
      search: readOptionalMap('search.json'),
    ),
    warnings: <ImportWarning>[],
  );
}
