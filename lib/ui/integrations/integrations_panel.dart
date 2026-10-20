import 'package:flutter/material.dart';
import 'package:sodalite_configurator/integrations/integration_controller.dart';
import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/service_urls.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/draft_time.dart';
import 'package:sodalite_configurator/ui/integrations/integrations_scope.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';

Future<void> showIntegrationsDialog(BuildContext context, {VoidCallback? onUpload}) {
  final width = MediaQuery.sizeOf(context).width;
  final height = MediaQuery.sizeOf(context).height;
  return showSodaliteDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Интеграции'),
      content: SizedBox(
        width: width > 900 ? 720 : width - 96,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height * 0.62),
          child: SingleChildScrollView(child: IntegrationsPanel(embedded: true, onUpload: onUpload)),
        ),
      ),
      actions: [SodaliteButton.primary(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
    ),
  );
}

class IntegrationsPanel extends StatefulWidget {
  const IntegrationsPanel({super.key, this.embedded = false, this.onUpload});

  final bool embedded;
  final VoidCallback? onUpload;

  @override
  State<IntegrationsPanel> createState() => _IntegrationsPanelState();
}

class _FieldEntry {
  final controller = TextEditingController();
  final focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _IntegrationsPanelState extends State<IntegrationsPanel> {
  final _consulUrl = _FieldEntry();
  final _consulToken = _FieldEntry();
  final _jasperApi = _FieldEntry();
  final _identity = _FieldEntry();
  final _clientId = _FieldEntry();
  final _clientSecret = _FieldEntry();
  final _scope = _FieldEntry();
  final _visited = <String>{};
  IntegrationController? _bound;
  var _applying = false;
  var _revealToken = false;
  var _revealSecret = false;
  String? _attempt;

  @override
  void initState() {
    super.initState();
    _watch('consulUrl', _consulUrl.focus);
    _watch('jasperApiUrl', _jasperApi.focus);
    _watch('identityUrl', _identity.focus);
  }

  void _watch(String key, FocusNode focus) {
    focus.addListener(() {
      if (focus.hasFocus || !mounted) return;
      setState(() => _visited.add(key));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Integrations.read(context);
    if (identical(next, _bound)) return;
    _bound?.removeListener(_onStore);
    _bound = next;
    _bound?.addListener(_onStore);
    if (next != null) _syncFrom(next.settings);
  }

  @override
  void dispose() {
    _bound?.removeListener(_onStore);
    for (final field in [_consulUrl, _consulToken, _jasperApi, _identity, _clientId, _clientSecret, _scope]) {
      field.dispose();
    }
    super.dispose();
  }

  void _onStore() {
    final bound = _bound;
    if (bound == null || !mounted || _applying) return;
    _syncFrom(bound.settings);
    setState(() {});
  }

  void _syncFrom(IntegrationSettings settings) {
    _applying = true;
    _assign(_consulUrl, settings.consulUrl);
    _assign(_consulToken, settings.consulToken);
    _assign(_jasperApi, settings.jasperApiUrl);
    _assign(_identity, settings.identityUrl);
    _assign(_clientId, settings.clientId);
    _assign(_clientSecret, settings.clientSecret);
    _assign(_scope, settings.scope);
    _applying = false;
  }

  void _assign(_FieldEntry field, String value) {
    if (field.focus.hasFocus || field.controller.text == value) return;
    field.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _commit() {
    final bound = _bound;
    if (bound == null || _applying) return;
    bound.updateConnection(
      consulUrl: _consulUrl.controller.text,
      consulToken: _consulToken.controller.text,
      jasperApiUrl: _jasperApi.controller.text,
      identityUrl: _identity.controller.text,
      clientId: _clientId.controller.text,
      clientSecret: _clientSecret.controller.text,
      scope: _scope.controller.text,
    );
  }

  void _login() {
    _commit();
    setState(() => _attempt = 'jasper');
    final settings = _bound?.settings;
    if (settings == null) return;
    if (!looksLikeHttpUrl(settings.jasperApiUrl) ||
        !looksLikeHttpUrl(settings.identityUrl) ||
        settings.clientId.trim().isEmpty) {
      return;
    }
    _bound!.login();
  }

  void _upload() {
    _commit();
    setState(() => _attempt = 'consul');
    if (_bound?.settings.consulReady != true) return;
    widget.onUpload?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bound = _bound;
    if (bound == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary);
    final consul = _consulColumn(bound, body);
    final jasper = _jasperColumn(bound, body);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[Text('Интеграции', style: theme.textTheme.headlineSmall), const SizedBox(height: 8)],
        Text(
          'Адреса и ключи остаются в этом браузере и не попадают в ZIP. Без них модуль по-прежнему скачивается файлом.',
          style: body,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (widget.embedded || constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [consul, const SizedBox(height: 32), jasper],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: consul),
                const SizedBox(width: 32),
                Expanded(child: jasper),
              ],
            );
          },
        ),
        if (bound.notice case final notice?) ...[
          const SizedBox(height: 16),
          Text(
            notice,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bound.noticeIsError ? SodaliteColors.errorText : SodaliteColors.secondary,
            ),
          ),
        ],
      ],
    );
    if (widget.embedded) return content;
    return Card(
      key: const Key('integrationsPanel'),
      child: Padding(padding: const EdgeInsets.all(32), child: content),
    );
  }

  Widget _consulColumn(IntegrationController bound, TextStyle? body) {
    final attempted = _attempt == 'consul';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Consul', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Кнопка «В Consul» в редакторе записывает готовый модуль одним сохранением. Незаконченный модуль туда не уходит.',
          style: body,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _consulUrl,
          fieldKey: 'consulUrl',
          label: 'Адрес Consul',
          example: 'Например, http://127.0.0.1:8500',
          error: _urlError(
            'consulUrl',
            _consulUrl.controller.text,
            showEmpty: attempted,
            example: 'Например, http://127.0.0.1:8500',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _consulToken,
          fieldKey: 'consulToken',
          label: 'Ключ API Consul',
          example: 'Например, 11111111-2222-3333-4444-555555555555',
          error: attempted && _consulToken.controller.text.trim().isEmpty
              ? 'Укажите ключ API. Например, 11111111-2222-3333-4444-555555555555'
              : null,
          obscure: !_revealToken,
          onToggleObscure: () => setState(() => _revealToken = !_revealToken),
          revealTooltip: _revealToken ? 'Скрыть ключ' : 'Показать ключ',
        ),
        const SizedBox(height: 12),
        Text(bound.settings.consulReady ? 'Адрес и ключ заданы' : 'Адрес или ключ пока не заданы', style: body),
        if (widget.onUpload != null) ...[
          const SizedBox(height: 16),
          SodaliteButton.secondary(
            key: const Key('uploadConsul'),
            onPressed: bound.busyUpload ? null : _upload,
            child: const Text('Загрузить в Consul'),
          ),
        ],
      ],
    );
  }

  Widget _jasperColumn(IntegrationController bound, TextStyle? body) {
    final attempted = _attempt == 'jasper';
    final redirect = bound.redirectUri;
    final busy = bound.busyLogin || bound.busyRefresh || bound.busyXsds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jasper', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Вход открывает Identity и возвращает сюда. Токен обновляется отдельной кнопкой.', style: body),
        const SizedBox(height: 16),
        _textField(
          entry: _jasperApi,
          fieldKey: 'jasperApiUrl',
          label: 'Адрес Jasper',
          example: 'Например, https://jasper.example.com',
          error: _urlError(
            'jasperApiUrl',
            _jasperApi.controller.text,
            showEmpty: attempted,
            example: 'Например, https://jasper.example.com',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _identity,
          fieldKey: 'identityUrl',
          label: 'Адрес Identity',
          example: 'Например, https://identity.example.com',
          error: _urlError(
            'identityUrl',
            _identity.controller.text,
            showEmpty: attempted,
            example: 'Например, https://identity.example.com',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _clientId,
          fieldKey: 'jasperClientId',
          label: 'Идентификатор клиента',
          example: 'Например, sodalite-configurator',
          error: attempted && _clientId.controller.text.trim().isEmpty
              ? 'Укажите идентификатор клиента. Например, sodalite-configurator'
              : null,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _scope,
          fieldKey: 'jasperScope',
          label: 'Область доступа',
          example: 'Например, jasper_api offline_access',
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _clientSecret,
          fieldKey: 'jasperClientSecret',
          label: 'Секрет клиента',
          example: 'Необязательно. Например, секрет закрытого клиента Identity',
          obscure: !_revealSecret,
          onToggleObscure: () => setState(() => _revealSecret = !_revealSecret),
          revealTooltip: _revealSecret ? 'Скрыть секрет' : 'Показать секрет',
        ),
        if (redirect.isNotEmpty) ...[
          const SizedBox(height: 12),
          SelectableText('Адрес возврата для клиента Identity: $redirect', style: body),
        ],
        const SizedBox(height: 12),
        Text(_jasperStatus(bound.settings), style: body),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SodaliteButton.primary(
              key: const Key('loginJasper'),
              onPressed: bound.busyLogin ? null : _login,
              child: const Text('Войти'),
            ),
            SodaliteButton.ghost(
              key: const Key('refreshJasperToken'),
              onPressed: busy ? null : () => bound.refreshAccessToken(),
              child: const Text('Обновить токен'),
            ),
            SodaliteButton.secondary(
              key: const Key('refreshXsds'),
              onPressed: busy ? null : () => bound.refreshXsds(),
              child: const Text('Обновить список XSD'),
            ),
            if (bound.settings.signedIn || bound.settings.refreshToken.isNotEmpty)
              SodaliteButton.ghost(
                key: const Key('logoutJasper'),
                onPressed: bound.busyLogin ? null : bound.logout,
                child: const Text('Выйти'),
              ),
          ],
        ),
      ],
    );
  }

  String? _urlError(String key, String value, {required bool showEmpty, required String example}) {
    final show = showEmpty || _visited.contains(key);
    if (!show) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return showEmpty ? 'Укажите адрес. $example' : null;
    if (!looksLikeHttpUrl(trimmed)) return 'Нужен адрес http или https. $example';
    return null;
  }

  Widget _textField({
    required _FieldEntry entry,
    required String fieldKey,
    required String label,
    required String example,
    String? error,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    String? revealTooltip,
    TextInputType? keyboardType,
  }) {
    return TextField(
      key: Key(fieldKey),
      controller: entry.controller,
      focusNode: entry.focus,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: keyboardType,
      onChanged: (_) => _commit(),
      decoration: InputDecoration(
        labelText: label,
        helperText: error == null ? example : null,
        helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
        errorText: error,
        suffixIcon: onToggleObscure == null
            ? null
            : SodaliteIconButton(
                tooltip: revealTooltip ?? '',
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
      ),
    );
  }
}

String _jasperStatus(IntegrationSettings settings) {
  if (!settings.signedIn) return 'Вход не выполнен';
  final expiry = settings.accessExpiresAt;
  final until = expiry == null ? 'срок не указан' : 'до ${formatDraftWhen(expiry)}';
  if (settings.xsds.isEmpty) return 'Вход выполнен, $until. Список XSD ещё не получен.';
  final fetched = settings.xsdsFetchedAt == null ? '' : ', обновлён ${formatDraftWhen(settings.xsdsFetchedAt!)}';
  return 'Вход выполнен, $until. XSD: ${settings.xsds.length}$fetched.';
}
