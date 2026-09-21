import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/codec/import_files.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/editor_page.dart';
import 'package:sodalite_configurator/ui/strings.dart';

typedef PickZipBytesFn = Future<List<int>?> Function();

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.download, this.pickZipBytes, this.drafts});

  final DownloadFn download;
  final PickZipBytesFn? pickZipBytes;
  final DraftStore? drafts;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DraftStore _drafts;
  late Future<List<DraftMeta>> _listed;

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
      appBar: AppBar(title: const Text('Sodalite Configurator')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton(onPressed: _createModule, child: const Text(UiStrings.createModule)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _openZip, child: const Text(UiStrings.openZip)),
              const SizedBox(height: 24),
              FutureBuilder<List<DraftMeta>>(
                future: _listed,
                builder: (context, snapshot) {
                  final drafts = snapshot.data ?? const <DraftMeta>[];
                  if (drafts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(UiStrings.draftsHeading, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final draft in drafts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(draft.title),
                          subtitle: Text('${draft.slug} · ${draft.updatedAt.toLocal()}'),
                          onTap: () => _openDraft(draft.slug),
                          trailing: IconButton(
                            tooltip: UiStrings.deleteDraft,
                            onPressed: () => _deleteDraft(draft.slug),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createModule() async {
    final slug = await showDialog<String>(context: context, builder: (context) => const _SlugDialog());
    if (slug == null || !mounted) {
      return;
    }
    await _openEditor(
      DocumentController(
        catalog: Catalog.modulePack(),
        root: newModuleBundle(slug: slug, id: newNodeId),
        drafts: _drafts,
      ),
    );
  }

  Future<void> _openZip() async {
    final bytes = await (widget.pickZipBytes ?? _pickZipBytes)();
    if (bytes == null || !mounted) {
      return;
    }

    final result = importZip(bytes, id: newNodeId);
    if (result.bundle == null) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(UiStrings.importFailed),
          content: Text(result.errors.join('\n')),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
      return;
    }

    await _openEditor(
      DocumentController(
        catalog: Catalog.modulePack(),
        root: result.bundle!,
        drafts: _drafts,
        importWarnings: result.warnings,
        importErrors: result.errors,
      ),
    );
  }

  Future<void> _openDraft(String slug) async {
    final root = await _drafts.load(slug);
    if (root == null || !mounted) {
      return;
    }
    await _openEditor(DocumentController(catalog: Catalog.modulePack(), root: root, drafts: _drafts));
  }

  Future<void> _deleteDraft(String slug) async {
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

class _SlugDialog extends StatefulWidget {
  const _SlugDialog();

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

  bool get _valid => _pattern.hasMatch(_controller.text.trim());

  void _submit() {
    if (!_valid) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(UiStrings.createModule),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: UiStrings.pathLabel('slug')),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [TextButton(onPressed: _valid ? _submit : null, child: const Text('OK'))],
    );
  }
}
