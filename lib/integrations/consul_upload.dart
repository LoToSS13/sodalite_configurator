import 'dart:convert';

import 'package:sodalite_configurator/codec/json_format.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/integrations/http_client.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/integrations/service_urls.dart';

final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

bool isConsulSlug(String slug) => _slugPattern.hasMatch(slug.trim());

List<String> writtenConsulFiles(ModuleFiles files) => [
  'app.json',
  'base_layer.json',
  'additional_layers.json',
  if (files.objectCreation != null) 'object_creation.json',
  if (files.search != null) 'search.json',
];

List<String> removedConsulFiles(ModuleFiles files) => [
  if (files.objectCreation == null) 'object_creation.json',
  if (files.search == null) 'search.json',
];

/// One Consul transaction, so a failed write does not leave half a module.
List<Map<String, Object?>> consulTransaction(ModuleFiles files) {
  final slug = files.slug.trim();
  if (!isConsulSlug(slug)) {
    throw IntegrationException('Идентификатор модуля не подходит для пути Consul.');
  }
  final prefix = 'apps/$slug';
  return [
    _set('$prefix/app.json', encodeJson(files.app)),
    _set('$prefix/base_layer.json', encodeJson(files.baseLayer)),
    _set('$prefix/additional_layers.json', encodeJson(files.additionalLayers)),
    if (files.objectCreation != null)
      _set('$prefix/object_creation.json', encodeJson(files.objectCreation!))
    else
      _delete('$prefix/object_creation.json'),
    if (files.search != null)
      _set('$prefix/search.json', encodeJson(files.search!))
    else
      _delete('$prefix/search.json'),
  ];
}

Future<void> uploadModuleToConsul({
  required IntegrationHttp http,
  required String consulUrl,
  required String token,
  required ModuleFiles files,
}) async {
  final result = await http.send(
    method: 'PUT',
    url: Uri.parse('${consulAgentRoot(consulUrl)}/v1/txn'),
    headers: {'X-Consul-Token': token.trim(), 'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(consulTransaction(files)),
  );
  if (result.status >= 200 && result.status < 300) return;
  throw IntegrationException(_consulFailure(result.status, result.body));
}

Map<String, Object?> _set(String key, String value) => {
  'KV': {'Verb': 'set', 'Key': key, 'Value': base64Encode(utf8.encode(value))},
};

Map<String, Object?> _delete(String key) => {
  'KV': {'Verb': 'delete', 'Key': key},
};

String _consulFailure(int status, String body) {
  if (status == 401 || status == 403) {
    final brief = briefBody(body);
    return 'Consul отклонил ключ API.${brief.isEmpty ? '' : ' $brief'}';
  }
  final brief = briefBody(body);
  return 'Consul ответил $status.${brief.isEmpty ? '' : ' $brief'}';
}
