import 'package:flutter/material.dart';
import 'package:sodalite_configurator/metadata/metadata_controller.dart';

class MetadataScope extends InheritedNotifier<MetadataController> {
  const MetadataScope({super.key, required MetadataController controller, required super.child})
    : super(notifier: controller);

  static MetadataController? read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<MetadataScope>();
    final widget = element?.widget;
    return widget is MetadataScope ? widget.notifier : null;
  }
}
