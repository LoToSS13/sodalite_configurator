import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/sodalite_tooltip.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';
import 'package:sodalite_configurator/ui/editor/node_summary.dart';
import 'package:sodalite_configurator/ui/strings.dart';

IconData sectionIcon(EditorSection section) => switch (section) {
  EditorSection.app => Icons.grid_view_rounded,
  EditorSection.baseLayer => Icons.layers_outlined,
  EditorSection.additionalLayers => Icons.copy_all_outlined,
  EditorSection.objectCreation => Icons.add_location_alt_outlined,
  EditorSection.search => Icons.search,
};

String sectionDescription(EditorSection section) => switch (section) {
  EditorSection.app => 'Название и\u00a0описание, которые увидят пользователи Sodalite',
  EditorSection.baseLayer => 'Геоданные, внешний вид объектов и\u00a0содержимое их\u00a0карточек',
  EditorSection.additionalLayers => 'Дополнительные данные, которые можно показать на\u00a0карте',
  EditorSection.objectCreation => 'Форма и\u00a0типы геометрии для новых объектов на\u00a0карте',
  EditorSection.search => 'Объекты, условия поиска и\u00a0вид результатов',
};

class EditorNavigation extends StatefulWidget {
  const EditorNavigation({
    super.key,
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onNodeTap,
  });
  final DocumentController controller;
  final EditorSection selected;
  final ValueChanged<EditorSection> onSelect;
  final ValueChanged<EditorSection> onAdd;
  final ValueChanged<String> onNodeTap;

  @override
  State<EditorNavigation> createState() => _EditorNavigationState();
}

class _EditorNavigationState extends State<EditorNavigation> {
  final Map<String, bool> _expanded = {};
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  late int _selectionEpoch;
  DocumentController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectionEpoch = controller.selectionEpoch;
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectionEpoch != controller.selectionEpoch || oldWidget.selected != widget.selected) {
      final selectedId = controller.selectedId ?? 'section:${widget.selected.name}';
      bool reveal(_TreeEntry entry) {
        final contains = entry.id == selectedId || entry.children.any(reveal);
        if (contains) _expanded[entry.id] = true;
        return contains;
      }

      reveal(_rootEntry());
    }
    _selectionEpoch = controller.selectionEpoch;
  }

  _TreeEntry _nodeEntry(Node node) {
    final type = node.typeId == TypeIds.app ? UiStrings.appCard : controller.catalog.type(node.typeId).labelRu;
    final name = nodeName(node);
    return _TreeEntry(
      id: node.id,
      label: name ?? type,
      subtitle: name == null ? nodeSummary(node) : type,
      selected: controller.selectedId == node.id,
      count: controller.visibleIssues.where((issue) => node.find(issue.nodeId) != null).length,
      onTap: () => widget.onNodeTap(node.id),
      children: [for (final child in node.childrenBySlot.values.expand((items) => items)) _nodeEntry(child)],
    );
  }

  _TreeEntry _rootEntry() {
    final slug = controller.root.fields['slug'];
    return _TreeEntry(
      id: controller.root.id,
      label: slug is String && slug.isNotEmpty ? 'Модуль $slug' : 'Новый модуль',
      selected: controller.selectedId == controller.root.id,
      onTap: () => widget.onNodeTap(controller.root.id),
      children: [
        for (final section in visibleEditorSections(controller.root))
          _TreeEntry(
            id: 'section:${section.name}',
            label: editorSectionLabel(section),
            selected: widget.selected == section && controller.selectedId == null,
            count: editorSectionIssueCount(controller.root, controller.visibleIssues, section),
            onTap: () {
              setState(() {
                _expanded[controller.root.id] = true;
                _expanded['section:${section.name}'] = true;
              });
              widget.onSelect(section);
            },
            children: [for (final node in _sectionNodes(section)) _nodeEntry(node)],
          ),
      ],
    );
  }

  List<Node> _sectionNodes(EditorSection section) {
    final nodes = controller.root.childrenBySlot[section.name] ?? const <Node>[];
    if (section == EditorSection.additionalLayers || section == EditorSection.app) return nodes;
    return [
      for (final node in nodes)
        for (final children in node.childrenBySlot.values) ...children,
    ];
  }

  List<_TreeRowData> _rows(_TreeEntry section) {
    final result = <_TreeRowData>[];
    void visit(_TreeEntry entry, int depth, List<bool> guides, bool last) {
      final open = _expanded[entry.id] ?? depth == 1;
      result.add(_TreeRowData(entry, depth, guides, last, open));
      if (!open) return;
      for (var index = 0; index < entry.children.length; index++) {
        visit(entry.children[index], depth + 1, [...guides, !last], index == entry.children.length - 1);
      }
    }

    for (var index = 0; index < section.children.length; index++) {
      visit(section.children[index], 1, [], index == section.children.length - 1);
    }
    return result;
  }

  Widget _sectionHeader(BuildContext context, EditorSection section, _TreeEntry entry) {
    final selected = widget.selected == section;
    final open = _expanded[entry.id] ?? true;
    final color = selected ? SodaliteColors.accentStrong : SodaliteColors.secondary;
    return CustomPaint(
      foregroundPainter: _SectionStemPainter(visible: open && entry.children.isNotEmpty),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? SodaliteColors.accentSubdued : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                selected: selected,
                child: TextButton(
                  onPressed: entry.onTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 52),
                    alignment: Alignment.centerLeft,
                    foregroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                  child: Row(
                    children: [
                      Icon(sectionIcon(section), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (entry.count > 0) ...[
                        const SizedBox(width: 4),
                        SodaliteTooltip(
                          message: UiStrings.issuesCount(entry.count),
                          child: Text(
                            '${entry.count}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.errorText),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (entry.children.isNotEmpty)
              MergeSemantics(
                child: Semantics(
                  expanded: open,
                  label: '${open ? 'Свернуть' : 'Развернуть'} «${entry.label}»',
                  button: true,
                  child: SodaliteTooltip(
                    message: '${open ? 'Свернуть' : 'Развернуть'} «${entry.label}»',
                    excludeFromSemantics: true,
                    child: IconButton(
                      onPressed: () => setState(() => _expanded[entry.id] = !open),
                      icon: Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18),
                      style: IconButton.styleFrom(
                        foregroundColor: color,
                        minimumSize: const Size(36, 40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = visibleEditorSections(controller.root);
    final entries = _rootEntry().children;
    final rowsBySection = [for (final entry in entries) _rows(entry)];
    final depth = rowsBySection.expand((rows) => rows).fold(0, (value, row) => math.max(value, row.depth));
    final addable = addableEditorSections(controller.root);
    return Material(
      color: SodaliteColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(24, 28, 24, 28), child: SodaliteBrand()),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
            child: Text(
              'Структура модуля',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(constraints.maxWidth - 24, 192.0 + depth * 16);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: width > constraints.maxWidth - 24,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: ListView(
                          controller: _vertical,
                          padding: const EdgeInsets.only(bottom: 12),
                          children: [
                            for (var index = 0; index < sections.length; index++) ...[
                              _sectionHeader(context, sections[index], entries[index]),
                              if (_expanded[entries[index].id] ?? true)
                                for (final row in rowsBySection[index])
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: _TreeRow(
                                      key: ValueKey(row.entry.id),
                                      data: row,
                                      onToggle: () => setState(() => _expanded[row.entry.id] = !row.open),
                                    ),
                                  ),
                              const SizedBox(height: 4),
                            ],
                            if (addable.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Text(
                                  'Добавить возможности',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                                ),
                              ),
                              for (final section in addable)
                                TextButton.icon(
                                  onPressed: () => widget.onAdd(section),
                                  icon: const Icon(Icons.add, size: 20),
                                  label: Text(editorSectionLabel(section)),
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    minimumSize: const Size(0, 52),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    foregroundColor: SodaliteColors.secondary,
                                    textStyle: Theme.of(context).textTheme.bodyMedium,
                                  ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.laptop_outlined, size: 18, color: SodaliteColors.icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Черновики хранятся\nв этом браузере',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeEntry {
  const _TreeEntry({
    required this.id,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.count = 0,
    this.children = const [],
  });
  final String id;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
  final int count;
  final List<_TreeEntry> children;
}

class _TreeRowData {
  const _TreeRowData(this.entry, this.depth, this.guides, this.last, this.open);
  final _TreeEntry entry;
  final int depth;
  final List<bool> guides;
  final bool last;
  final bool open;
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({super.key, required this.data, required this.onToggle});
  final _TreeRowData data;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final entry = data.entry;
    final height = entry.subtitle == null ? 40.0 : 44.0;
    return CustomPaint(
      painter: _BranchPainter(
        depth: data.depth,
        guides: data.guides,
        last: data.last,
        open: data.open && entry.children.isNotEmpty,
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(left: data.depth * 16.0),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: entry.children.isEmpty
                    ? null
                    : MergeSemantics(
                        child: Semantics(
                          expanded: data.open,
                          label: '${data.open ? 'Свернуть' : 'Развернуть'} «${entry.label}»',
                          button: true,
                          child: SodaliteTooltip(
                            message: '${data.open ? 'Свернуть' : 'Развернуть'} «${entry.label}»',
                            excludeFromSemantics: true,
                            child: IconButton(
                              onPressed: onToggle,
                              icon: Icon(data.open ? Icons.expand_more : Icons.chevron_right, size: 16),
                              style:
                                  IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(24, height),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: SodaliteColors.secondary,
                                  ).copyWith(
                                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                                    splashFactory: NoSplash.splashFactory,
                                  ),
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: Semantics(
                  selected: entry.selected,
                  child: SodaliteTooltip(
                    message: [entry.label, if (entry.subtitle != null) entry.subtitle!].join(' · '),
                    excludeFromSemantics: true,
                    child: TextButton(
                      onPressed: entry.onTap,
                      style:
                          TextButton.styleFrom(
                            minimumSize: Size(0, height - 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            alignment: Alignment.centerLeft,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: entry.selected ? SodaliteColors.accentSubdued : Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ).copyWith(
                            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                            splashFactory: NoSplash.splashFactory,
                            side: WidgetStateProperty.resolveWith(
                              (states) => BorderSide(
                                color: states.contains(WidgetState.focused)
                                    ? SodaliteColors.accent
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: entry.selected ? SodaliteColors.accentStrong : SodaliteColors.text,
                                  ),
                                ),
                                if (entry.subtitle != null)
                                  Text(
                                    entry.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                                  ),
                              ],
                            ),
                          ),
                          if (entry.count > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: SodaliteTooltip(
                                message: UiStrings.issuesCount(entry.count),
                                child: Text(
                                  '${entry.count}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(color: SodaliteColors.errorText),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionStemPainter extends CustomPainter {
  const _SectionStemPainter({required this.visible});
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    canvas.drawLine(
      Offset(20, size.height - 8),
      Offset(20, size.height),
      Paint()
        ..color = SodaliteColors.border
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SectionStemPainter oldDelegate) => oldDelegate.visible != visible;
}

class _BranchPainter extends CustomPainter {
  const _BranchPainter({required this.depth, required this.guides, required this.last, required this.open});
  final int depth;
  final List<bool> guides;
  final bool last;

  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SodaliteColors.border
      ..strokeWidth = 1;
    for (var level = 0; level < guides.length; level++) {
      if (guides[level]) canvas.drawLine(Offset(12 + level * 16.0, 0), Offset(12 + level * 16.0, size.height), paint);
    }
    if (open) {
      final ownX = 12 + depth * 16.0;
      canvas.drawLine(Offset(ownX, size.height / 2 + 8), Offset(ownX, size.height), paint);
    }
    if (depth == 0) return;
    final x = 12 + (depth - 1) * 16.0;
    final mid = size.height / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, last ? mid : size.height), paint);
    canvas.drawLine(Offset(x, mid), Offset(x + 8, mid), paint);
  }

  @override
  bool shouldRepaint(_BranchPainter oldDelegate) =>
      oldDelegate.depth != depth ||
      oldDelegate.open != open ||
      oldDelegate.last != last ||
      oldDelegate.guides.toString() != guides.toString();
}
