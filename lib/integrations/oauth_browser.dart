import 'package:sodalite_configurator/integrations/oauth_browser_stub.dart'
    if (dart.library.html) 'package:sodalite_configurator/integrations/oauth_browser_web.dart'
    as impl;

class OAuthCallback {
  const OAuthCallback.success({required this.code, required this.state}) : error = null;

  const OAuthCallback.failure(this.error) : code = null, state = null;

  final String? code;
  final String? state;
  final String? error;
}

class OAuthSession {
  const OAuthSession({required this.verifier, required this.redirectUri});

  final String verifier;
  final String redirectUri;
}

abstract class OAuthBrowser {
  OAuthCallback? takeCallback();

  void remember({required String state, required String verifier, required String redirectUri});

  OAuthSession? takeSession(String state);

  void clearSession();

  String redirectUri();

  Future<String> challenge(String verifier);

  void go(Uri uri);
}

OAuthBrowser createOAuthBrowser() => impl.createOAuthBrowser();
