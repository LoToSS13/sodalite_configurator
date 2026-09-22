import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/editor/filter_rows.dart';
import 'package:sodalite_configurator/ui/editor/node_summary.dart';
import 'package:sodalite_configurator/ui/editor/slot_add_button.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class BlockCard extends StatefulWidget {
  const BlockCard({
    super.key,
    required this.node,
    required this.controller,
    this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  final Node node;
  final DocumentController controller;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<BlockCard> {
  bool _expanded = true;

  @override
  void didUpdateWidget(BlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.controller.selectedId;
    if (selected != null && widget.node.find(selected) != null) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final controller = widget.controller;
    final type = controller.catalog.type(node.typeId);
    final selected = controller.selectedId == node.id;
    final scheme = Theme.of(context).colorScheme;
    final summary = nodeSummary(node);

    return Card(
      key: Key('node-${node.id}'),
      color: selected ? scheme.secondaryContainer : null,
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: Key('collapse-${node.id}'),
                  tooltip: _expanded ? UiStrings.collapse : UiStrings.expand,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.titleMedium,
                      children: [
                        TextSpan(text: type.labelRu),
                        if (summary != null)
                          TextSpan(
                            text: ' · $summary',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
                if (node.typeId == TypeIds.layer)
                  IconButton(
                    key: Key('duplicate-${node.id}'),
                    tooltip: UiStrings.duplicateLayer,
                    onPressed: () => controller.duplicateLayer(node.id),
                    icon: const Icon(Icons.copy),
                  ),
                if (widget.onMoveUp != null)
                  IconButton(
                    key: Key('move-up-${node.id}'),
                    tooltip: UiStrings.moveUp,
                    onPressed: widget.onMoveUp,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                if (widget.onMoveDown != null)
                  IconButton(
                    key: Key('move-down-${node.id}'),
                    tooltip: UiStrings.moveDown,
                    onPressed: widget.onMoveDown,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                if (widget.onRemove != null)
                  IconButton(tooltip: 'Удалить', onPressed: widget.onRemove, icon: const Icon(Icons.close)),
              ],
            ),
            if (_expanded) ...[
              FieldControls(node: node, fields: type.fields, controller: controller),
              for (final slot in type.slots) ..._slotSection(slot),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _slotSection(SlotSpec slot) {
    final node = widget.node;
    final controller = widget.controller;
    final children = node.childrenBySlot[slot.key] ?? const <Node>[];
    if (slot.key == 'criterions') {
      return [FilterCriterionList(parentId: node.id, children: children, controller: controller)];
    }
    return [
      for (var index = 0; index < children.length; index++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BlockCard(
            node: children[index],
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
          padding: const EdgeInsets.only(top: 8),
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(UiStrings.confirmDisableFeature),
      content: const Text(UiStrings.confirmDisableFeatureBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(UiStrings.cancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(UiStrings.confirm)),
      ],
    ),
  );
  if (confirmed == true) {
    onConfirm();
  }
}
