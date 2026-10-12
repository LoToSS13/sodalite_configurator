import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Flutter equivalent of transitions.dev's Accordion expand motion.
/// The content remains mounted until the closing animation completes.
class SodaliteAccordionPanel extends StatefulWidget {
  const SodaliteAccordionPanel({super.key, required this.expanded, required this.builder});

  final bool expanded;
  final WidgetBuilder builder;

  @override
  State<SodaliteAccordionPanel> createState() => _SodaliteAccordionPanelState();
}

class _SodaliteAccordionPanelState extends State<SodaliteAccordionPanel> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 250);
  static const _ease = Cubic(0.22, 1, 0.36, 1);
  late final _controller = AnimationController(
    vsync: this,
    duration: _duration,
    reverseDuration: _duration,
    value: widget.expanded ? 1 : 0,
  )..addStatusListener(_onStatus);
  late final _progress = CurvedAnimation(parent: _controller, curve: _ease, reverseCurve: _ease.flipped);
  late bool _showContent = widget.expanded;
  bool _reduceMotion = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.expanded && _showContent && mounted) {
      setState(() => _showContent = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _controller.value = widget.expanded ? 1 : 0;
      _showContent = widget.expanded;
    }
  }

  @override
  void didUpdateWidget(SodaliteAccordionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (widget.expanded) _showContent = true;
    if (_reduceMotion) {
      _controller.value = widget.expanded ? 1 : 0;
      _showContent = widget.expanded;
    } else if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showContent) return const SizedBox.shrink();
    return SizeTransition(
      sizeFactor: _progress,
      axisAlignment: -1,
      child: IgnorePointer(
        ignoring: !widget.expanded,
        child: ExcludeFocus(
          excluding: !widget.expanded,
          child: ExcludeSemantics(
            excluding: !widget.expanded,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, child) {
                final blur = 2 * (1 - _progress.value);
                return Opacity(
                  opacity: _progress.value,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: child,
                  ),
                );
              },
              child: RepaintBoundary(child: widget.builder(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class SodaliteAccordionChevron extends StatelessWidget {
  const SodaliteAccordionChevron({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      curve: const Cubic(0.22, 1, 0.36, 1),
      transformAlignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1, expanded ? -1 : 1, 1),
      child: const Icon(Icons.expand_more),
    );
  }
}
