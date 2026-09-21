import 'package:flutter/material.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/ui/strings.dart';

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
    final label = slot.key == 'additionalLayers'
        ? UiStrings.addAdditionalLayer
        : slot.allowedTypeIds.length == 1
        ? catalog.type(slot.allowedTypeIds.single).labelRu
        : slot.key;

    return PopupMenuButton<String>(
      key: Key('slot-add-$parentId-${slot.key}'),
      tooltip: label,
      onSelected: (typeId) {
        controller.addChild(parentId: parentId, slot: slot.key, typeId: typeId);
      },
      itemBuilder: (context) => [
        for (final typeId in slot.allowedTypeIds)
          PopupMenuItem<String>(value: typeId, child: Text(catalog.type(typeId).labelRu)),
      ],
      child: DashedSlotButton(label: label),
    );
  }
}

class DashedSlotButton extends StatelessWidget {
  const DashedSlotButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    final content = CustomPaint(
      painter: _DashedRectPainter(color: color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );

    if (onPressed == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onPressed, child: content),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)));
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
