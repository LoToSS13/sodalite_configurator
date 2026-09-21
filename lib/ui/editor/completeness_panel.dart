import 'package:flutter/material.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/strings.dart';

class CompletenessPanel extends StatelessWidget {
  const CompletenessPanel({
    super.key,
    required this.issues,
    required this.catalog,
    required this.root,
    required this.onIssueTap,
  });

  final List<Issue> issues;
  final Catalog catalog;
  final Node root;
  final ValueChanged<Issue> onIssueTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(UiStrings.issuesHeading, style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: issues.isEmpty
                ? const Center(child: Text(UiStrings.noIssues))
                : ListView.builder(
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return ListTile(
                        title: Text(UiStrings.issueHeadline(issue, catalog, root)),
                        subtitle: Text(UiStrings.issueReason(issue.message)),
                        onTap: () => onIssueTap(issue),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
