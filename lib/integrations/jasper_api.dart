import 'dart:convert';

import 'package:sodalite_configurator/integrations/http_client.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/service_urls.dart';

class JasperToken {
  const JasperToken({required this.accessToken, this.refreshToken, this.expiresAt});

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
}

Uri jasperAuthorizeUri({
  required String identityUrl,
  required String clientId,
  required String redirectUri,
  required String scope,
  required String state,
  required String challenge,
}) {
  return Uri.parse('${identityServerRoot(identityUrl)}/connect/authorize').replace(
    queryParameters: {
      'client_id': clientId.trim(),
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'response_mode': 'query',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      if (scope.trim().isNotEmpty) 'scope': scope.trim(),
    },
  );
}

Future<JasperToken> exchangeJasperToken({
  required IntegrationHttp http,
  required String identityUrl,
  required String clientId,
  required String clientSecret,
  required Map<String, String> grant,
}) async {
  final fields = <String, String>{
    'client_id': clientId.trim(),
    ...grant,
    if (clientSecret.trim().isNotEmpty) 'client_secret': clientSecret.trim(),
  };
  final result = await http.send(
    method: 'POST',
    url: Uri.parse('${identityServerRoot(identityUrl)}/connect/token'),
    headers: const {'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
    body: Uri(queryParameters: fields).query,
  );
  if (result.status < 200 || result.status >= 300) {
    throw IntegrationException(_tokenFailure(result.status, result.body));
  }
  return parseJasperToken(result.body);
}

JasperToken parseJasperToken(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw IntegrationException('Jasper вернул не JSON при входе.');
  }
  if (decoded is! Map) throw IntegrationException('Jasper вернул неожиданный ответ входа.');
  final access = decoded['access_token'];
  if (access is! String || access.isEmpty) {
    final error = decoded['error_description'] ?? decoded['error'];
    throw IntegrationException(error is String && error.isNotEmpty ? error : 'Jasper не выдал токен.');
  }
  final refresh = decoded['refresh_token'];
  final expiresIn = decoded['expires_in'];
  return JasperToken(
    accessToken: access,
    refreshToken: refresh is String && refresh.isNotEmpty ? refresh : null,
    expiresAt: expiresIn is num ? DateTime.now().toUtc().add(Duration(seconds: expiresIn.round())) : null,
  );
}

Future<List<XsdEntry>> fetchJasperXsds({
  required IntegrationHttp http,
  required String apiUrl,
  required String accessToken,
}) async {
  final result = await http.send(
    method: 'GET',
    url: Uri.parse('${jasperApiPrefix(apiUrl)}/XSDs'),
    headers: {'Authorization': 'Bearer ${accessToken.trim()}', 'Accept': 'application/json'},
  );
  if (result.status == 401 || result.status == 403) {
    throw IntegrationException('Jasper не принял токен. Обновите его или войдите снова.');
  }
  if (result.status == 404) {
    throw IntegrationException('Список XSD не найден. Проверьте адрес Jasper: к нему добавляется /api/v1/XSDs.');
  }
  if (result.status < 200 || result.status >= 300) {
    final brief = briefBody(result.body);
    throw IntegrationException('Jasper ответил ${result.status}.${brief.isEmpty ? '' : ' $brief'}');
  }
  return parseJasperXsds(result.body);
}

List<XsdEntry> parseJasperXsds(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw IntegrationException('Jasper вернул не JSON со списком XSD.');
  }
  final list = _unwrapList(decoded);
  if (list == null) {
    throw IntegrationException('В ответе Jasper нет списка XSD.');
  }
  final entries = <XsdEntry>[];
  final seen = <String>{};
  for (final item in list) {
    final entry = _entryFrom(item);
    if (entry == null || !seen.add(entry.value)) continue;
    entries.add(entry);
  }
  entries.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return entries;
}

List<Object?>? _unwrapList(Object? decoded) {
  if (decoded is List) return decoded;
  if (decoded is! Map) return null;
  for (final key in const ['xsds', 'XSDs', 'items', 'data', 'value', 'result', 'results']) {
    final nested = decoded[key];
    if (nested is List) return nested;
  }
  return null;
}

XsdEntry? _entryFrom(Object? item) {
  if (item is String && item.trim().isNotEmpty) {
    final value = item.trim();
    return XsdEntry(value: value, label: value);
  }
  if (item is! Map) return null;
  String? pick(List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  final value = pick(['businessScope', 'alias', 'xsdPath', 'path', 'id', 'name', 'key']);
  if (value == null) return null;
  final label = pick(['name', 'title', 'alias', 'businessScope']) ?? value;
  return XsdEntry(value: value, label: label);
}

String _tokenFailure(int status, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error_description'] ?? decoded['error'];
      if (error is String && error.isNotEmpty) return error;
    }
  } catch (_) {}
  final brief = briefBody(body);
  return 'Identity ответил $status.${brief.isEmpty ? '' : ' $brief'}';
}
