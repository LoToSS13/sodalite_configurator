import 'package:flutter/material.dart';
import 'package:sodalite_configurator/metadata/metadata_catalog.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';
import 'package:sodalite_configurator/ui/sodalite_search_field.dart';
import 'package:sodalite_configurator/ui/strings.dart';

Future<MetadataCard?> showMetadataCardPicker(BuildContext context, MetadataCatalog catalog) {
  return showSodaliteDialog<MetadataCard>(
    context: context,
    builder: (context) => _PickerDialog<MetadataCard>(
      title: 'Карточка',
      searchLabel: 'Поиск карточки',
      items: catalog.cards,
      titleOf: _cardTitle,
      subtitleOf: (card) => '${metadataTypeTitle(card.type)} · ${metadataCountLabel(card.fields.length, cards: false)}',
      matches: (card, query) => _matches(query, card.alias, card.name),
    ),
  );
}

Future<MetadataField?> showMetadataFieldPicker(BuildContext context, MetadataCatalog catalog, MetadataCard card) {
  return showSodaliteDialog<MetadataField>(
    context: context,
    builder: (context) => _PickerDialog<MetadataField>(
      title: _cardTitle(card),
      searchLabel: 'Поиск поля',
      items: card.fields,
      titleOf: _fieldTitle,
      subtitleOf: (field) => _fieldSubtitle(catalog, field),
      matches: (field, query) => _matches(query, field.alias, field.name),
      emptyText: 'У этой карточки нет полей',
    ),
  );
}

class _PickerDialog<T> extends StatefulWidget {
  const _PickerDialog({
    required this.title,
    required this.searchLabel,
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.matches,
    this.emptyText = 'Ничего не найдено',
  });

  final String title;
  final String searchLabel;
  final List<T> items;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final bool Function(T item, String query) matches;
  final String emptyText;

  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final item in widget.items)
        if (widget.matches(item, _query)) item,
    ];
    return AlertDialog(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(
          children: [
            SodaliteSearchField(
              hintText: 'Псевдоним или имя',
              semanticLabel: widget.searchLabel,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: shown.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        _query.isEmpty ? widget.emptyText : 'Ничего не найдено',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final item = shown[index];
                        final subtitle = widget.subtitleOf(item);
                        return InkWell(
                          onTap: () => Navigator.pop(context, item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.titleOf(item), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [SodaliteButton.secondary(onPressed: () => Navigator.pop(context), child: const Text(UiStrings.cancel))],
    );
  }
}

String _cardTitle(MetadataCard card) => card.name.isEmpty ? card.alias : '${card.alias}  ${card.name}';

String _fieldTitle(MetadataField field) => field.name.isEmpty ? field.alias : '${field.alias}  ${field.name}';

String _fieldSubtitle(MetadataCatalog catalog, MetadataField field) {
  final parts = <String>[];
  if (field.column case final column?) parts.add(column);
  if (field.domain case final domain?) parts.add(domain);
  if (field.reference case final reference?) {
    final target = catalog.card(reference);
    final name = target == null || target.name.isEmpty ? reference : target.name;
    parts.add('ссылка на $name');
  }
  if (field.section case final section?) parts.add('секция $section');
  if (field.required) parts.add('обязательное');
  if (field.hidden) parts.add('скрыто');
  return parts.join(' · ');
}

bool _matches(String query, String alias, String name) {
  if (query.isEmpty) return true;
  return alias.toLowerCase().contains(query) || name.toLowerCase().contains(query);
}
