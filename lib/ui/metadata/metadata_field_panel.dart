import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/metadata/metadata_catalog.dart';
import 'package:sodalite_configurator/metadata/metadata_controller.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_dialog.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_scope.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_search_field.dart';

/// Fields of the loaded gmfull, beside the object card.
///
/// The list opens a card and any link field. Back and the breadcrumbs return.
/// A placed value uses the aliases joined by ".".
class MetadataFieldPanel extends StatefulWidget {
  const MetadataFieldPanel({super.key, required this.infoId, required this.controller});

  final String infoId;
  final DocumentController controller;

  @override
  State<MetadataFieldPanel> createState() => _MetadataFieldPanelState();
}

class _Frame {
  const _Frame(this.cardAlias, this.via);

  final String cardAlias;
  final String? via;
}

class _MetadataFieldPanelState extends State<MetadataFieldPanel> {
  final List<_Frame> _stack = [];
  var _followAlias = true;
  String? _anchoredAlias;
  var _query = '';

  ButtonStyle _compact(BuildContext context) {
    return TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      maximumSize: const Size(220, 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      textStyle: Theme.of(context).textTheme.bodySmall,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  void didUpdateWidget(covariant MetadataFieldPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.infoId == widget.infoId) return;
    _followAlias = true;
    _anchoredAlias = null;
    _stack.clear();
    _query = '';
  }

  void _syncAlias(MetadataCatalog? catalog, String alias) {
    if (!_followAlias || _anchoredAlias == alias) return;
    if (catalog == null) {
      _anchoredAlias = null;
      return;
    }
    _anchoredAlias = alias;
    _query = '';
    _stack.clear();
    if (catalog.card(alias) != null) _stack.add(_Frame(alias, null));
  }

  void _showList() {
    setState(() {
      _followAlias = false;
      _query = '';
      _stack.clear();
    });
  }

  void _back() {
    if (_stack.length <= 1) {
      _showList();
      return;
    }
    setState(() {
      _query = '';
      _stack.removeLast();
    });
  }

  void _jump(int crumb) {
    if (crumb <= 0) {
      _showList();
      return;
    }
    setState(() {
      _query = '';
      _followAlias = true;
      while (_stack.length > crumb) {
        _stack.removeLast();
      }
    });
  }

  void _openCard(MetadataCatalog catalog, String alias) {
    if (catalog.card(alias) == null) return;
    setState(() {
      _followAlias = true;
      _anchoredAlias = alias;
      _query = '';
      _stack
        ..clear()
        ..add(_Frame(alias, null));
    });
    widget.controller.setField(widget.infoId, 'alias', alias);
  }

  void _openLink(MetadataField field) {
    final target = field.reference;
    if (target == null) return;
    setState(() {
      _query = '';
      _stack.add(_Frame(target, field.alias));
    });
  }

  String _chain(String leaf) {
    final parts = [
      for (final frame in _stack)
        if (frame.via != null) frame.via!,
    ];
    parts.add(leaf);
    return parts.join('.');
  }

  String _prefix() {
    return [
      for (final frame in _stack)
        if (frame.via != null) frame.via!,
    ].join('.');
  }

  @override
  Widget build(BuildContext context) {
    final metadata = MetadataScope.read(context);
    if (metadata == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([metadata, widget.controller]),
      builder: (context, _) {
        final info = widget.controller.root.find(widget.infoId);
        if (info == null) return const SizedBox.shrink();
        final alias = info.fields['alias'];
        _syncAlias(metadata.catalog, alias is String ? alias : '');
        return _PanelShell(
          child: metadata.catalog == null
              ? _EmptyCatalog(metadata: metadata)
              : _LoadedPanel(
                  catalog: metadata.catalog!,
                  info: info,
                  stack: _stack,
                  query: _query,
                  compact: _compact(context),
                  prefix: _prefix(),
                  onQuery: (value) => setState(() => _query = value.trim().toLowerCase()),
                  onBack: _stack.isEmpty ? null : _back,
                  onJump: _jump,
                  onOpenCard: (alias) => _openCard(metadata.catalog!, alias),
                  onOpenLink: _openLink,
                  chain: _chain,
                  onPlace: (path, slot, leafName) => _place(info, path, slot, leafName),
                  placed: _placed(info),
                ),
        );
      },
    );
  }

  _Placed _placed(Node info) {
    final title = info.fields['titleContent'];
    return _Placed(title: title is String ? title : '', paths: _pathKeys(info), rows: _rowTokens(info));
  }

  Set<String> _pathKeys(Node info) => {for (final entry in _pathEntries(info)) entry.key};

  Set<String> _rowTokens(Node info) {
    final tokens = <String>{};
    for (final section in info.childrenBySlot['infoSections'] ?? const <Node>[]) {
      for (final row in section.childrenBySlot['fields'] ?? const <Node>[]) {
        final content = row.fields['content'];
        if (content is String) tokens.add(content);
      }
    }
    return tokens;
  }

  void _place(Node info, String path, _Slot slot, String leafName) {
    final token = '{$path}';
    if (slot == _Slot.title) {
      final current = info.fields['titleContent'];
      widget.controller.setField(widget.infoId, 'titleContent', current == token ? '' : token);
      return;
    }
    if (slot == _Slot.path) {
      final entries = _pathEntries(info);
      if (entries.any((entry) => entry.key == path)) {
        entries.removeWhere((entry) => entry.key == path);
      } else {
        entries.add(MapEntry(path, path));
      }
      _writePaths(entries);
      return;
    }
    final existing = _rowWith(info, token);
    if (existing != null) {
      widget.controller.removeNode(existing.id);
      return;
    }
    final sections = info.childrenBySlot['infoSections'] ?? const <Node>[];
    final sectionId = sections.isEmpty
        ? widget.controller.addChild(parentId: info.id, slot: 'infoSections', typeId: TypeIds.infoSection)
        : sections.first.id;
    if (sectionId == null) return;
    widget.controller.addChild(
      parentId: sectionId,
      slot: 'fields',
      typeId: TypeIds.fieldRow,
      fields: {'name': leafName.isEmpty ? path.split('.').last : leafName, 'content': token},
    );
  }

  Node? _rowWith(Node info, String token) {
    for (final section in info.childrenBySlot['infoSections'] ?? const <Node>[]) {
      for (final row in section.childrenBySlot['fields'] ?? const <Node>[]) {
        if (row.fields['content'] == token) return row;
      }
    }
    return null;
  }

  List<MapEntry<String, String>> _pathEntries(Node info) {
    final value = info.fields['paths'];
    if (value is Map) {
      return [
        for (final entry in value.entries)
          if (entry.key is String && entry.value is String) MapEntry(entry.key as String, entry.value as String),
      ];
    }
    if (value is List) {
      return [
        for (final item in value)
          if (item is Map && item['key'] is String && item['value'] is String)
            MapEntry(item['key'] as String, item['value'] as String),
      ];
    }
    return [];
  }

  void _writePaths(List<MapEntry<String, String>> entries) {
    final keys = [for (final entry in entries) entry.key];
    final blank = keys.any((key) => key.trim().isEmpty);
    final duplicated = keys.length != keys.toSet().length;
    final Object value = blank || duplicated
        ? [
            for (final entry in entries) {'key': entry.key, 'value': entry.value},
          ]
        : {for (final entry in entries) entry.key: entry.value};
    widget.controller.setField(widget.infoId, 'paths', value);
  }
}

enum _Slot { title, path, row }

class _Placed {
  const _Placed({required this.title, required this.paths, required this.rows});

  final String title;
  final Set<String> paths;
  final Set<String> rows;
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SodaliteColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SodaliteColors.border),
      ),
      child: SizedBox(height: 640, child: child),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.metadata});

  final MetadataController metadata;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Поля метаданных', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Откройте файл .gmfull. Панель покажет карточки и ссылки между ними.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
          ),
          if (metadata.error case final message?) ...[
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.errorText)),
          ],
          const SizedBox(height: 16),
          SodaliteButton.primary(
            key: const Key('metadataPanelOpen'),
            onPressed: () => showMetadataDialog(context),
            child: const Text('Открыть gmfull'),
          ),
        ],
      ),
    );
  }
}

class _LoadedPanel extends StatelessWidget {
  const _LoadedPanel({
    required this.catalog,
    required this.info,
    required this.stack,
    required this.query,
    required this.compact,
    required this.prefix,
    required this.onQuery,
    required this.onBack,
    required this.onJump,
    required this.onOpenCard,
    required this.onOpenLink,
    required this.chain,
    required this.onPlace,
    required this.placed,
  });

  final MetadataCatalog catalog;
  final Node info;
  final List<_Frame> stack;
  final String query;
  final ButtonStyle compact;
  final String prefix;
  final ValueChanged<String> onQuery;
  final VoidCallback? onBack;
  final ValueChanged<int> onJump;
  final ValueChanged<String> onOpenCard;
  final ValueChanged<MetadataField> onOpenLink;
  final String Function(String leaf) chain;
  final void Function(String path, _Slot slot, String leafName) onPlace;
  final _Placed placed;

  @override
  Widget build(BuildContext context) {
    final frame = stack.isEmpty ? null : stack.last;
    final card = frame == null ? null : catalog.card(frame.cardAlias);
    final alias = info.fields['alias'];
    final moduleAlias = alias is String ? alias : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Breadcrumb(catalog: catalog, stack: stack, compact: compact, onJump: onJump),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card == null ? 'Карточки' : '${card.alias}  ${card.name.isEmpty ? card.alias : card.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card == null
                              ? 'Выберите карточку, чтобы открыть её поля'
                              : prefix.isEmpty
                              ? '${metadataTypeTitle(card.type)} · корень карточки модуля'
                              : '${metadataTypeTitle(card.type)} · путь $prefix',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  if (onBack != null)
                    SodaliteButton.secondary(
                      key: const Key('metadataPanelBack'),
                      style: compact,
                      onPressed: onBack,
                      child: const Text('Назад'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SodaliteSearchField(
                key: ValueKey(stack.map((frame) => '${frame.cardAlias}:${frame.via}').join('/')),
                hintText: 'Псевдоним или имя',
                semanticLabel: card == null ? 'Поиск карточки' : 'Поиск поля',
                onChanged: onQuery,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: SodaliteColors.muted),
        Expanded(
          child: card == null
              ? _CardList(
                  catalog: catalog,
                  query: query,
                  moduleAlias: moduleAlias,
                  compact: compact,
                  onOpen: onOpenCard,
                )
              : _FieldList(
                  catalog: catalog,
                  card: card,
                  query: query,
                  compact: compact,
                  chain: chain,
                  placed: placed,
                  onOpenLink: onOpenLink,
                  onPlace: onPlace,
                ),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.catalog, required this.stack, required this.compact, required this.onJump});

  final MetadataCatalog catalog;
  final List<_Frame> stack;
  final ButtonStyle compact;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final labels = ['Карточки'];
    for (var index = 0; index < stack.length; index++) {
      final frame = stack[index];
      if (index == 0 || frame.via == null) {
        final card = catalog.card(frame.cardAlias);
        labels.add(card == null || card.name.isEmpty ? frame.cardAlias : card.name);
        continue;
      }
      final parent = catalog.card(stack[index - 1].cardAlias);
      final via = parent?.fields.where((field) => field.alias == frame.via).firstOrNull;
      final name = via == null || via.name.isEmpty ? frame.via! : via.name;
      labels.add(name);
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var index = 0; index < labels.length; index++)
          SodaliteButton.ghost(
            key: Key('metadataCrumb-$index'),
            style: compact,
            onPressed: index == labels.length - 1 ? null : () => onJump(index),
            child: Text(labels[index]),
          ),
      ],
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({
    required this.catalog,
    required this.query,
    required this.moduleAlias,
    required this.compact,
    required this.onOpen,
  });

  final MetadataCatalog catalog;
  final String query;
  final String moduleAlias;
  final ButtonStyle compact;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final card in catalog.cards)
        if (_matches(query, card.alias, card.name)) card,
    ];
    if (cards.isEmpty) {
      return const _EmptyLine('Ничего не найдено');
    }
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final current = card.alias == moduleAlias;
        return _Line(
          title: '${card.alias}  ${card.name.isEmpty ? card.alias : card.name}',
          meta:
              '${metadataTypeTitle(card.type)}${current ? ' · карточка этого модуля' : ''} · ${metadataCountLabel(card.fields.length, cards: false)}',
          trailing: SodaliteButton.ghost(
            key: Key('metadataOpenCard-${card.alias}'),
            style: compact,
            onPressed: () => onOpen(card.alias),
            child: const Text('Открыть'),
          ),
        );
      },
    );
  }
}

class _FieldList extends StatelessWidget {
  const _FieldList({
    required this.catalog,
    required this.card,
    required this.query,
    required this.compact,
    required this.chain,
    required this.placed,
    required this.onOpenLink,
    required this.onPlace,
  });

  final MetadataCatalog catalog;
  final MetadataCard card;
  final String query;
  final ButtonStyle compact;
  final String Function(String leaf) chain;
  final _Placed placed;
  final ValueChanged<MetadataField> onOpenLink;
  final void Function(String path, _Slot slot, String leafName) onPlace;

  @override
  Widget build(BuildContext context) {
    final fields = [
      for (final field in card.fields)
        if (_matches(query, field.alias, field.name)) field,
    ];
    if (fields.isEmpty) {
      return _EmptyLine(query.isEmpty ? 'У этой карточки нет полей' : 'Ничего не найдено');
    }
    return ListView.builder(
      itemCount: fields.length,
      itemBuilder: (context, index) {
        final field = fields[index];
        final path = chain(field.alias);
        final token = '{$path}';
        final target = field.reference == null ? null : catalog.card(field.reference!);
        final leaf = field.name.isEmpty ? field.alias : field.name;
        return _Line(
          title: '${field.alias}  $leaf',
          meta: '${_fieldMeta(catalog, field)}${path.contains('.') ? ' · $path' : ''}',
          trailing: target == null
              ? null
              : SodaliteButton.secondary(
                  key: Key('metadataDeeper-$path'),
                  style: compact,
                  onPressed: () => onOpenLink(field),
                  child: const Text('Дальше'),
                ),
          footer: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _slotButton(
                label: 'Заголовок',
                active: placed.title == token,
                onPressed: () => onPlace(path, _Slot.title, leaf),
              ),
              _slotButton(
                label: 'Путь',
                active: placed.paths.contains(path),
                onPressed: () => onPlace(path, _Slot.path, leaf),
              ),
              _slotButton(
                label: 'Раздел',
                active: placed.rows.contains(token),
                onPressed: () => onPlace(path, _Slot.row, leaf),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _slotButton({required String label, required bool active, required VoidCallback onPressed}) {
    final button = active
        ? SodaliteButton.primary(style: compact, onPressed: onPressed, child: Text(label))
        : SodaliteButton.ghost(style: compact, onPressed: onPressed, child: Text(label));
    return button;
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.meta, this.trailing, this.footer});

  final String title;
  final String meta;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SodaliteColors.muted)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary)),
    );
  }
}

String _fieldMeta(MetadataCatalog catalog, MetadataField field) {
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
