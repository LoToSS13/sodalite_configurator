import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/sodalite_success_check.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/editor/node_summary.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';

class CompletenessPanel extends StatelessWidget {
  const CompletenessPanel({
    super.key,
    required this.issues,
    required this.catalog,
    required this.root,
    required this.onIssueTap,
    this.onClose,
  });

  final List<Issue> issues;
  final Catalog catalog;
  final Node root;
  final ValueChanged<Issue> onIssueTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SodaliteColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        issues.isEmpty ? 'Модуль готов к\u00a0экспорту' : 'Что осталось заполнить',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (onClose != null)
                      SodaliteIconButton(
                        tooltip: 'Закрыть замечания',
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  issues.isEmpty
                      ? 'Можно скачать ZIP с\u00a0конфигурацией'
                      : 'Выберите замечание, чтобы перейти к\u00a0нужному блоку',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: issues.isEmpty
                ? const Center(child: SodaliteSuccessCheck())
                : ListView.builder(
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SodaliteColors.canvas,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${index + 1}', style: Theme.of(context).textTheme.titleSmall),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: SodaliteColors.icon),
                        title: Text(UiStrings.issueHeadline(issue, catalog, root)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _location(issue.nodeId),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                            ),
                            const SizedBox(height: 4),
                            Text(UiStrings.issueReason(issue.message)),
                          ],
                        ),
                        onTap: () => onIssueTap(issue),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _location(String targetId) {
    List<String>? findPath(Node parent) {
      if (parent.id == targetId) return [];
      for (final siblings in parent.childrenBySlot.values) {
        for (var index = 0; index < siblings.length; index++) {
          final child = siblings[index];
          final rest = findPath(child);
          if (rest != null) {
            final name =
                nodeSummary(child) ??
                (child.typeId == TypeIds.app ? UiStrings.appCard : catalog.type(child.typeId).labelRu);
            return ['${index + 1}. $name', ...rest];
          }
        }
      }
      return null;
    }

    final section = editorSectionLabel(editorSectionOf(root, targetId));
    return [section, ...?findPath(root)].join(' / ');
  }
}
