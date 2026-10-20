import 'package:sodalite_configurator/integrations/http_client_stub.dart'
    if (dart.library.html) 'package:sodalite_configurator/integrations/http_client_web.dart'
    as impl;

class HttpResult {
  const HttpResult(this.status, this.body);

  final int status;
  final String body;
}

abstract class IntegrationHttp {
  Future<HttpResult> send({
    required String method,
    required Uri url,
    Map<String, String> headers = const {},
    String? body,
  });
}

IntegrationHttp createIntegrationHttp() => impl.createIntegrationHttp();
