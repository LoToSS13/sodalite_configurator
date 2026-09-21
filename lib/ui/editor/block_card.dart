import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/editor/slot_add_button.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class BlockCard extends StatelessWidget {
  const BlockCard({super.key, required this.node, required this.controller, this.onRemove});

  final Node node;
  final DocumentController controller;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog;
    final type = catalog.type(node.typeId);
    final selected = controller.selectedId == node.id;
    final scheme = Theme.of(context).colorScheme;

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
                Expanded(child: Text(type.labelRu, style: Theme.of(context).textTheme.titleMedium)),
                if (onRemove != null)
                  IconButton(tooltip: 'Удалить', onPressed: onRemove, icon: const Icon(Icons.close)),
              ],
            ),
            FieldControls(node: node, fields: type.fields, controller: controller),
            for (final slot in type.slots) ..._slotSection(slot),
          ],
        ),
      ),
    );
  }

  List<Widget> _slotSection(SlotSpec slot) {
    if (slot.key == 'objectCreation' || slot.key == 'search') {
      return [_featureSlot(slot)];
    }

    final children = node.childrenBySlot[slot.key] ?? const <Node>[];
    return [
      for (final child in children)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BlockCard(
            node: child,
            controller: controller,
            onRemove: _canRemove(slot) ? () => controller.removeNode(child.id) : null,
          ),
        ),
      if (_canAdd(slot, children.length))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SlotAddButton(parentId: node.id, slot: slot, catalog: controller.catalog, controller: controller),
        ),
    ];
  }

  Widget _featureSlot(SlotSpec slot) {
    final children = node.childrenBySlot[slot.key] ?? const <Node>[];
    if (children.isNotEmpty) {
      final child = children.first;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: BlockCard(
          node: child,
          controller: controller,
          onRemove: slot.key == 'objectCreation' ? controller.disableObjectCreation : controller.disableSearch,
        ),
      );
    }

    final label = slot.key == 'objectCreation' ? UiStrings.enableObjectCreation : UiStrings.enableSearch;
    final onPressed = slot.key == 'objectCreation' ? controller.enableObjectCreation : controller.enableSearch;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DashedSlotButton(label: label, onPressed: onPressed),
    );
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
