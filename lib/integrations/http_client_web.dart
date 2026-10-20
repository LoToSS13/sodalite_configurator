import 'dart:js_interop';

import 'package:sodalite_configurator/integrations/http_client.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:web/web.dart';

IntegrationHttp createIntegrationHttp() => _WebIntegrationHttp();

class _WebIntegrationHttp implements IntegrationHttp {
  @override
  Future<HttpResult> send({
    required String method,
    required Uri url,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final headerList = Headers();
    for (final entry in headers.entries) {
      headerList.append(entry.key, entry.value);
    }
    try {
      final response = await window
          .fetch(
            url.toString().toJS,
            RequestInit(
              method: method,
              headers: headerList,
              body: body?.toJS,
              credentials: 'omit',
              mode: 'cors',
              cache: 'no-store',
            ),
          )
          .toDart;
      final text = (await response.text().toDart).toDart;
      return HttpResult(response.status, text);
    } catch (_) {
      throw IntegrationException(
        'Браузер не пустил запрос к ${url.host}. Сервер должен разрешать этот сайт и заголовки Authorization и X-Consul-Token.',
      );
    }
  }
}
