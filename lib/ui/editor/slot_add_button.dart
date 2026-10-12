import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';

class SlotAddButton extends StatelessWidget {
  const SlotAddButton({
    super.key,
    required this.parentId,
    required this.slot,
    required this.catalog,
    required this.controller,
  });

  final String parentId;
  final SlotSpec slot;
  final Catalog catalog;
  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    final label = slot.allowedTypeIds.length == 1
        ? _addLabel(slot.allowedTypeIds.single)
        : switch (slot.key) {
            'actions' => 'Добавить действие',
            'filter' => 'Добавить фильтр',
            _ => 'Добавить блок',
          };

    Widget button(VoidCallback onPressed) =>
        SodaliteButton.ghost(icon: const Icon(Icons.add, size: 20), label: Text(label), onPressed: onPressed);

    if (slot.allowedTypeIds.length == 1) {
      return Align(
        key: Key('slot-add-$parentId-${slot.key}'),
        alignment: Alignment.centerLeft,
        child: button(
          () => controller.addChild(parentId: parentId, slot: slot.key, typeId: slot.allowedTypeIds.single),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SodaliteMenuButton<String>(
        key: Key('slot-add-$parentId-${slot.key}'),
        tooltip: label,
        onSelected: (typeId) {
          controller.addChild(parentId: parentId, slot: slot.key, typeId: typeId);
        },
        itemBuilder: (context) => [
          for (final typeId in slot.allowedTypeIds)
            SodaliteMenuItem<String>(value: typeId, label: catalog.type(typeId).labelRu, icon: Icons.add),
        ],
        trigger: button,
      ),
    );
  }
}

String _addLabel(String typeId) => switch (typeId) {
  TypeIds.layer => 'Добавить слой',
  TypeIds.geoSource => 'Добавить источник',
  TypeIds.geoStyle => 'Добавить оформление',
  TypeIds.geoRule => 'Добавить правило',
  TypeIds.info => 'Добавить карточку объекта',
  TypeIds.infoSection => 'Добавить раздел информации',
  TypeIds.fieldRow => 'Добавить поле',
  TypeIds.imageSection => 'Добавить изображения',
  TypeIds.attachmentSection => 'Добавить вложения',
  TypeIds.inspectionTab => 'Добавить вкладку инспекции',
  TypeIds.inspectionObject => 'Добавить объект инспекции',
  TypeIds.inspectionCreation => 'Добавить создание при инспекции',
  TypeIds.geometryType => 'Добавить тип геометрии',
  TypeIds.searchObject => 'Добавить объект поиска',
  TypeIds.searchFilterGroup => 'Добавить группу фильтра',
  _ => 'Добавить блок',
};
