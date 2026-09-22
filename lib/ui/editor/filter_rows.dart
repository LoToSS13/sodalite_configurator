import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/filter_operator.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class FilterCriterionList extends StatelessWidget {
  const FilterCriterionList({super.key, required this.parentId, required this.children, required this.controller});

  final String parentId;
  final List<Node> children;
  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilterCriterionRow(node: child, controller: controller),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: Key('add-criterion-$parentId'),
                onPressed: () => controller.addFilterCriterion(parentId),
                child: const Text(UiStrings.addCriterion),
              ),
              TextButton(
                key: Key('add-filter-group-$parentId'),
                onPressed: () => controller.addFilterCriterion(parentId, group: true),
                child: const Text(UiStrings.addFilterGroup),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FilterCriterionRow extends StatelessWidget {
  const FilterCriterionRow({super.key, required this.node, required this.controller});

  final Node node;
  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    if (node.typeId == TypeIds.searchFilterInvalid) {
      final reason = node.fields['reason'];
      return Row(
        children: [
          Expanded(child: Text(reason is String ? reason : UiStrings.issueReason('Invalid search filter'))),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => controller.removeNode(node.id),
            icon: const Icon(Icons.close),
          ),
        ],
      );
    }

    final operator = node.fields['operator'];
    final selected = filterOperatorValues.contains(operator) ? operator as String : null;
    final isGroup = node.typeId == TypeIds.searchFilterGroup;
    final alias = node.fields['alias'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                key: ValueKey('${node.id}-filter-operator-$selected'),
                isExpanded: true,
                initialValue: selected,
                decoration: InputDecoration(labelText: UiStrings.pathLabel('operator')),
                items: [
                  for (final item in filterOperatorValues)
                    DropdownMenuItem(value: item, child: Text(UiStrings.enumLabel(item))),
                ],
                onChanged: (next) {
                  if (next != null) {
                    controller.setFilterOperator(node.id, next);
                  }
                },
              ),
            ),
            if (!isGroup) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SyncedTextField(
                  key: ValueKey('${node.id}-filter-alias'),
                  value: alias is String ? alias : '',
                  decoration: InputDecoration(labelText: UiStrings.pathLabel('alias')),
                  onChanged: (text) => controller.setField(node.id, 'alias', text),
                ),
              ),
            ],
            IconButton(
              tooltip: 'Удалить',
              onPressed: () => controller.removeNode(node.id),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (node.typeId == TypeIds.searchFilterScalar)
          SyncedTextField(
            key: ValueKey('${node.id}-filter-value'),
            value: node.fields['value'] is String ? node.fields['value'] as String : '',
            decoration: InputDecoration(labelText: UiStrings.pathLabel('value')),
            onChanged: (text) => controller.setField(node.id, 'value', text),
          ),
        if (node.typeId == TypeIds.searchFilterList)
          StringListEditor(
            node: node,
            spec: const FieldSpec(key: 'value', kind: FieldKind.stringList, required: true),
            controller: controller,
            label: UiStrings.pathLabel('value'),
            errorText: null,
          ),
        if (isGroup)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: FilterCriterionList(
              parentId: node.id,
              children: node.childrenBySlot['criterions'] ?? const <Node>[],
              controller: controller,
            ),
          ),
      ],
    );
  }
}
