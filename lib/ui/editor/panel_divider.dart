import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:sodalite_configurator/ui/design_system.dart';

/// A desktop splitter. Delta follows the pointer; callers enforce pane limits.
class PanelDivider extends StatefulWidget {
  const PanelDivider({
    super.key,
    required this.label,
    required this.onDelta,
    required this.onReset,
    this.headerHeight = 0,
  });
  final String label;
  final ValueChanged<double> onDelta;
  final VoidCallback onReset;
  final double headerHeight;

  @override
  State<PanelDivider> createState() => _PanelDividerState();
}

class _PanelDividerState extends State<PanelDivider> {
  bool _focused = false;
  bool _dragging = false;
  int? _activePointer;
  double? _lastPointerX;

  void _startDrag(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _lastPointerX = event.position.dx;
  }

  void _updateDrag(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final previousX = _lastPointerX;
    _lastPointerX = event.position.dx;
    if (previousX != null && event.position.dx != previousX) {
      if (!_dragging) setState(() => _dragging = true);
      widget.onDelta(event.position.dx - previousX);
    }
  }

  void _endDrag(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _lastPointerX = null;
    if (_dragging) setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: SodaliteColors.canvas),
        if (widget.headerHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.headerHeight,
            child: const ColoredBox(color: SodaliteColors.surface),
          ),
        Semantics(
          enabled: true,
          label: widget.label,
          hint: 'Перетащите или используйте стрелки влево и вправо. Двойной щелчок сбрасывает ширину',
          onIncrease: () => widget.onDelta(16),
          onDecrease: () => widget.onDelta(-16),
          child: Focus(
            onFocusChange: (value) => setState(() => _focused = value),
            onKeyEvent: (_, event) {
              if (event is KeyUpEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                widget.onDelta(-16);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                widget.onDelta(16);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.home) {
                widget.onReset();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: widget.onReset,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _startDrag,
                  onPointerMove: _updateDrag,
                  onPointerUp: _endDrag,
                  onPointerCancel: _endDrag,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _focused || _dragging ? SodaliteColors.accent : SodaliteColors.icon,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
