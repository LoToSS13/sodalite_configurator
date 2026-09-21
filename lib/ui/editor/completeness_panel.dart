import 'package:flutter/material.dart';
import 'package:sodalite_configurator/schema/issue.dart';

class CompletenessPanel extends StatelessWidget {
  const CompletenessPanel({super.key, required this.issues, required this.onIssueTap});

  final List<Issue> issues;
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
            child: Text('Замечания', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: issues.isEmpty
                ? const Center(child: Text('Нет замечаний'))
                : ListView.builder(
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return ListTile(
                        title: Text(issue.message),
                        subtitle: Text(issue.path),
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
