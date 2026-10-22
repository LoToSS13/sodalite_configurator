import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/sodalite_accordion.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/editor/filter_rows.dart';
import 'package:sodalite_configurator/ui/editor/node_summary.dart';
import 'package:sodalite_configurator/ui/editor/slot_add_button.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';
import 'package:sodalite_configurator/ui/help_copy.dart';
import 'package:sodalite_configurator/ui/sodalite_help.dart';
import 'package:sodalite_configurator/ui/sodalite_tooltip.dart';

class BlockCard extends StatelessWidget {
  const BlockCard({
    super.key,
    required this.node,
    required this.controller,
    this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
    this.depth = 0,
    this.visibleSlots,
    this.footer,
  });

  final Node node;
  final DocumentController controller;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final int depth;

  /// Restricts only this node's immediate slots; descendants keep their own slots.
  final Set<String>? visibleSlots;
  final Widget? footer;

  bool get _expanded => controller.isBlockExpanded(node.id);

  @override
  Widget build(BuildContext context) {
    final node = this.node;
    final controller = this.controller;
    final type = controller.catalog.type(node.typeId);
    final selected = controller.selectedId == node.id;
    final scheme = Theme.of(context).colorScheme;
    final summary = _expanded ? nodeSummary(node) : nodeCollapsedSummary(node);
    final label = node.typeId == TypeIds.app ? UiStrings.appCard : type.labelRu;
    final issueCount = controller.visibleIssues
        .where((issue) => _expanded ? issue.nodeId == node.id : node.find(issue.nodeId) != null)
        .length;
    final canDuplicate = node.typeId == TypeIds.layer;
    final actionCount =
        (canDuplicate ? 1 : 0) + (onMoveUp != null ? 1 : 0) + (onMoveDown != null ? 1 : 0) + (onRemove != null ? 1 : 0);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              expanded: _expanded,
              child: SodaliteIconButton(
                key: Key('collapse-${node.id}'),
                tooltip: '${_expanded ? UiStrings.collapse : UiStrings.expand} «$label»',
                onPressed: () => controller.toggleBlock(node.id),
                icon: SodaliteAccordionChevron(expanded: _expanded),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: SodaliteTooltip(
                          message: label,
                          excludeFromSemantics: true,
                          child: Semantics(
                            selected: selected,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (this.depth == 0
                                          ? sodaliteCardTitleStyle(context)
                                          : Theme.of(context).textTheme.titleMedium)
                                      ?.copyWith(color: selected ? SodaliteColors.accentStrong : SodaliteColors.text),
                            ),
                          ),
                        ),
                      ),
                      if (HelpCopy.block(node.typeId) case final help?) SodaliteHelpButton(name: label, text: help),
                    ],
                  ),
                  if (summary != null)
                    SodaliteTooltip(
                      message: summary,
                      excludeFromSemantics: true,
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            if (issueCount > 0)
              SodaliteTooltip(
                message: UiStrings.issuesCount(issueCount),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.error_outline, color: SodaliteColors.error, size: 18),
                ),
              ),
            if (actionCount == 1)
              SodaliteIconButton(
                tooltip: canDuplicate ? UiStrings.duplicateLayer : 'Удалить блок',
                onPressed: canDuplicate ? () => controller.duplicateLayer(node.id) : onRemove,
                icon: Icon(canDuplicate ? Icons.copy_outlined : Icons.delete_outline, size: 20),
              )
            else if (actionCount > 1)
              SodaliteMenuButton<String>(
                tooltip: 'Действия с блоком',
                icon: const Icon(Icons.more_horiz, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'duplicate':
                      controller.duplicateLayer(node.id);
                    case 'up':
                      this.onMoveUp?.call();
                    case 'down':
                      this.onMoveDown?.call();
                    case 'remove':
                      this.onRemove?.call();
                  }
                },
                itemBuilder: (_) => [
                  if (node.typeId == TypeIds.layer)
                    const SodaliteMenuItem(
                      value: 'duplicate',
                      label: UiStrings.duplicateLayer,
                      icon: Icons.copy_outlined,
                    ),
                  if (this.onMoveUp != null)
                    const SodaliteMenuItem(value: 'up', label: UiStrings.moveUp, icon: Icons.arrow_upward),
                  if (this.onMoveDown != null)
                    const SodaliteMenuItem(value: 'down', label: UiStrings.moveDown, icon: Icons.arrow_downward),
                  if (this.onRemove != null) ...[
                    if (node.typeId == TypeIds.layer || this.onMoveUp != null || this.onMoveDown != null)
                      const SodaliteMenuDivider<String>(),
                    const SodaliteMenuItem(
                      value: 'remove',
                      label: 'Удалить блок',
                      icon: Icons.delete_outline,
                      destructive: true,
                    ),
                  ],
                ],
              ),
          ],
        ),
        SodaliteAccordionPanel(
          expanded: _expanded,
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (type.fields.isNotEmpty) ...[
                const SizedBox(height: 12),
                FieldControls(node: node, fields: type.fields, controller: controller),
              ],
              for (final slot in type.slots)
                if (visibleSlots == null || visibleSlots!.contains(slot.key)) ..._slotSection(slot),
              if (footer != null) ...[const SizedBox(height: 16), footer!],
            ],
          ),
        ),
      ],
    );
    if (this.depth == 0) {
      return Card(
        key: Key('node-${node.id}'),
        color: SodaliteColors.surface,
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 20), child: content),
      );
    }
    // Enclose each nested block so its fields and add actions have one clear boundary.
    return Container(
      key: Key('node-${node.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: SodaliteColors.muted),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  List<Widget> _slotSection(SlotSpec slot) {
    final node = this.node;
    final controller = this.controller;
    final children = node.childrenBySlot[slot.key] ?? const <Node>[];
    if (slot.key == 'criterions') {
      return [FilterCriterionList(parentId: node.id, children: children, controller: controller)];
    }
    return [
      for (var index = 0; index < children.length; index++)
        Padding(
          key: ValueKey(children[index].id),
          padding: const EdgeInsets.only(top: 16),
          child: BlockCard(
            key: ValueKey(children[index].id),
            node: children[index],
            depth: this.depth + 1,
            controller: controller,
            onRemove: _canRemove(slot) ? () => controller.removeNode(children[index].id) : null,
            onMoveUp: slot.cardinality == SlotCardinality.list && index > 0
                ? () => controller.moveChild(children[index].id, offset: -1)
                : null,
            onMoveDown: slot.cardinality == SlotCardinality.list && index < children.length - 1
                ? () => controller.moveChild(children[index].id, offset: 1)
                : null,
          ),
        ),
      if (_canAdd(slot, children.length))
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SlotAddButton(parentId: node.id, slot: slot, catalog: controller.catalog, controller: controller),
        ),
    ];
  }

  bool _canAdd(SlotSpec slot, int count) {
    return switch (slot.cardinality) {
      SlotCardinality.list => true,
      SlotCardinality.one || SlotCardinality.optionalOne => count == 0,
    };
  }

  bool _canRemove(SlotSpec slot) {
    return slot.cardinality != SlotCardinality.one;
  }
}

Future<void> confirmDisableFeature(BuildContext context, {required VoidCallback onConfirm}) async {
  final confirmed = await showSodaliteDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(UiStrings.confirmDisableFeature),
      content: const Text(UiStrings.confirmDisableFeatureBody),
      actions: [
        SodaliteButton.secondary(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(UiStrings.cancel),
        ),
        SodaliteButton.destructive(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(UiStrings.confirm),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    onConfirm();
  }
}
