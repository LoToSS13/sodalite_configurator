import 'package:sodalite_configurator/ui/sodalite_buttons.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/codec/import_files.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/sample/example_module.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/draft_time.dart';
import 'package:sodalite_configurator/ui/editor/editor_page.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/sodalite_search_field.dart';
import 'package:sodalite_configurator/ui/integrations/integrations_panel.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';

typedef PickZipBytesFn = Future<List<int>?> Function();
typedef PickJsonFilesFn = Future<Map<String, String>?> Function();

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.download, this.pickZipBytes, this.pickJsonFiles, this.drafts});

  final DownloadFn download;
  final PickZipBytesFn? pickZipBytes;
  final PickJsonFilesFn? pickJsonFiles;
  final DraftStore? drafts;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DraftStore _drafts;
  late Future<List<DraftMeta>> _listed;
  String _query = '';
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.drafts ?? createDraftStore();
    _reloadDrafts();
  }

  void _reloadDrafts() {
    _listed = _drafts.list();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SodaliteBrand(),
        titleSpacing: 32,
        actions: [
          if (MediaQuery.sizeOf(context).width > 600)
            const Padding(
              padding: EdgeInsets.only(right: 32),
              child: StatusPill(label: 'Локальная работа', icon: Icons.computer_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            children: [
              Text('Модули', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Настройте слои, карточки объектов и\u00a0поиск для Sodalite',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SodaliteColors.secondary),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('С чего начнём?', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте модуль, откройте пример или\u00a0готовую конфигурацию',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SodaliteButton.primary(onPressed: _createModule, label: const Text(UiStrings.createModule)),
                          SodaliteButton.secondary(
                            onPressed: _openExample,
                            icon: const Icon(Icons.auto_stories_outlined, size: 20),
                            label: const Text('Открыть пример'),
                          ),
                          SodaliteButton.secondary(
                            onPressed: _openZip,
                            icon: const Icon(Icons.folder_open_outlined, size: 20),
                            label: const Text(UiStrings.openZip),
                          ),
                          SodaliteButton.ghost(
                            onPressed: _openJson,
                            icon: const Icon(Icons.data_object, size: 20),
                            label: const Text(UiStrings.openJson),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Пример «Городские объекты» уже заполнен: пути, подстановки в\u00a0фигурных скобках, поиск и\u00a0создание объектов.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const IntegrationsPanel(),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Text(UiStrings.draftsHeading, style: Theme.of(context).textTheme.headlineSmall);
                  final search = SodaliteSearchField(
                    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [heading, const SizedBox(height: 16), search],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: heading),
                      SizedBox(width: 360, child: search),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Черновики только в\u00a0этом браузере. Другое устройство, другой браузер и\u00a0очистка данных сайта их\u00a0не\u00a0увидят.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<DraftMeta>>(
                future: _listed,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _EmptyDrafts(
                      icon: Icons.error_outline,
                      title: 'Не удалось загрузить черновики',
                      message: 'Попробуйте открыть список ещё раз',
                      action: SodaliteButton.ghost(
                        onPressed: () => setState(_reloadDrafts),
                        child: const Text('Повторить'),
                      ),
                    );
                  }
                  final drafts = (snapshot.data ?? const <DraftMeta>[])
                      .where((draft) => '${draft.title} ${draft.slug}'.toLowerCase().contains(_query))
                      .toList();
                  if (drafts.isEmpty) {
                    return _EmptyDrafts(
                      icon: _query.isEmpty ? Icons.layers_outlined : Icons.search,
                      title: _query.isEmpty ? 'Здесь будут ваши модули' : 'Модули не найдены',
                      message: _query.isEmpty
                          ? 'Создайте модуль или\u00a0откройте пример, чтобы он\u00a0появился в\u00a0списке'
                          : 'Попробуйте другое название или\u00a0идентификатор',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final draft in drafts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SodalitePress(
                            whiteOverlay: false,
                            builder: (states) => Theme(
                              data: Theme.of(context).copyWith(
                                highlightColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                splashFactory: NoSplash.splashFactory,
                              ),
                              child: ListenableBuilder(
                                listenable: states,
                                builder: (context, _) => Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color: states.value.contains(WidgetState.focused)
                                          ? SodaliteColors.accent
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ListTile(
                                    statesController: states,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: SodaliteColors.accentSubdued,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.layers_outlined, color: SodaliteColors.accent),
                                    ),
                                    title: Text(draft.title, style: Theme.of(context).textTheme.titleMedium),
                                    subtitle: Text('${draft.slug} · ${formatDraftWhen(draft.updatedAt)}'),
                                    onTap: () => _openDraft(draft.slug),
                                    trailing: SodaliteIconButton(
                                      tooltip: UiStrings.deleteDraft,
                                      onPressed: () => _deleteDraft(draft.slug),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Когда модуль будет готов, скачайте ZIP с\u00a0конфигурацией',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createModule() async {
    final taken = {for (final draft in await _drafts.list()) draft.slug};
    if (!mounted) {
      return;
    }
    final slug = await showSodaliteDialog<String>(
      context: context,
      builder: (context) => _SlugDialog(takenSlugs: taken),
    );
    if (slug == null || !mounted) {
      return;
    }
    await _openEditor(
      DocumentController(
        catalog: Catalog.modulePack(),
        root: newModuleBundle(slug: slug, id: newNodeId),
        drafts: _drafts,
        draftAlreadySaved: false,
      ),
    );
  }

  Future<void> _openExample() async {
    final example = createExampleModule();
    if (!mounted) return;
    final root = await _resolveImportedDraft(example.root);
    if (root == null || !mounted) return;
    try {
      await _drafts.save(root);
    } catch (_) {
      await _showImportError(
        'Не удалось сохранить пример в этом браузере. Проверьте доступность хранилища и попробуйте ещё раз.',
      );
      return;
    }
    if (!mounted) return;
    await _openEditor(
      DocumentController(catalog: Catalog.modulePack(), root: root, drafts: _drafts, importWarnings: example.warnings),
    );
  }

  Future<void> _openZip() => _importModule(() async {
    final bytes = await (widget.pickZipBytes ?? _pickZipBytes)();
    return bytes == null ? null : importZip(bytes, id: newNodeId);
  });

  Future<void> _openJson() => _importModule(() async {
    final files = await (widget.pickJsonFiles ?? _pickJsonFiles)();
    return files == null ? null : importLooseFiles(files, id: newNodeId);
  });

  Future<void> _showImportError(String message) async {
    if (!mounted) return;
    await showSodaliteDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(UiStrings.importFailed),
        scrollable: true,
        content: SelectableText(message),
        actions: [SodaliteButton.primary(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
      ),
    );
  }

  Future<void> _importModule(Future<ImportResult?> Function() read) async {
    if (_importing) return;
    _importing = true;
    try {
      final result = await read();
      if (result == null || !mounted) return;
      if (result.bundle == null) {
        await _showImportError(result.errors.join('\n'));
        return;
      }
      final root = await _resolveImportedDraft(result.bundle!);
      if (root == null || !mounted) return;
      // No controller (and therefore no autosave) exists before collision resolution.
      try {
        await _drafts.save(root);
      } catch (_) {
        await _showImportError(
          'Не удалось сохранить импортированный модуль в этом браузере. '
          'Проверьте доступность хранилища и попробуйте ещё раз.',
        );
        return;
      }
      if (!mounted) return;
      await _openEditor(
        DocumentController(
          catalog: Catalog.modulePack(),
          root: root,
          drafts: _drafts,
          importWarnings: result.warnings,
          importErrors: result.errors,
        ),
      );
    } on FormatException catch (error) {
      await _showImportError(error.message);
    } catch (_) {
      await _showImportError('Не удалось прочитать файлы или хранилище черновиков. Попробуйте открыть модуль ещё раз.');
    } finally {
      _importing = false;
    }
  }

  Future<Node?> _resolveImportedDraft(Node root) async {
    final slug = root.fields['slug'] as String;
    if (await _drafts.load(slug) == null) return root;
    if (!mounted) return null;
    final choice = await showSodaliteDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Черновик уже существует'),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: Text(
            'В этом браузере уже есть модуль «$slug». '
            'Откройте копию с новым идентификатором или замените сохранённый черновик. '
            'При замене его текущие настройки будут потеряны.',
          ),
        ),
        actions: [
          SodaliteButton.secondary(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          SodaliteButton.ghost(
            onPressed: () => Navigator.pop(context, 'replace'),
            style: const ButtonStyle(foregroundColor: WidgetStatePropertyAll(SodaliteColors.errorText)),
            child: const Text('Заменить'),
          ),
          SodaliteButton.primary(onPressed: () => Navigator.pop(context, 'copy'), child: const Text('Открыть копию')),
        ],
      ),
    );
    if (choice == null || !mounted) return null;
    if (choice == 'replace') return root;
    var candidate = '$slug-copy';
    var suffix = 2;
    while (await _drafts.load(candidate) != null) {
      candidate = '$slug-copy-${suffix++}';
    }
    return root.copyWith(fields: {...root.fields, 'slug': candidate});
  }

  Future<void> _openDraft(String slug) async {
    final root = await _drafts.load(slug);
    if (root == null || !mounted) {
      return;
    }
    await _openEditor(DocumentController(catalog: Catalog.modulePack(), root: root, drafts: _drafts));
  }

  Future<void> _deleteDraft(String slug) async {
    final confirmed = await showSodaliteDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить черновик?'),
        content: Text('Черновик «$slug» будет удалён из этого браузера. Скачанные ZIP-файлы останутся'),
        actions: [
          SodaliteButton.secondary(onPressed: () => Navigator.pop(context, false), child: const Text(UiStrings.cancel)),
          SodaliteButton.destructive(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить черновик'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _drafts.delete(slug);
    if (!mounted) {
      return;
    }
    setState(_reloadDrafts);
  }

  Future<void> _openEditor(DocumentController controller) async {
    if (!mounted) {
      controller.dispose();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(controller: controller, download: widget.download, ownsController: true),
      ),
    );
    if (mounted) {
      setState(_reloadDrafts);
    }
  }
}

Future<List<int>?> _pickZipBytes() async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
    withData: true,
  );
  return picked?.files.single.bytes;
}

Future<Map<String, String>?> _pickJsonFiles() async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    allowMultiple: true,
    withData: true,
  );
  if (picked == null) {
    return null;
  }
  final contents = <String, String>{};
  for (final file in picked.files) {
    final bytes = file.bytes;
    if (bytes == null) throw FormatException('Не удалось прочитать файл «${file.name}». Выберите его ещё раз.');
    contents[file.name] = decodeImportText(file.name, bytes);
  }
  return contents;
}

class _SlugDialog extends StatefulWidget {
  const _SlugDialog({this.takenSlugs = const {}});

  final Set<String> takenSlugs;

  @override
  State<_SlugDialog> createState() => _SlugDialogState();
}

class _SlugDialogState extends State<_SlugDialog> {
  final TextEditingController _controller = TextEditingController();
  static final RegExp _pattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _slug => _controller.text.trim();

  bool get _taken => widget.takenSlugs.contains(_slug);

  bool get _valid => _pattern.hasMatch(_slug) && !_taken;

  void _submit() {
    if (!_valid) {
      return;
    }
    Navigator.of(context).pop(_slug);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(UiStrings.createModule),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Задайте идентификатор — он\u00a0станет именем папки модуля'),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: UiStrings.pathLabel('slug'),
                hintText: 'Например, city_objects',
                helperText: 'Строчные латинские буквы, цифры, дефис и\u00a0нижнее подчёркивание',
                errorText: _taken ? UiStrings.slugTaken : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        SodaliteButton.secondary(onPressed: () => Navigator.pop(context), child: const Text(UiStrings.cancel)),
        SodaliteButton.primary(onPressed: _valid ? _submit : null, child: const Text(UiStrings.createModule)),
      ],
    );
  }
}

class _EmptyDrafts extends StatelessWidget {
  const _EmptyDrafts({required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: SodaliteColors.canvas, borderRadius: BorderRadius.circular(24)),
            child: Icon(icon, size: 32, color: SodaliteColors.icon),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
