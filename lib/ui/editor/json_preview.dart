import 'package:flutter/material.dart';

class JsonPreview extends StatelessWidget {
  const JsonPreview({super.key, required this.text, this.filename});

  final String text;
  final String? filename;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filename != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(filename!, style: Theme.of(context).textTheme.titleMedium),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
