import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/ui/editor/block_card.dart';
import 'package:sodalite_configurator/ui/editor/completeness_panel.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.controller, required this.download, this.ownsController = false});

  final DocumentController controller;
  final DownloadFn download;
  final bool ownsController;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  @override
  void dispose() {
    if (widget.ownsController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  void _onIssueTap(Issue issue) {
    widget.controller.select(issue.nodeId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureNodeVisible(context, issue.nodeId);
    });
  }

  void _export() {
    try {
      final bytes = widget.controller.exportZip();
      final slug = widget.controller.root.fields['slug'] as String? ?? 'module';
      widget.download(filename: '$slug-sodalite-module.zip', bytes: bytes);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          appBar: AppBar(
            title: Text('${controller.root.fields['slug'] ?? ''}'),
            actions: [
              Center(child: Text(UiStrings.issuesCount(controller.issues.length))),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: FilledButton(
                  key: const Key('exportZip'),
                  onPressed: controller.canExport ? _export : null,
                  child: const Text(UiStrings.downloadZip),
                ),
              ),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: BlockCard(node: controller.root, controller: controller),
                ),
              ),
              SizedBox(
                width: 320,
                child: CompletenessPanel(
                  issues: controller.issues,
                  catalog: controller.catalog,
                  root: controller.root,
                  onIssueTap: _onIssueTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _ensureNodeVisible(BuildContext context, String nodeId) {
  final targetKey = Key('node-$nodeId');
  Element? match;
  void visit(Element element) {
    if (match != null) {
      return;
    }
    if (element.widget.key == targetKey) {
      match = element;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  final found = match;
  if (found != null) {
    Scrollable.ensureVisible(found, alignment: 0.1, duration: const Duration(milliseconds: 200));
  }
}
