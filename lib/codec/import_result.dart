import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/schema/node.dart';

const kModulePackFileNames = {
  'app.json',
  'base_layer.json',
  'additional_layers.json',
  'object_creation.json',
  'search.json',
};

@immutable
class ImportResult {
  final Node? bundle;
  final List<ImportWarning> warnings;
  final List<String> errors;

  const ImportResult({this.bundle, this.warnings = const [], this.errors = const []});
}

List<ImportWarning> zipExtraFileWarnings(Iterable<String> names, {required String prefix}) {
  final prefixWithSlash = prefix.endsWith('/') ? prefix : '$prefix/';
  final warnings = <ImportWarning>[];
  for (final name in names) {
    if (name.endsWith('/')) {
      continue;
    }
    if (!name.startsWith(prefixWithSlash)) {
      warnings.add(ImportWarning(file: name, message: 'Unknown extra file "$name" was ignored.'));
      continue;
    }
    final relative = name.substring(prefixWithSlash.length);
    if (relative.isEmpty || relative.contains('/')) {
      if (relative.isNotEmpty) {
        warnings.add(ImportWarning(file: relative, message: 'Unknown extra file "$relative" was ignored.'));
      }
      continue;
    }
    if (!kModulePackFileNames.contains(relative)) {
      warnings.add(ImportWarning(file: relative, message: 'Unknown extra file "$relative" was ignored.'));
    }
  }
  return warnings;
}

String moduleFileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash == -1 ? normalized : normalized.substring(slash + 1);
}
