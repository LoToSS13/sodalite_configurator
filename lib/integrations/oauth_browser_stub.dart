import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/integrations/oauth_browser.dart';

OAuthBrowser createOAuthBrowser() => _StubOAuthBrowser();

class _StubOAuthBrowser implements OAuthBrowser {
  @override
  OAuthCallback? takeCallback() => null;

  @override
  void remember({required String state, required String verifier, required String redirectUri}) {}

  @override
  OAuthSession? takeSession(String state) => null;

  @override
  void clearSession() {}

  @override
  String redirectUri() => '';

  @override
  Future<String> challenge(String verifier) {
    throw IntegrationException('Вход в Jasper доступен в браузерной версии.');
  }

  @override
  void go(Uri uri) {
    throw IntegrationException('Вход в Jasper доступен в браузерной версии.');
  }
}
