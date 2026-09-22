import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sodalite_configurator/ui/strings.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text(filename ?? '', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  key: const Key('copyJson'),
                  tooltip: UiStrings.copyJson,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(UiStrings.copied)));
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
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
