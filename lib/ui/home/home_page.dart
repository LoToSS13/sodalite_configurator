import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/editor_page.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.download});

  final DownloadFn download;

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
              const OutlinedButton(onPressed: null, child: Text(UiStrings.openZip)),
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
