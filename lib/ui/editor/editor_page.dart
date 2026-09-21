import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/ui/editor/block_card.dart';
import 'package:sodalite_configurator/ui/editor/completeness_panel.dart';
import 'package:sodalite_configurator/ui/editor/json_preview.dart';
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
  bool _jsonOpen = false;

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
        final compactBar = MediaQuery.sizeOf(context).width < 720;
        return Scaffold(
          appBar: AppBar(
            title: Text('${controller.root.fields['slug'] ?? ''}', overflow: TextOverflow.ellipsis),
            actions: [
              if (!compactBar) Center(child: Text(UiStrings.issuesCount(controller.issues.length))),
              if (compactBar)
                IconButton(
                  tooltip: UiStrings.jsonPreview,
                  isSelected: _jsonOpen,
                  onPressed: () => setState(() => _jsonOpen = !_jsonOpen),
                  icon: const Icon(Icons.code),
                )
              else
                TextButton(
                  onPressed: () => setState(() => _jsonOpen = !_jsonOpen),
                  child: const Text(UiStrings.jsonPreview),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: FilledButton(
                  key: const Key('exportZip'),
                  style: compactBar
                      ? FilledButton.styleFrom(minimumSize: const Size(40, 40), padding: const EdgeInsets.all(8))
                      : null,
                  onPressed: controller.canExport ? _export : null,
                  child: compactBar ? const Icon(Icons.download, size: 20) : const Text(UiStrings.downloadZip),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (controller.hasImportNotes) _ImportNotesBanner(controller: controller),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvas = SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: BlockCard(node: controller.root, controller: controller),
                    );
                    final side = _jsonOpen
                        ? JsonPreview(text: modulePreviewText(controller.root))
                        : CompletenessPanel(
                            issues: controller.issues,
                            catalog: controller.catalog,
                            root: controller.root,
                            onIssueTap: _onIssueTap,
                          );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: canvas),
                          SizedBox(height: 240, child: side),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: canvas),
                        SizedBox(width: 320, child: side),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImportNotesBanner extends StatelessWidget {
  const _ImportNotesBanner({required this.controller});

  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    final lines = [
      ...controller.importErrors,
      for (final warning in controller.importWarnings) '${warning.file}: ${warning.message}',
    ];
    return Material(
      key: const Key('importWarningsBanner'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(UiStrings.importNotesHeading, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
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
