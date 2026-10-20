import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/integrations/consul_read.dart' as consul_read;
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
    _catalog = _store.read();
    _boot();
  }

  final IntegrationStore _store;
  final IntegrationHttp _http;
  final OAuthBrowser _oauth;

  late IntegrationCatalog _catalog;
  String? _notice;
  var _noticeIsError = false;
  var _busyLogin = false;
  var _busyRefresh = false;
  var _busyXsds = false;
  var _busyUpload = false;

  IntegrationSettings get settings => _catalog.settings;

  List<IntegrationContour> get contours => _catalog.contours;

  String? get activeContourId => _catalog.active?.id;

  String? get activeContourName => _catalog.active?.name;

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
    unawaited(refreshXsds(silent: !settings.signedIn));
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
    _saveActive(
      settings.copyWith(
        consulUrl: consulUrl,
        consulToken: consulToken,
        jasperApiUrl: jasperApiUrl,
        identityUrl: identityUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        scope: scope,
      ),
    );
    notifyListeners();
  }

  void selectContour(String id) {
    if (_catalog.active?.id == id || _catalog.contours.every((contour) => contour.id != id)) return;
    _catalog = _catalog.select(id);
    _store.write(_catalog);
    _notice = null;
    notifyListeners();
  }

  void addContour(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final contour = IntegrationContour(id: _randomToken(12), name: trimmed, settings: IntegrationSettings.empty);
    _catalog = _catalog.add(contour);
    _store.write(_catalog);
    _notice = null;
    notifyListeners();
  }

  void renameContour(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _catalog.contours.every((contour) => contour.id != id)) return;
    _catalog = _catalog.updating(id, name: trimmed);
    _store.write(_catalog);
    notifyListeners();
  }

  void deleteContour(String id) {
    if (_catalog.contours.every((contour) => contour.id != id)) return;
    _catalog = _catalog.remove(id);
    _store.write(_catalog);
    _notice = null;
    notifyListeners();
  }

  void explain(String message) {
    _notice = message;
    _noticeIsError = false;
    notifyListeners();
  }

  void logout() {
    _saveActive(
      settings.copyWith(accessToken: '', refreshToken: '', accessExpiresAt: null, xsds: const [], xsdsFetchedAt: null),
    );
    _notice = 'Выход выполнен. Адреса сохранены.';
    _noticeIsError = false;
    notifyListeners();
  }

  Future<void> login() async {
    if (_busyLogin) return;
    final missing = <String>[
      if (!looksLikeHttpUrl(settings.jasperApiUrl)) 'Base URL',
      if (!looksLikeHttpUrl(settings.identityUrl)) 'Auth URL',
      if (settings.clientId.trim().isEmpty) 'Client ID',
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
          identityUrl: settings.identityUrl,
          clientId: settings.clientId,
          redirectUri: redirect,
          scope: settings.scope,
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
        identityUrl: settings.identityUrl,
        clientId: settings.clientId,
        clientSecret: settings.clientSecret,
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
    if (settings.refreshToken.trim().isEmpty) {
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
        identityUrl: settings.identityUrl,
        clientId: settings.clientId,
        clientSecret: settings.clientSecret,
        grant: {'grant_type': 'refresh_token', 'refresh_token': settings.refreshToken.trim()},
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
    if (!settings.signedIn || _busyLogin || _busyRefresh || _busyXsds) return;
    unawaited(refreshXsds());
  }

  Future<void> refreshXsds({bool silent = false}) async {
    if (!settings.signedIn) {
      if (!silent) _fail('Сначала войдите в Jasper.');
      return;
    }
    if (_busyXsds) return;
    if (!looksLikeHttpUrl(settings.jasperApiUrl)) {
      if (!silent) _fail('Укажите Base URL.');
      return;
    }
    _busyXsds = true;
    if (!silent) _notice = null;
    notifyListeners();
    final requestedUrl = settings.jasperApiUrl;
    final requestedContour = activeContourId;
    try {
      final list = await fetchJasperXsds(http: _http, apiUrl: requestedUrl, accessToken: settings.accessToken);
      if (!_sameContour(requestedContour, requestedUrl)) return;
      final notice = list.isEmpty
          ? await _emptyXsdNotice(requestedUrl, requestedContour)
          : 'Список XSD обновлён: ${list.length}.';
      if (notice == null || !_sameContour(requestedContour, requestedUrl)) return;
      _saveActive(settings.copyWith(xsds: list, xsdsFetchedAt: DateTime.now().toUtc()));
      _notice = notice;
      _noticeIsError = list.isEmpty;
    } catch (error) {
      if (activeContourId == requestedContour && settings.jasperApiUrl.trim() != requestedUrl.trim()) {
        _saveActive(settings.copyWith(xsds: const [], xsdsFetchedAt: null));
      }
      _notice = _message(error, 'Не удалось получить список XSD.');
      _noticeIsError = true;
    } finally {
      _busyXsds = false;
      notifyListeners();
    }
  }

  Future<List<String>> listConsulModules() {
    _requireConsul();
    return consul_read.listConsulModuleSlugs(http: _http, consulUrl: settings.consulUrl, token: settings.consulToken);
  }

  Future<consul_read.ConsulModuleFolder> readConsulModule(String slug) {
    _requireConsul();
    return consul_read.readConsulModule(
      http: _http,
      consulUrl: settings.consulUrl,
      token: settings.consulToken,
      slug: slug,
    );
  }

  Future<void> uploadToConsul(ModuleFiles files) async {
    if (!settings.consulReady) {
      throw IntegrationException('Укажите URL и Token Consul.');
    }
    if (_busyUpload) return;
    _busyUpload = true;
    notifyListeners();
    try {
      await uploadModuleToConsul(http: _http, consulUrl: settings.consulUrl, token: settings.consulToken, files: files);
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

  Future<consul_read.ConsulFolderSnapshot?> inspectConsulModule(String slug) {
    _requireConsul();
    return consul_read.inspectConsulModule(
      http: _http,
      consulUrl: settings.consulUrl,
      token: settings.consulToken,
      slug: slug,
    );
  }

  void _requireConsul() {
    if (!settings.consulReady) {
      throw IntegrationException('Укажите URL и Token Consul.');
    }
  }

  Future<String?> _emptyXsdNotice(String requestedUrl, String? requestedContour) async {
    try {
      final rights = await fetchJasperRights(http: _http, apiUrl: requestedUrl, accessToken: settings.accessToken);
      if (!_sameContour(requestedContour, requestedUrl)) return null;
      return emptyXsdRightsMessage(rights);
    } catch (error) {
      if (activeContourId != requestedContour || settings.jasperApiUrl.trim() != requestedUrl.trim()) return null;
      return 'Список XSD пуст. ${_message(error, 'Права клиента запросить не удалось.')}';
    }
  }

  bool _sameContour(String? contourId, String requestedUrl) {
    return activeContourId == contourId && settings.jasperApiUrl.trim() == requestedUrl.trim() && settings.signedIn;
  }

  void _saveActive(IntegrationSettings next) {
    final active = _catalog.active;
    if (active == null) return;
    _catalog = _catalog.updating(active.id, settings: next);
    _store.write(_catalog);
  }

  void _rememberToken(JasperToken token, {bool keepRefresh = false}) {
    _saveActive(
      settings.copyWith(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken ?? (keepRefresh ? settings.refreshToken : ''),
        accessExpiresAt: token.expiresAt,
      ),
    );
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
