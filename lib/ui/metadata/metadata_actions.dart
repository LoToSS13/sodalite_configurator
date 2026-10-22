import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/metadata/metadata_catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_dialog.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_picker.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_scope.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:sodalite_configurator/ui/sodalite_toast.dart';

class MetadataFieldButton extends StatelessWidget {
  const MetadataFieldButton({super.key, required this.sectionId, required this.controller});

  final String sectionId;
  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    if (MetadataScope.read(context) == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: SodaliteButton.ghost(
        key: Key('metadata-field-$sectionId'),
        onPressed: () => addMetadataFieldRow(context: context, document: controller, sectionId: sectionId),
        child: const Text('Поле из метаданных'),
      ),
    );
  }
}

Future<MetadataCard?> chooseMetadataCard(BuildContext context) async {
  final metadata = MetadataScope.read(context);
  if (metadata == null) return null;
  final catalog = metadata.catalog;
  if (catalog == null) {
    await showMetadataDialog(context);
    return null;
  }
  return showMetadataCardPicker(context, catalog);
}

Future<void> addMetadataFieldRow({
  required BuildContext context,
  required DocumentController document,
  required String sectionId,
}) async {
  final metadata = MetadataScope.read(context);
  if (metadata == null) return;
  final catalog = metadata.catalog;
  if (catalog == null) {
    await showMetadataDialog(context);
    return;
  }
  final info = enclosingInfo(document.root, sectionId);
  final alias = info?.fields['alias'];
  var card = alias is String ? catalog.card(alias) : null;
  if (card == null) {
    if (!context.mounted) return;
    card = await showMetadataCardPicker(context, catalog);
    if (card == null || !context.mounted || info == null) return;
    document.setField(info.id, 'alias', card.alias);
  }
  if (!context.mounted) return;
  final field = await showMetadataFieldPicker(context, catalog, card);
  if (field == null || !context.mounted) return;
  document.addChild(
    parentId: sectionId,
    slot: 'fields',
    typeId: TypeIds.fieldRow,
    fields: {'name': field.name.isEmpty ? field.alias : field.name, 'content': '{${field.alias}}'},
  );
}

Future<MetadataField?> pickMetadataField(
  BuildContext context, {
  required String? alias,
  required String infoId,
  required DocumentController document,
}) async {
  final metadata = MetadataScope.read(context);
  if (metadata == null) return null;
  final catalog = metadata.catalog;
  if (catalog == null) {
    await showMetadataDialog(context);
    return null;
  }
  var card = alias == null ? null : catalog.card(alias);
  if (card == null) {
    if (!context.mounted) return null;
    card = await showMetadataCardPicker(context, catalog);
    if (card == null || !context.mounted) return null;
    document.setField(infoId, 'alias', card.alias);
  }
  if (!context.mounted) return null;
  return showMetadataFieldPicker(context, catalog, card);
}

void notifyDuplicatePath(BuildContext context, String alias) {
  SodaliteToast.show(context, message: 'Путь $alias уже есть', kind: SodaliteToastKind.info);
}

Node? enclosingInfo(Node root, String nodeId) {
  Node? found;
  bool walk(Node node) {
    if (node.id == nodeId) {
      if (node.typeId == TypeIds.info) found = node;
      return true;
    }
    for (final children in node.childrenBySlot.values) {
      for (final child in children) {
        if (!walk(child)) continue;
        if (found == null && node.typeId == TypeIds.info) found = node;
        return true;
      }
    }
    return false;
  }

  walk(root);
  return found;
}
