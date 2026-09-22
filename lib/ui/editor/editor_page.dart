import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/block_card.dart';
import 'package:sodalite_configurator/ui/editor/completeness_panel.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/editor/json_preview.dart';
import 'package:sodalite_configurator/ui/editor/slot_add_button.dart';
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
  EditorSection _section = EditorSection.app;
  var _seenUndoEpoch = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onDocument);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocument);
    if (widget.ownsController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  void _onDocument() {
    final epoch = widget.controller.undoEpoch;
    if (epoch > _seenUndoEpoch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(UiStrings.removed),
          action: SnackBarAction(label: UiStrings.undo, onPressed: widget.controller.undo),
        ),
      );
    }
    _seenUndoEpoch = epoch;
  }

  void _onIssueTap(Issue issue) {
    setState(() => _section = editorSectionOf(widget.controller.root, issue.nodeId));
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

  void _openIssues() {
    final controller = widget.controller;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 420,
          child: CompletenessPanel(
            issues: controller.issues,
            catalog: controller.catalog,
            root: controller.root,
            onIssueTap: (issue) {
              Navigator.of(context).pop();
              _onIssueTap(issue);
            },
          ),
        );
      },
    );
  }

  void _addSection(EditorSection section) {
    switch (section) {
      case EditorSection.objectCreation:
        widget.controller.enableObjectCreation();
      case EditorSection.search:
        widget.controller.enableSearch();
      case EditorSection.app:
      case EditorSection.baseLayer:
      case EditorSection.additionalLayers:
        break;
    }
    setState(() => _section = section);
  }

  Future<void> _disableSection(EditorSection section) async {
    await confirmDisableFeature(
      context,
      onConfirm: () {
        if (_section == section) {
          setState(() => _section = EditorSection.app);
        }
        switch (section) {
          case EditorSection.objectCreation:
            widget.controller.disableObjectCreation();
          case EditorSection.search:
            widget.controller.disableSearch();
          case EditorSection.app:
          case EditorSection.baseLayer:
          case EditorSection.additionalLayers:
            break;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final compactBar = MediaQuery.sizeOf(context).width < 720;
        final visible = visibleEditorSections(controller.root);
        final section = visible.contains(_section) ? _section : EditorSection.app;
        final addable = addableEditorSections(controller.root);
        return Scaffold(
          appBar: AppBar(
            title: Text('${controller.root.fields['slug'] ?? ''}', overflow: TextOverflow.ellipsis),
            actions: [
              if (compactBar)
                IconButton(
                  key: const Key('issuesMenu'),
                  tooltip: UiStrings.issuesCount(controller.issues.length),
                  onPressed: controller.issues.isEmpty ? null : _openIssues,
                  icon: Badge(
                    isLabelVisible: controller.issues.isNotEmpty,
                    label: Text('${controller.issues.length}'),
                    child: const Icon(Icons.checklist),
                  ),
                )
              else
                TextButton(
                  key: const Key('issuesMenu'),
                  onPressed: controller.issues.isEmpty ? null : _openIssues,
                  child: Text(UiStrings.issuesCount(controller.issues.length)),
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
              _SectionBar(
                root: controller.root,
                issues: controller.issues,
                selected: section,
                visible: visible,
                addable: addable,
                onSelect: (section) => setState(() => _section = section),
                onAdd: _addSection,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvas = SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _sectionCanvas(controller, section),
                    );
                    final side = JsonPreview(
                      filename: editorSectionFileName(section),
                      text: editorSectionPreviewText(controller.root, section),
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
                        SizedBox(width: 400, child: side),
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

  Widget _sectionCanvas(DocumentController controller, EditorSection section) {
    final root = controller.root;
    return switch (section) {
      EditorSection.app => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            key: Key('node-${root.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(controller.catalog.type(root.typeId).labelRu, style: Theme.of(context).textTheme.titleMedium),
                  FieldControls(
                    node: root,
                    fields: controller.catalog.type(root.typeId).fields,
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          BlockCard(node: root.childrenBySlot['app']!.single, controller: controller),
        ],
      ),
      EditorSection.baseLayer => BlockCard(node: root.childrenBySlot['baseLayer']!.single, controller: controller),
      EditorSection.additionalLayers => _AdditionalLayersCanvas(controller: controller),
      EditorSection.objectCreation => BlockCard(
        node: root.childrenBySlot['objectCreation']!.single,
        controller: controller,
        onRemove: () => _disableSection(EditorSection.objectCreation),
      ),
      EditorSection.search => BlockCard(
        node: root.childrenBySlot['search']!.single,
        controller: controller,
        onRemove: () => _disableSection(EditorSection.search),
      ),
    };
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({
    required this.root,
    required this.issues,
    required this.selected,
    required this.visible,
    required this.addable,
    required this.onSelect,
    required this.onAdd,
  });

  final Node root;
  final List<Issue> issues;
  final EditorSection selected;
  final List<EditorSection> visible;
  final List<EditorSection> addable;
  final ValueChanged<EditorSection> onSelect;
  final ValueChanged<EditorSection> onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final section in visible)
                    _SectionTab(
                      section: section,
                      selected: section == selected,
                      badge: editorSectionIssueCount(root, issues, section),
                      onTap: () => onSelect(section),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<EditorSection>(
            key: const Key('add-file-tab'),
            tooltip: UiStrings.addFile,
            enabled: addable.isNotEmpty,
            onSelected: onAdd,
            itemBuilder: (context) => [
              for (final section in addable) PopupMenuItem(value: section, child: Text(editorSectionLabel(section))),
            ],
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Icon(Icons.add)),
          ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({required this.section, required this.selected, required this.badge, required this.onTap});

  final EditorSection section;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('editor-tab-${section.name}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Text(
              editorSectionLabel(section),
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? scheme.primary : null,
              ),
            ),
            if (badge > 0) ...[const SizedBox(width: 8), Badge(label: Text('$badge'))],
          ],
        ),
      ),
    );
  }
}

class _AdditionalLayersCanvas extends StatelessWidget {
  const _AdditionalLayersCanvas({required this.controller});

  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    final root = controller.root;
    final children = root.childrenBySlot['additionalLayers'] ?? const <Node>[];
    final slot = controller.catalog
        .type(TypeIds.moduleBundle)
        .slots
        .firstWhere((item) => item.key == 'additionalLayers');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BlockCard(
              node: children[index],
              controller: controller,
              onRemove: () => controller.removeNode(children[index].id),
              onMoveUp: index > 0 ? () => controller.moveChild(children[index].id, offset: -1) : null,
              onMoveDown: index < children.length - 1
                  ? () => controller.moveChild(children[index].id, offset: 1)
                  : null,
            ),
          ),
        SlotAddButton(parentId: root.id, slot: slot, catalog: controller.catalog, controller: controller),
      ],
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
