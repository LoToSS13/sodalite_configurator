import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_select.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/filter_operator.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/design_system.dart';

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
            key: ValueKey(child.id),
            padding: const EdgeInsets.only(top: 8),
            child: FilterCriterionRow(node: child, controller: controller),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: SodaliteMenuButton<bool>(
            key: Key('add-filter-condition-$parentId'),
            tooltip: 'Добавить в эту группу',
            onSelected: (group) => controller.addFilterCriterion(parentId, group: group),
            itemBuilder: (context) => const [
              SodaliteMenuItem<bool>(value: false, label: 'Критерий', icon: Icons.add),
              SodaliteMenuItem<bool>(value: true, label: 'Группу условий', icon: Icons.account_tree_outlined),
            ],
            trigger: (onPressed) => SodaliteButton.ghost(
              onPressed: onPressed,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить условие'),
            ),
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
        key: Key('node-${node.id}'),
        children: [
          Expanded(child: Text(reason is String ? reason : UiStrings.issueReason('Invalid search filter'))),
          SodaliteIconButton(
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
    final isScalar = node.typeId == TypeIds.searchFilterScalar;
    final isList = node.typeId == TypeIds.searchFilterList;

    Widget operatorField() => SodaliteSelect<String>(
      key: ValueKey('${node.id}-filter-operator-$selected'),
      value: selected,
      decoration: InputDecoration(labelText: UiStrings.pathLabel('operator')),
      values: filterOperatorValues,
      labelOf: UiStrings.enumLabel,
      onChanged: (next) {
        if (next != null) controller.setFilterOperator(node.id, next);
      },
    );
    Widget aliasField() => SyncedTextField(
      key: ValueKey('${node.id}-filter-alias'),
      value: alias is String ? alias : '',
      decoration: InputDecoration(labelText: UiStrings.pathLabel('alias')),
      onChanged: (text) => controller.setField(node.id, 'alias', text),
    );
    Widget valueField() => SyncedTextField(
      key: ValueKey('${node.id}-filter-value'),
      value: node.fields['value'] is String ? node.fields['value'] as String : '',
      decoration: InputDecoration(labelText: UiStrings.pathLabel('value')),
      onChanged: (text) => controller.setField(node.id, 'value', text),
    );
    final remove = SodaliteIconButton(
      tooltip: 'Удалить условие',
      onPressed: () => controller.removeNode(node.id),
      icon: const Icon(Icons.close),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= 500;
        return Column(
          key: Key('node-${node.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isGroup)
              Row(
                children: [
                  Expanded(child: operatorField()),
                  remove,
                ],
              )
            else if (inline)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: aliasField()),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: operatorField()),
                  if (isScalar) ...[const SizedBox(width: 8), Expanded(flex: 3, child: valueField())],
                  remove,
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(child: aliasField()),
                  remove,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: operatorField()),
                  if (isScalar) ...[const SizedBox(width: 8), Expanded(child: valueField())],
                ],
              ),
            ],
            if (isList) ...[
              const SizedBox(height: 8),
              StringListEditor(
                node: node,
                spec: const FieldSpec(key: 'value', kind: FieldKind.stringList, required: true),
                controller: controller,
                label: UiStrings.pathLabel('value'),
                errorText: null,
              ),
            ],
            if (isGroup)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: SodaliteColors.border, width: 2)),
                ),
                child: FilterCriterionList(
                  parentId: node.id,
                  children: node.childrenBySlot['criterions'] ?? const <Node>[],
                  controller: controller,
                ),
              ),
          ],
        );
      },
    );
  }
}
