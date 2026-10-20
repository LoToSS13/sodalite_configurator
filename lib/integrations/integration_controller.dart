import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/integrations/consul_upload.dart';
import 'package:sodalite_configurator/integrations/http_client.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/integration_store.dart';
import 'package:sodalite_configurator/integrations/jasper_api.dart';
import 'package:sodalite_configurator/integrations/oauth_browser.dart';
import 'package:sodalite_configurator/integrations/service_urls.dart';

const _pkceAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

class IntegrationController extends ChangeNotifier {
  IntegrationController({IntegrationStore? store, IntegrationHttp? http, OAuthBrowser? oauth})
    : _store = store ?? createIntegrationStore(),
      _http = http ?? createIntegrationHttp(),
      _oauth = oauth ?? createOAuthBrowser() {
    _settings = _store.read();
    _boot();
  }

  final IntegrationStore _store;
  final IntegrationHttp _http;
  final OAuthBrowser _oauth;

  late IntegrationSettings _settings;
  String? _notice;
  var _noticeIsError = false;
  var _busyLogin = false;
  var _busyRefresh = false;
  var _busyXsds = false;
  var _busyUpload = false;

  IntegrationSettings get settings => _settings;

  String? get notice => _notice;

  bool get noticeIsError => _noticeIsError;

  bool get busyLogin => _busyLogin;

  bool get busyRefresh => _busyRefresh;

  bool get busyXsds => _busyXsds;

  bool get busyUpload => _busyUpload;

  String get redirectUri => _oauth.redirectUri();

  void _boot() {
    final callback = _oauth.takeCallback();
    if (callback != null) {
      unawaited(finishLogin(callback));
      return;
    }
    unawaited(refreshXsds(silent: !_settings.signedIn));
  }

  void updateConnection({
    required String consulUrl,
    required String consulToken,
    required String jasperApiUrl,
    required String identityUrl,
    required String clientId,
    required String clientSecret,
    required String scope,
  }) {
    _settings = _settings.copyWith(
      consulUrl: consulUrl,
      consulToken: consulToken,
      jasperApiUrl: jasperApiUrl,
      identityUrl: identityUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      scope: scope,
    );
    _store.write(_settings);
    notifyListeners();
  }

  void explain(String message) {
    _notice = message;
    _noticeIsError = false;
    notifyListeners();
  }

  void logout() {
    _settings = _settings.copyWith(
      accessToken: '',
      refreshToken: '',
      accessExpiresAt: null,
      xsds: const [],
      xsdsFetchedAt: null,
    );
    _store.write(_settings);
    _notice = 'Выход выполнен. Адреса сохранены.';
    _noticeIsError = false;
    notifyListeners();
  }

  Future<void> login() async {
    if (_busyLogin) return;
    final missing = <String>[
      if (!looksLikeHttpUrl(_settings.jasperApiUrl)) 'адрес Jasper',
      if (!looksLikeHttpUrl(_settings.identityUrl)) 'адрес Identity',
      if (_settings.clientId.trim().isEmpty) 'идентификатор клиента',
    ];
    if (missing.isNotEmpty) {
      _fail('Заполните: ${missing.join(', ')}.');
      return;
    }
    final redirect = _oauth.redirectUri();
    if (redirect.isEmpty) {
      _fail('Вход в Jasper доступен в браузерной версии.');
      return;
    }
    _busyLogin = true;
    _notice = null;
    notifyListeners();
    try {
      final verifier = _randomToken();
      final challenge = await _oauth.challenge(verifier);
      final state = _randomToken(32);
      _oauth.remember(state: state, verifier: verifier, redirectUri: redirect);
      _oauth.go(
        jasperAuthorizeUri(
          identityUrl: _settings.identityUrl,
          clientId: _settings.clientId,
          redirectUri: redirect,
          scope: _settings.scope,
          state: state,
          challenge: challenge,
        ),
      );
    } catch (error) {
      _busyLogin = false;
      _fail(_message(error, 'Не удалось открыть вход в Jasper.'));
    }
  }

  Future<void> finishLogin(OAuthCallback callback) async {
    _busyLogin = true;
    _notice = null;
    notifyListeners();
    var signedIn = false;
    try {
      if (callback.error != null) throw IntegrationException(callback.error!);
      final session = _oauth.takeSession(callback.state ?? '');
      if (session == null || callback.code == null || callback.code!.isEmpty) {
        throw IntegrationException('Сессия входа потеряна. Нажмите «Войти» ещё раз.');
      }
      final token = await exchangeJasperToken(
        http: _http,
        identityUrl: _settings.identityUrl,
        clientId: _settings.clientId,
        clientSecret: _settings.clientSecret,
        grant: {
          'grant_type': 'authorization_code',
          'code': callback.code!,
          'redirect_uri': session.redirectUri,
          'code_verifier': session.verifier,
        },
      );
      _rememberToken(token);
      _notice = 'Вход в Jasper выполнен.';
      _noticeIsError = false;
      signedIn = true;
    } catch (error) {
      _notice = _message(error, 'Не удалось войти в Jasper.');
      _noticeIsError = true;
    } finally {
      _oauth.clearSession();
      _busyLogin = false;
      notifyListeners();
    }
    if (signedIn) await refreshXsds();
  }

  Future<void> refreshAccessToken() async {
    if (_busyRefresh) return;
    if (_settings.refreshToken.trim().isEmpty) {
      _fail('Токена обновления нет. Войдите снова: Identity выдаёт его не при каждом входе.');
      return;
    }
    _busyRefresh = true;
    _notice = null;
    notifyListeners();
    var refreshed = false;
    try {
      final token = await exchangeJasperToken(
        http: _http,
        identityUrl: _settings.identityUrl,
        clientId: _settings.clientId,
        clientSecret: _settings.clientSecret,
        grant: {'grant_type': 'refresh_token', 'refresh_token': _settings.refreshToken.trim()},
      );
      _rememberToken(token, keepRefresh: token.refreshToken == null);
      _notice = 'Токен обновлён.';
      _noticeIsError = false;
      refreshed = true;
    } catch (error) {
      _notice = _message(error, 'Не удалось обновить токен.');
      _noticeIsError = true;
    } finally {
      _busyRefresh = false;
      notifyListeners();
    }
    if (refreshed) await refreshXsds();
  }

  void refreshXsdsIfSignedIn() {
    if (!_settings.signedIn || _busyLogin || _busyRefresh || _busyXsds) return;
    unawaited(refreshXsds());
  }

  Future<void> refreshXsds({bool silent = false}) async {
    if (!_settings.signedIn) {
      if (!silent) _fail('Сначала войдите в Jasper.');
      return;
    }
    if (_busyXsds) return;
    if (!looksLikeHttpUrl(_settings.jasperApiUrl)) {
      if (!silent) _fail('Укажите адрес Jasper.');
      return;
    }
    _busyXsds = true;
    if (!silent) _notice = null;
    notifyListeners();
    final requestedUrl = _settings.jasperApiUrl;
    try {
      final list = await fetchJasperXsds(http: _http, apiUrl: requestedUrl, accessToken: _settings.accessToken);
      if (_settings.jasperApiUrl.trim() != requestedUrl.trim()) return;
      _settings = _settings.copyWith(xsds: list, xsdsFetchedAt: DateTime.now().toUtc());
      _store.write(_settings);
      _notice = list.isEmpty
          ? 'Jasper вернул пустой список XSD. Проверьте права клиента.'
          : 'Список XSD обновлён: ${list.length}.';
      _noticeIsError = list.isEmpty;
    } catch (error) {
      if (_settings.jasperApiUrl.trim() != requestedUrl.trim()) {
        _settings = _settings.copyWith(xsds: const [], xsdsFetchedAt: null);
        _store.write(_settings);
      }
      _notice = _message(error, 'Не удалось получить список XSD.');
      _noticeIsError = true;
    } finally {
      _busyXsds = false;
      notifyListeners();
    }
  }

  Future<void> uploadToConsul(ModuleFiles files) async {
    if (!_settings.consulReady) {
      throw IntegrationException('Укажите адрес Consul и ключ API.');
    }
    if (_busyUpload) return;
    _busyUpload = true;
    notifyListeners();
    try {
      await uploadModuleToConsul(
        http: _http,
        consulUrl: _settings.consulUrl,
        token: _settings.consulToken,
        files: files,
      );
      _notice = 'Модуль ${files.slug} записан в Consul.';
      _noticeIsError = false;
    } catch (error) {
      final message = _message(error, 'Не удалось записать модуль в Consul.');
      _notice = message;
      _noticeIsError = true;
      throw IntegrationException(message);
    } finally {
      _busyUpload = false;
      notifyListeners();
    }
  }

  void _rememberToken(JasperToken token, {bool keepRefresh = false}) {
    _settings = _settings.copyWith(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken ?? (keepRefresh ? _settings.refreshToken : ''),
      accessExpiresAt: token.expiresAt,
    );
    _store.write(_settings);
  }

  void _fail(String message) {
    _notice = message;
    _noticeIsError = true;
    notifyListeners();
  }

  String _message(Object error, String fallback) {
    return error is IntegrationException ? error.message : fallback;
  }
}

String _randomToken([int length = 64]) {
  final random = Random.secure();
  return String.fromCharCodes(
    List.generate(length, (_) => _pkceAlphabet.codeUnitAt(random.nextInt(_pkceAlphabet.length))),
  );
}
