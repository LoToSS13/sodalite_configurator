import 'package:sodalite_configurator/integrations/http_client.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';

IntegrationHttp createIntegrationHttp() => _StubIntegrationHttp();

class _StubIntegrationHttp implements IntegrationHttp {
  @override
  Future<HttpResult> send({
    required String method,
    required Uri url,
    Map<String, String> headers = const {},
    String? body,
  }) {
    throw IntegrationException('Запросы к Consul и Jasper доступны в браузерной версии.');
  }
}
