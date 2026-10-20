import 'dart:convert';

import 'package:sodalite_configurator/codec/import_result.dart';
import 'package:sodalite_configurator/integrations/consul_upload.dart';
import 'package:sodalite_configurator/integrations/http_client.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/integrations/service_urls.dart';

class ConsulModuleFolder {
  const ConsulModuleFolder({required this.files, required this.ignored});

  final Map<String, String> files;
  final List<String> ignored;
}

Future<List<String>> listConsulModuleSlugs({
  required IntegrationHttp http,
  required String consulUrl,
  required String token,
}) async {
  final result = await http.send(
    method: 'GET',
    url: _kvUri(consulUrl, 'apps/', {'keys': 'true', 'separator': '/'}),
    headers: _headers(token),
  );
  if (result.status == 404) return const [];
  _reject(result, 'Не удалось получить список модулей Consul.');
  return parseConsulModuleSlugs(result.body);
}

Future<ConsulModuleFolder> readConsulModule({
  required IntegrationHttp http,
  required String consulUrl,
  required String token,
  required String slug,
}) async {
  final folder = slug.trim();
  if (!isConsulSlug(folder)) {
    throw IntegrationException('Идентификатор модуля не подходит для пути Consul. Например, city_objects');
  }
  final result = await http.send(
    method: 'GET',
    url: _kvUri(consulUrl, 'apps/$folder/', {'recurse': 'true'}),
    headers: _headers(token),
  );
  if (result.status == 404) {
    throw IntegrationException('В Consul нет модуля «$folder» по пути apps/$folder/.');
  }
  _reject(result, 'Не удалось прочитать модуль из Consul.');
  return parseConsulModule(result.body, slug: folder);
}

List<String> parseConsulModuleSlugs(String body) {
  final decoded = _jsonList(body, 'Consul вернул неожиданный список модулей.');
  final slugs = <String>{};
  for (final item in decoded) {
    if (item is! String) continue;
    final parts = item.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length == 2 && parts.first == 'apps' && isConsulSlug(parts[1])) slugs.add(parts[1]);
  }
  return slugs.toList()..sort();
}

ConsulModuleFolder parseConsulModule(String body, {required String slug}) {
  final decoded = _jsonList(body, 'Consul вернул неожиданный модуль.');
  final prefix = 'apps/$slug/';
  final files = <String, String>{};
  final ignored = <String>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final key = item['Key'];
    if (key is! String || !key.startsWith(prefix)) continue;
    final relative = key.substring(prefix.length);
    if (relative.isEmpty || relative.endsWith('/')) continue;
    if (!kModulePackFileNames.contains(relative) || relative.contains('/')) {
      ignored.add(relative);
      continue;
    }
    files[relative] = _decodeValue(relative, item['Value']);
  }
  if (files.isEmpty) {
    throw IntegrationException('В apps/$slug/ нет файлов модуля.');
  }
  return ConsulModuleFolder(files: files, ignored: ignored);
}

Uri _kvUri(String consulUrl, String key, Map<String, String> query) {
  return Uri.parse('${consulAgentRoot(consulUrl)}/v1/kv/$key').replace(queryParameters: query);
}

Map<String, String> _headers(String token) => {'X-Consul-Token': token.trim(), 'Accept': 'application/json'};

void _reject(HttpResult result, String fallback) {
  if (result.status >= 200 && result.status < 300) return;
  throw IntegrationException(_consulFailure(result.status, result.body, fallback));
}

String _consulFailure(int status, String body, String fallback) {
  if (status == 401 || status == 403) {
    final brief = briefBody(body);
    return 'Consul отклонил ключ API.${brief.isEmpty ? '' : ' $brief'}';
  }
  final brief = briefBody(body);
  if (brief.isEmpty) return '$fallback Consul ответил $status.';
  return '$fallback Consul ответил $status. $brief';
}

List<Object?> _jsonList(String body, String failure) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw IntegrationException('Consul вернул не JSON.');
  }
  if (decoded is! List) throw IntegrationException(failure);
  return decoded;
}

String _decodeValue(String filename, Object? value) {
  if (value is! String || value.isEmpty) {
    throw IntegrationException('Файл «$filename» в Consul пуст.');
  }
  try {
    return utf8.decode(base64Decode(value));
  } catch (_) {
    throw IntegrationException('Файл «$filename» в Consul не удалось прочитать.');
  }
}
