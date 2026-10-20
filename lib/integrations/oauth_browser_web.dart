import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/integrations/oauth_browser.dart';
import 'package:web/web.dart';

const _sessionKey = 'sodalite-configurator.oauth';

OAuthBrowser createOAuthBrowser() => _WebOAuthBrowser();

class _WebOAuthBrowser implements OAuthBrowser {
  @override
  OAuthCallback? takeCallback() {
    final uri = Uri.parse(window.location.href);
    final params = uri.queryParameters;
    final error = params['error'];
    final code = params['code'];
    if ((error == null || error.isEmpty) && (code == null || code.isEmpty)) return null;
    _replaceAddress(uri);
    if (error != null && error.isNotEmpty) {
      final description = params['error_description'];
      return OAuthCallback.failure(description == null || description.isEmpty ? error : description);
    }
    return OAuthCallback.success(code: code ?? '', state: params['state'] ?? '');
  }

  @override
  void remember({required String state, required String verifier, required String redirectUri}) {
    window.sessionStorage.setItem(
      _sessionKey,
      jsonEncode({'state': state, 'verifier': verifier, 'redirectUri': redirectUri}),
    );
  }

  @override
  OAuthSession? takeSession(String state) {
    final raw = window.sessionStorage.getItem(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['state'] != state) return null;
      final verifier = decoded['verifier'];
      final redirectUri = decoded['redirectUri'];
      if (verifier is! String || verifier.isEmpty || redirectUri is! String || redirectUri.isEmpty) return null;
      return OAuthSession(verifier: verifier, redirectUri: redirectUri);
    } catch (_) {
      return null;
    }
  }

  @override
  void clearSession() {
    window.sessionStorage.removeItem(_sessionKey);
  }

  @override
  String redirectUri() => _pageAddress(Uri.parse(window.location.href));

  @override
  Future<String> challenge(String verifier) async {
    final digest = await window.crypto.subtle
        .digest('SHA-256'.toJS, Uint8List.fromList(utf8.encode(verifier)).toJS)
        .toDart;
    if (digest is! JSArrayBuffer) {
      throw IntegrationException('Браузер не смог подготовить вход.');
    }
    return base64Url.encode(digest.toDart.asUint8List()).replaceAll('=', '');
  }

  @override
  void go(Uri uri) {
    window.location.assign(uri.toString());
  }

  void _replaceAddress(Uri uri) {
    final kept = <String, String>{
      for (final entry in uri.queryParameters.entries)
        if (entry.key != 'code' &&
            entry.key != 'state' &&
            entry.key != 'error' &&
            entry.key != 'error_description' &&
            entry.key != 'session_state' &&
            entry.key != 'iss')
          entry.key: entry.value,
    };
    window.history.replaceState(null, '', _pageAddress(uri, kept));
  }
}

String _pageAddress(Uri uri, [Map<String, String> query = const {}]) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  final base = '${uri.origin}$path';
  if (query.isEmpty) return base;
  return Uri.parse(base).replace(queryParameters: query).toString();
}
