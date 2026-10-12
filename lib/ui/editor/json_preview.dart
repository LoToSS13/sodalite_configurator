import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/sodalite_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:sodalite_configurator/ui/editor/json_value_range.dart';

class JsonPreview extends StatefulWidget {
  const JsonPreview({
    super.key,
    required this.text,
    this.filename,
    this.onClose,
    this.embedded = false,
    this.selectedPath,
  });

  final String text;
  final String? filename;
  final VoidCallback? onClose;
  final bool embedded;
  final List<Object>? selectedPath;

  @override
  State<JsonPreview> createState() => _JsonPreviewState();
}

class _JsonPreviewState extends State<JsonPreview> {
  final _verticalScroll = ScrollController();
  static const _fontSize = 14.0;
  static const _lineHeight = 1.6;

  @override
  void initState() {
    super.initState();
    _scrollToSelection();
  }

  @override
  void didUpdateWidget(covariant JsonPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.selectedPath, widget.selectedPath) || oldWidget.filename != widget.filename) {
      _scrollToSelection();
    }
  }

  @override
  void dispose() {
    _verticalScroll.dispose();
    super.dispose();
  }

  JsonValueRange? get _selection {
    final path = widget.selectedPath;
    if (path == null) return null;
    return findJsonValueRange(widget.text, path);
  }

  void _scrollToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalScroll.hasClients) return;
      final range = _selection;
      if (range == null) {
        _verticalScroll.jumpTo(0);
        return;
      }
      final line = '\n'.allMatches(widget.text.substring(0, range.start)).length;
      final lineExtent = MediaQuery.textScalerOf(context).scale(_fontSize) * _lineHeight;
      final target = (line * lineExtent - 40).clamp(0.0, _verticalScroll.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)) {
        _verticalScroll.jumpTo(target);
      } else {
        _verticalScroll.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final filename = widget.filename;
    final onClose = widget.onClose;
    final embedded = widget.embedded;
    final selectedRange = _selection;
    return Material(
      color: SodaliteColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.data_object, size: 20, color: SodaliteColors.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    embedded ? filename ?? 'JSON' : UiStrings.jsonPreview,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SodaliteIconButton(
                  key: const Key('copyJson'),
                  tooltip: UiStrings.copyJson,
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        SodaliteToast.show(context, message: UiStrings.copied);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        SodaliteToast.show(
                          context,
                          kind: SodaliteToastKind.error,
                          message: 'Не удалось скопировать JSON. Выделите текст и скопируйте вручную',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 20),
                ),
                if (onClose != null)
                  SodaliteIconButton(
                    tooltip: 'Скрыть JSON',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
          ),
          if (!embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                filename ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
              ),
            ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScroll,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        List.generate(text.split('\n').length, (index) => '${index + 1}').join('\n'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: _fontSize,
                          height: _lineHeight,
                          color: SodaliteColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SelectableText.rich(
                      TextSpan(children: _jsonSpans(text, selectedRange)),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _fontSize,
                        height: _lineHeight,
                        color: SodaliteColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Только чтение · Изменения через форму',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

List<TextSpan> _jsonSpans(String source, JsonValueRange? selectedRange) {
  final tokens = RegExp(r'"(?:\\.|[^"\\])*"|\b(?:true|false|null)\b|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?');
  final spans = <TextSpan>[];
  void addRange(int start, int end, Color? color) {
    if (start >= end) return;
    final boundaries = <int>{start, end};
    if (selectedRange != null) {
      if (selectedRange.start > start && selectedRange.start < end) boundaries.add(selectedRange.start);
      if (selectedRange.end > start && selectedRange.end < end) boundaries.add(selectedRange.end);
    }
    final points = boundaries.toList()..sort();
    for (var i = 0; i < points.length - 1; i++) {
      final selected = selectedRange != null && points[i] >= selectedRange.start && points[i] < selectedRange.end;
      spans.add(
        TextSpan(
          text: source.substring(points[i], points[i + 1]),
          style: TextStyle(color: color, backgroundColor: selected ? SodaliteColors.accentSubdued : null),
        ),
      );
    }
  }

  var end = 0;
  for (final match in tokens.allMatches(source)) {
    addRange(end, match.start, null);
    final value = match.group(0)!;
    final isKey = value.startsWith('"') && source.substring(match.end).trimLeft().startsWith(':');
    addRange(match.start, match.end, isKey ? SodaliteColors.accentStrong : SodaliteColors.text);
    end = match.end;
  }
  addRange(end, source.length, null);
  return spans;
}
