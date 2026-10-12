import 'package:sodalite_configurator/ui/help_copy.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_help.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';

/// Renaming is explicit: a partially typed identifier never enters the document.
class SlugField extends StatelessWidget {
  const SlugField({super.key, required this.controller});
  final DocumentController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Идентификатор',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
                ),
                const SodaliteHelpButton(name: 'Идентификатор', text: HelpCopy.moduleSlug),
                SelectableText(
                  controller.root.fields['slug'] as String? ?? '',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SodaliteButton.ghost(
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Изменить'),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.bodyLarge),
            ),
            onPressed: () => showSodaliteDialog<void>(
              context: context,
              builder: (_) => _RenameDialog(controller: controller),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Имя папки модуля; входит в имя ZIP-файла',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
      ),
    ],
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.controller});
  final DocumentController controller;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final String _original = widget.controller.root.fields['slug'] as String? ?? '';
  late final TextEditingController _text = TextEditingController(text: _original);
  bool _saving = false;
  String? _error;
  String get _slug => _text.text.trim();
  bool get _valid => RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(_slug);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _slug == _original) return;
    if (!_valid) {
      setState(() => _error = 'Начните с латинской буквы или цифры. Используйте a–z, 0–9, дефис и подчёркивание');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final renamed = await widget.controller.trySetSlug(_slug);
      if (!mounted) return;
      if (renamed) {
        Navigator.pop(context);
      } else {
        setState(() {
          _saving = false;
          _error = UiStrings.slugTaken;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить идентификатор. Попробуйте ещё раз';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Изменить идентификатор'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Изменится имя папки и ZIP-файла. Настройки модуля сохранятся'),
            const SizedBox(height: 24),
            TextField(
              controller: _text,
              autofocus: true,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Идентификатор модуля',
                helperText: 'Строчные латинские буквы, цифры, дефис и подчёркивание',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        SodaliteButton.secondary(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Отмена')),
        SodaliteButton.primary(
          onPressed: _saving || _slug == _original || !_valid ? null : _save,
          inProgress: _saving,
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}
