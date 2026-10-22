import 'package:flutter/material.dart';
import 'package:sodalite_configurator/metadata/metadata_catalog.dart';
import 'package:sodalite_configurator/metadata/metadata_controller.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/draft_time.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_scope.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';
import 'package:sodalite_configurator/ui/strings.dart';

Future<void> showMetadataDialog(BuildContext context) {
  final metadata = MetadataScope.read(context);
  if (metadata == null) return Future<void>.value();
  return showSodaliteDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: metadata,
      builder: (context, _) => _MetadataDialog(metadata: metadata),
    ),
  );
}

class _MetadataDialog extends StatelessWidget {
  const _MetadataDialog({required this.metadata});

  final MetadataController metadata;

  @override
  Widget build(BuildContext context) {
    final catalog = metadata.catalog;
    final reading = metadata.busy;
    return AlertDialog(
      title: const Text('Метаданные'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              catalog == null
                  ? 'Откройте файл .gmfull, сохранённый в редакторе метаданных. '
                        'Конфигуратор оставит карточки и поля. Сам файл в браузере не хранится, '
                        'а список карточек остаётся в этом браузере после закрытия вкладки.'
                  : 'Загружен файл «${catalog.fileName}», ${formatDraftWhen(catalog.importedAt)}. '
                        '${metadataCountLabel(catalog.cards.length, cards: true)}. '
                        'Список хранится в этом браузере.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (reading) ...[
              const SizedBox(height: 16),
              Text(_readingLabel(metadata), style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (metadata.error case final message?) ...[
              const SizedBox(height: 16),
              Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.errorText)),
            ],
          ],
        ),
      ),
      actions: [
        if (catalog != null)
          SodaliteButton.ghost(
            key: const Key('metadataClear'),
            onPressed: reading ? null : () => _clear(context),
            child: const Text('Убрать'),
          ),
        SodaliteButton.secondary(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        SodaliteButton.primary(
          key: const Key('metadataOpenFile'),
          onPressed: reading ? null : () => metadata.importFile(),
          child: Text(catalog == null ? 'Открыть gmfull' : 'Заменить файл'),
        ),
      ],
    );
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showSodaliteDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Убрать метаданные'),
        content: const SizedBox(
          width: 440,
          child: Text('Загруженные карточки будут убраны из этого браузера. Поля модуля не изменятся.'),
        ),
        actions: [
          SodaliteButton.secondary(onPressed: () => Navigator.pop(context, false), child: const Text(UiStrings.cancel)),
          SodaliteButton.destructive(onPressed: () => Navigator.pop(context, true), child: const Text('Убрать')),
        ],
      ),
    );
    if (confirmed == true) await metadata.clear();
  }
}

String _readingLabel(MetadataController metadata) {
  final read = metadata.bytesRead;
  final total = metadata.bytesTotal;
  if (read == null || total == null || total == 0) return 'Читаем файл…';
  return 'Читаем файл, ${_megabytes(read)} из ${_megabytes(total)} МБ';
}

String _megabytes(int bytes) {
  final value = bytes / (1024 * 1024);
  return value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
