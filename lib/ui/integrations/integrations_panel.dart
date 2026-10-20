import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sodalite_configurator/integrations/integration_controller.dart';
import 'package:sodalite_configurator/integrations/integration_settings.dart';
import 'package:sodalite_configurator/integrations/service_urls.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/draft_time.dart';
import 'package:sodalite_configurator/ui/integrations/integrations_scope.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';
import 'package:sodalite_configurator/ui/sodalite_select.dart';
import 'package:sodalite_configurator/ui/sodalite_toast.dart';

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
  String? _seenContour;
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
    if (next != null) {
      _seenContour = next.activeContourId;
      _syncFrom(next.settings, force: true);
    }
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
    final force = bound.activeContourId != _seenContour;
    _seenContour = bound.activeContourId;
    if (force) {
      _attempt = null;
      _visited.clear();
    }
    _syncFrom(bound.settings, force: force);
    setState(() {});
  }

  void _syncFrom(IntegrationSettings settings, {required bool force}) {
    _applying = true;
    _assign(_consulUrl, settings.consulUrl, force: force);
    _assign(_consulToken, settings.consulToken, force: force);
    _assign(_jasperApi, settings.jasperApiUrl, force: force);
    _assign(_identity, settings.identityUrl, force: force);
    _assign(_clientId, settings.clientId, force: force);
    _assign(_clientSecret, settings.clientSecret, force: force);
    _assign(_scope, settings.scope, force: force);
    _applying = false;
  }

  void _assign(_FieldEntry field, String value, {required bool force}) {
    if (!force && (field.focus.hasFocus || field.controller.text == value)) return;
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
        _contourBar(bound, body),
        if (bound.activeContourId != null) ...[const SizedBox(height: 24), _connection(bound, body)],
      ],
    );
    if (widget.embedded) return content;
    return Card(
      key: const Key('integrationsPanel'),
      child: Padding(padding: const EdgeInsets.all(32), child: content),
    );
  }

  Widget _connection(IntegrationController bound, TextStyle? body) {
    final consul = _consulColumn(bound, body);
    final jasper = _jasperColumn(bound, body);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
  }

  Widget _contourBar(IntegrationController bound, TextStyle? body) {
    final active = bound.activeContourId;
    final names = {for (final contour in bound.contours) contour.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Контур', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('У каждого контура свои URL, Token и вход в Jasper. Модуль от этого не меняется.', style: body),
        const SizedBox(height: 16),
        if (bound.contours.isNotEmpty)
          SodaliteSelect<String>(
            key: const Key('contourSelect'),
            value: active,
            values: [for (final contour in bound.contours) contour.id],
            labelOf: (id) {
              for (final contour in bound.contours) {
                if (contour.id == id) return contour.name;
              }
              return id;
            },
            decoration: const InputDecoration(labelText: 'Текущий контур'),
            onChanged: (id) {
              if (id != null) bound.selectContour(id);
            },
          ),
        if (bound.contours.isEmpty)
          Text('Контуров пока нет. Добавьте первый, чтобы задать Consul и Jasper.', style: body),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SodaliteButton.secondary(
              key: const Key('addContour'),
              onPressed: () => _addContour(names),
              child: const Text('Добавить'),
            ),
            SodaliteButton.ghost(
              key: const Key('renameContour'),
              onPressed: active == null ? null : () => _renameContour(bound, names),
              child: const Text('Переименовать'),
            ),
            SodaliteButton.ghost(
              key: const Key('deleteContour'),
              onPressed: active == null ? null : () => _deleteContour(bound),
              child: const Text('Удалить'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addContour(Set<String> names) async {
    final name = await _askContourName(title: 'Новый контур', taken: names);
    if (name == null) return;
    _bound?.addContour(name);
  }

  Future<void> _renameContour(IntegrationController bound, Set<String> names) async {
    final active = bound.activeContourId;
    final current = bound.activeContourName;
    if (active == null || current == null) return;
    final name = await _askContourName(
      title: 'Переименовать контур',
      initial: current,
      taken: names.difference({current}),
    );
    if (name == null) return;
    bound.renameContour(active, name);
  }

  Future<void> _deleteContour(IntegrationController bound) async {
    final active = bound.activeContourId;
    final name = bound.activeContourName;
    if (active == null || name == null) return;
    final confirmed = await showSodaliteDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить контур?'),
        content: SizedBox(
          width: 440,
          child: Text('Контур «$name» и его URL, Token и вход в Jasper будут удалены из этого браузера.'),
        ),
        actions: [
          SodaliteButton.secondary(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          SodaliteButton.destructive(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) bound.deleteContour(active);
  }

  Future<String?> _askContourName({required String title, String initial = '', required Set<String> taken}) {
    return showSodaliteDialog<String>(
      context: context,
      builder: (context) => _ContourNameDialog(title: title, initial: initial, taken: taken),
    );
  }

  Future<void> _copyCallback(String redirect) async {
    try {
      await Clipboard.setData(ClipboardData(text: redirect));
    } catch (_) {
      if (!mounted) return;
      SodaliteToast.show(context, message: 'Не удалось скопировать Callback URL');
      return;
    }
    if (!mounted) return;
    SodaliteToast.show(context, message: 'Callback URL скопирован');
  }

  Widget _consulColumn(IntegrationController bound, TextStyle? body) {
    final attempted = _attempt == 'consul';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Consul', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Кнопка «В Consul» в редакторе записывает готовый модуль одним сохранением. «Из Consul» на главной читает папку apps/{идентификатор}/ в черновик. Незаконченный модуль в Consul не уходит.',
          style: body,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _consulUrl,
          fieldKey: 'consulUrl',
          label: 'URL',
          example: 'Например, http://127.0.0.1:8500',
          error: _urlError(
            'consulUrl',
            _consulUrl.controller.text,
            showEmpty: attempted,
            label: 'URL',
            example: 'Например, http://127.0.0.1:8500',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _consulToken,
          fieldKey: 'consulToken',
          label: 'Token',
          example: 'Например, 11111111-2222-3333-4444-555555555555',
          error: attempted && _consulToken.controller.text.trim().isEmpty
              ? 'Укажите Token. Например, 11111111-2222-3333-4444-555555555555'
              : null,
          obscure: !_revealToken,
          onToggleObscure: () => setState(() => _revealToken = !_revealToken),
          revealTooltip: _revealToken ? 'Скрыть Token' : 'Показать Token',
        ),
        const SizedBox(height: 12),
        Text(bound.settings.consulReady ? 'URL и Token заданы' : 'URL или Token пока не заданы', style: body),
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
        Text(
          'Имена полей как в Postman. Auth URL можно вставить целиком: Access Token URL с того же сервера подставится сам.',
          style: body,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _jasperApi,
          fieldKey: 'jasperApiUrl',
          label: 'Base URL',
          example: 'Например, https://jasper.example.com',
          error: _urlError(
            'jasperApiUrl',
            _jasperApi.controller.text,
            showEmpty: attempted,
            label: 'Base URL',
            example: 'Например, https://jasper.example.com',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _identity,
          fieldKey: 'identityUrl',
          label: 'Auth URL',
          example: 'Например, https://identity.example.com/connect/authorize',
          error: _urlError(
            'identityUrl',
            _identity.controller.text,
            showEmpty: attempted,
            label: 'Auth URL',
            example: 'Например, https://identity.example.com/connect/authorize',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _clientId,
          fieldKey: 'jasperClientId',
          label: 'Client ID',
          example: 'Например, sodalite-configurator',
          error: attempted && _clientId.controller.text.trim().isEmpty
              ? 'Укажите Client ID. Например, sodalite-configurator'
              : null,
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _clientSecret,
          fieldKey: 'jasperClientSecret',
          label: 'Client Secret',
          example: 'Необязательно. Например, секрет закрытого клиента',
          obscure: !_revealSecret,
          onToggleObscure: () => setState(() => _revealSecret = !_revealSecret),
          revealTooltip: _revealSecret ? 'Скрыть Client Secret' : 'Показать Client Secret',
        ),
        const SizedBox(height: 16),
        _textField(
          entry: _scope,
          fieldKey: 'jasperScope',
          label: 'Scope',
          example: 'Например, jasper_api offline_access',
        ),
        if (redirect.isNotEmpty) ...[
          const SizedBox(height: 12),
          SelectableText('Callback URL: $redirect', style: body),
          const SizedBox(height: 8),
          SodaliteButton.ghost(
            key: const Key('copyCallbackUrl'),
            onPressed: () => _copyCallback(redirect),
            child: const Text('Скопировать'),
          ),
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

  String? _urlError(
    String key,
    String value, {
    required bool showEmpty,
    required String label,
    required String example,
  }) {
    final show = showEmpty || _visited.contains(key);
    if (!show) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return showEmpty ? 'Укажите $label. $example' : null;
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

class _ContourNameDialog extends StatefulWidget {
  const _ContourNameDialog({required this.title, required this.initial, required this.taken});

  final String title;
  final String initial;
  final Set<String> taken;

  @override
  State<_ContourNameDialog> createState() => _ContourNameDialogState();
}

class _ContourNameDialogState extends State<_ContourNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  bool get _taken => widget.taken.contains(_name);

  bool get _valid => _name.isNotEmpty && !_taken;

  void _submit() {
    if (_valid) Navigator.of(context).pop(_name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Имя контура',
            hintText: 'Например, тест',
            helperText: _name.isEmpty || !_taken ? 'Например, тест или прод' : null,
            errorText: _taken ? 'Контур с таким именем уже есть. Например, тест-2' : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        SodaliteButton.secondary(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        SodaliteButton.primary(onPressed: _valid ? _submit : null, child: const Text('Сохранить')),
      ],
    );
  }
}
