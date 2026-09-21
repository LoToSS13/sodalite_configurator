import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/codec/import_files.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/editor_page.dart';
import 'package:sodalite_configurator/ui/strings.dart';

typedef PickZipBytesFn = Future<List<int>?> Function();

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.download, this.pickZipBytes});

  final DownloadFn download;
  final PickZipBytesFn? pickZipBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sodalite Configurator')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(onPressed: () => _createModule(context), child: const Text(UiStrings.createModule)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => _openZip(context), child: const Text(UiStrings.openZip)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createModule(BuildContext context) async {
    final slug = await showDialog<String>(context: context, builder: (context) => const _SlugDialog());
    if (slug == null || !context.mounted) {
      return;
    }

    final controller = DocumentController(
      catalog: Catalog.modulePack(),
      root: newModuleBundle(slug: slug, id: newNodeId),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(controller: controller, download: download, ownsController: true),
      ),
    );
  }

  Future<void> _openZip(BuildContext context) async {
    final bytes = await (pickZipBytes ?? _pickZipBytes)();
    if (bytes == null || !context.mounted) {
      return;
    }

    final result = importZip(bytes, id: newNodeId);
    if (result.bundle == null) {
      if (!context.mounted) {
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

    final controller = DocumentController(
      catalog: Catalog.modulePack(),
      root: result.bundle!,
      importWarnings: result.warnings,
      importErrors: result.errors,
    );
    if (!context.mounted) {
      controller.dispose();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(controller: controller, download: download, ownsController: true),
      ),
    );
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
