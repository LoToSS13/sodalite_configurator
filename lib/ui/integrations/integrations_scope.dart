import 'package:flutter/material.dart';
import 'package:sodalite_configurator/integrations/integration_controller.dart';

class Integrations extends InheritedNotifier<IntegrationController> {
  const Integrations({super.key, required IntegrationController controller, required super.child})
    : super(notifier: controller);

  static IntegrationController? read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<Integrations>();
    final widget = element?.widget;
    return widget is Integrations ? widget.notifier : null;
  }
}
