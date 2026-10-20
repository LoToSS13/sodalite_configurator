import 'dart:convert';

import 'package:sodalite_configurator/integrations/service_urls.dart';

class XsdEntry {
  const XsdEntry({required this.value, required this.label});

  final String value;
  final String label;

  Map<String, String> toJson() => {'value': value, 'label': label};

  static XsdEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final value = json['value'];
    if (value is! String || value.trim().isEmpty) return null;
    final label = json['label'];
    return XsdEntry(
      value: value.trim(),
      label: label is String && label.trim().isNotEmpty ? label.trim() : value.trim(),
    );
  }
}

class IntegrationSettings {
  const IntegrationSettings({
    this.consulUrl = '',
    this.consulToken = '',
    this.jasperApiUrl = '',
    this.identityUrl = '',
    this.clientId = '',
    this.clientSecret = '',
    this.scope = '',
    this.accessToken = '',
    this.refreshToken = '',
    this.accessExpiresAt,
    this.xsds = const [],
    this.xsdsFetchedAt,
  });

  static const empty = IntegrationSettings();

  final String consulUrl;
  final String consulToken;
  final String jasperApiUrl;
  final String identityUrl;
  final String clientId;
  final String clientSecret;
  final String scope;
  final String accessToken;
  final String refreshToken;
  final DateTime? accessExpiresAt;
  final List<XsdEntry> xsds;
  final DateTime? xsdsFetchedAt;

  bool get consulReady => looksLikeHttpUrl(consulUrl) && consulToken.trim().isNotEmpty;

  bool get signedIn => accessToken.trim().isNotEmpty;

  IntegrationSettings copyWith({
    String? consulUrl,
    String? consulToken,
    String? jasperApiUrl,
    String? identityUrl,
    String? clientId,
    String? clientSecret,
    String? scope,
    String? accessToken,
    String? refreshToken,
    Object? accessExpiresAt = _keep,
    List<XsdEntry>? xsds,
    Object? xsdsFetchedAt = _keep,
  }) {
    return IntegrationSettings(
      consulUrl: consulUrl ?? this.consulUrl,
      consulToken: consulToken ?? this.consulToken,
      jasperApiUrl: jasperApiUrl ?? this.jasperApiUrl,
      identityUrl: identityUrl ?? this.identityUrl,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      scope: scope ?? this.scope,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessExpiresAt: identical(accessExpiresAt, _keep) ? this.accessExpiresAt : accessExpiresAt as DateTime?,
      xsds: xsds ?? this.xsds,
      xsdsFetchedAt: identical(xsdsFetchedAt, _keep) ? this.xsdsFetchedAt : xsdsFetchedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'consulUrl': consulUrl,
    'consulToken': consulToken,
    'jasperApiUrl': jasperApiUrl,
    'identityUrl': identityUrl,
    'clientId': clientId,
    'clientSecret': clientSecret,
    'scope': scope,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt?.toUtc().toIso8601String(),
    'xsds': [for (final entry in xsds) entry.toJson()],
    'xsdsFetchedAt': xsdsFetchedAt?.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static IntegrationSettings _fromMap(Map<dynamic, dynamic> decoded) {
    return IntegrationSettings(
      consulUrl: _string(decoded['consulUrl']),
      consulToken: _string(decoded['consulToken']),
      jasperApiUrl: _string(decoded['jasperApiUrl']),
      identityUrl: _string(decoded['identityUrl']),
      clientId: _string(decoded['clientId']),
      clientSecret: _string(decoded['clientSecret']),
      scope: _string(decoded['scope']),
      accessToken: _string(decoded['accessToken']),
      refreshToken: _string(decoded['refreshToken']),
      accessExpiresAt: _date(decoded['accessExpiresAt']),
      xsds: [
        for (final item in decoded['xsds'] is List ? decoded['xsds'] as List : const [])
          if (XsdEntry.fromJson(item) case final entry?) entry,
      ],
      xsdsFetchedAt: _date(decoded['xsdsFetchedAt']),
    );
  }
}

class IntegrationContour {
  const IntegrationContour({required this.id, required this.name, required this.settings});

  final String id;
  final String name;
  final IntegrationSettings settings;

  IntegrationContour copyWith({String? name, IntegrationSettings? settings}) {
    return IntegrationContour(id: id, name: name ?? this.name, settings: settings ?? this.settings);
  }

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'settings': settings.toJson()};

  static IntegrationContour? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final settings = json['settings'];
    if (id is! String || id.trim().isEmpty || name is! String || name.trim().isEmpty || settings is! Map) return null;
    return IntegrationContour(id: id.trim(), name: name.trim(), settings: IntegrationSettings._fromMap(settings));
  }
}

class IntegrationCatalog {
  const IntegrationCatalog({required this.activeId, required this.contours});

  final String? activeId;
  final List<IntegrationContour> contours;

  static const empty = IntegrationCatalog(activeId: null, contours: []);

  IntegrationContour? get active {
    for (final contour in contours) {
      if (contour.id == activeId) return contour;
    }
    return null;
  }

  IntegrationSettings get settings => active?.settings ?? IntegrationSettings.empty;

  IntegrationCatalog select(String id) => IntegrationCatalog(activeId: id, contours: contours);

  IntegrationCatalog add(IntegrationContour contour) {
    return IntegrationCatalog(activeId: contour.id, contours: [...contours, contour]);
  }

  IntegrationCatalog remove(String id) {
    final next = [
      for (final contour in contours)
        if (contour.id != id) contour,
    ];
    final nextActive = activeId == id ? (next.isEmpty ? null : next.first.id) : activeId;
    return IntegrationCatalog(activeId: nextActive, contours: next);
  }

  IntegrationCatalog updating(String id, {String? name, IntegrationSettings? settings}) {
    return IntegrationCatalog(
      activeId: activeId,
      contours: [
        for (final contour in contours)
          if (contour.id == id) contour.copyWith(name: name, settings: settings) else contour,
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'activeId': activeId,
    'contours': [for (final contour in contours) contour.toJson()],
  };

  String encode() => jsonEncode(toJson());

  static IntegrationCatalog decode(String? raw) {
    if (raw == null || raw.isEmpty) return _initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _initial();
      if (decoded['contours'] is List) {
        final contours = <IntegrationContour>[
          for (final item in decoded['contours'] as List)
            if (IntegrationContour.fromJson(item) case final contour?) contour,
        ];
        if (contours.isEmpty) return empty;
        final requested = decoded['activeId'];
        final activeId = requested is String && contours.any((contour) => contour.id == requested)
            ? requested
            : contours.first.id;
        return IntegrationCatalog(activeId: activeId, contours: contours);
      }
      return IntegrationCatalog(
        activeId: 'contour-1',
        contours: [
          IntegrationContour(id: 'contour-1', name: 'Контур 1', settings: IntegrationSettings._fromMap(decoded)),
        ],
      );
    } catch (_) {
      return _initial();
    }
  }

  static IntegrationCatalog _initial() {
    return const IntegrationCatalog(
      activeId: 'contour-1',
      contours: [IntegrationContour(id: 'contour-1', name: 'Контур 1', settings: IntegrationSettings.empty)],
    );
  }
}

const _keep = Object();

String _string(Object? value) => value is String ? value : '';

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
