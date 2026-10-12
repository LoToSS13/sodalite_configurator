import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/sodalite_tooltip.dart';
import 'design_system.dart';
import 'sodalite_buttons.dart';

enum SodaliteToastKind { success, error, info }

/// Figma Toast 1214:24403 with transitions.dev Toast open/close motion.
abstract final class SodaliteToast {
  static final _active = Expando<_ToastHandle>();

  /// Returns a safe dismissal callback, including after replacement or timeout.
  static VoidCallback show(
    BuildContext context, {
    required String message,
    SodaliteToastKind kind = SodaliteToastKind.success,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    assert((actionLabel == null) == (onAction == null));
    final overlay = Overlay.of(context, rootOverlay: true);
    _active[overlay]?.removeImmediately();

    final needsMoreTime = onAction != null || kind == SodaliteToastKind.error;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: SodaliteColors.surface);
    double measure(String value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final actionWidth = actionLabel == null ? 0.0 : math.max(44.0, measure(actionLabel) + 24);
    final width = math.max(
      0.0,
      math.min(
        math.min(560.0, MediaQuery.sizeOf(context).width - 48),
        measure(message) + 60 + (needsMoreTime ? 48 : 0) + (onAction != null ? actionWidth + 8 : 0),
      ),
    );

    final key = GlobalKey<_ToastOverlayState>();
    late final _ToastHandle handle;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        key: key,
        width: width,
        actionWidth: actionWidth,
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                handle.dismiss();
                onAction();
              },
        showClose: needsMoreTime,
        onClose: () => handle.dismiss(),
        onHidden: () => handle.removeImmediately(),
      ),
    );
    handle = _ToastHandle(
      entry: entry,
      key: key,
      onRemoved: () {
        if (_active[overlay] == handle) _active[overlay] = null;
      },
    );
    _active[overlay] = handle;
    overlay.insert(entry);
    handle.startTimer(Duration(seconds: needsMoreTime ? 8 : 4));
    return handle.dismiss;
  }
}

class _ToastHandle {
  _ToastHandle({required this.entry, required this.key, required this.onRemoved});

  final OverlayEntry entry;
  final GlobalKey<_ToastOverlayState> key;
  final VoidCallback onRemoved;
  Timer? _timer;
  bool _removed = false;

  void startTimer(Duration duration) => _timer = Timer(duration, dismiss);

  void dismiss() {
    if (_removed) return;
    _timer?.cancel();
    final state = key.currentState;
    if (state == null) {
      removeImmediately();
    } else {
      state.close();
    }
  }

  void removeImmediately() {
    if (_removed) return;
    _removed = true;
    _timer?.cancel();
    entry.remove();
    entry.dispose();
    onRemoved();
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    super.key,
    required this.width,
    required this.actionWidth,
    required this.message,
    required this.kind,
    required this.actionLabel,
    required this.onAction,
    required this.showClose,
    required this.onClose,
    required this.onHidden,
  });

  final double width;
  final double actionWidth;
  final String message;
  final SodaliteToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showClose;
  final VoidCallback onClose;
  final VoidCallback onHidden;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  static const _ease = Cubic(0.22, 1, 0.36, 1);
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 250),
  );
  late final _progress = CurvedAnimation(parent: _controller, curve: _ease, reverseCurve: _ease.flipped);
  bool _started = false;
  bool _closing = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (!_started) {
      _started = true;
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    } else if (_reduceMotion && !_closing) {
      _controller.value = 1;
    }
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    if (!_reduceMotion) await _controller.reverse();
    if (mounted) widget.onHidden();
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: SodaliteColors.surface);
    final bottomInset = math.max(MediaQuery.viewPaddingOf(context).bottom, MediaQuery.viewInsetsOf(context).bottom);
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24 + bottomInset,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, child) {
              final t = _reduceMotion ? 1.0 : _progress.value;
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - t)),
                  child: Transform.scale(
                    scale: .97 + .03 * t,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 2 * (1 - t), sigmaY: 2 * (1 - t)),
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: Material(
              color: SodaliteColors.text,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: widget.width,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          switch (widget.kind) {
                            SodaliteToastKind.success => Icons.check_circle,
                            SodaliteToastKind.error => Icons.cancel,
                            SodaliteToastKind.info => Icons.info_outline,
                          },
                          size: 24,
                          color: switch (widget.kind) {
                            SodaliteToastKind.success => SodaliteColors.success,
                            SodaliteToastKind.error => SodaliteColors.error,
                            SodaliteToastKind.info => SodaliteColors.surface,
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.message, style: style)),
                      if (widget.onAction != null) ...[
                        const SizedBox(width: 8),
                        _ToastControl(
                          width: widget.actionWidth,
                          onPressed: widget.onAction!,
                          child: Text(widget.actionLabel!, style: style.copyWith(decoration: TextDecoration.underline)),
                        ),
                      ],
                      if (widget.showClose) ...[
                        const SizedBox(width: 4),
                        SodaliteTooltip(
                          message: 'Закрыть уведомление',
                          child: _ToastControl(
                            width: 44,
                            onPressed: widget.onClose,
                            child: const Icon(Icons.close, size: 20, semanticLabel: 'Закрыть уведомление'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastControl extends StatelessWidget {
  const _ToastControl({required this.width, required this.onPressed, required this.child});
  final double width;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => SodalitePress(
    whiteOverlay: false,
    builder: (states) => TextButton(
      statesController: states,
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            minimumSize: Size(width, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: SodaliteColors.surface,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused) ? SodaliteColors.surface : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
      child: child,
    ),
  );
}
