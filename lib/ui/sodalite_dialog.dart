import 'package:flutter/material.dart';

const _openDuration = Duration(milliseconds: 250);
const _closeDuration = Duration(milliseconds: 150);
const _modalEase = Cubic(0.22, 1, 0.36, 1);

/// Shows a Material dialog with the same result and dismissal semantics as
/// [showDialog], using the app's shared open and close transition.
Future<T?> showSodaliteDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

  return navigator.push<T>(
    _SodaliteDialogRoute<T>(
      context: context,
      builder: builder,
      themes: themes,
      barrierDismissible: barrierDismissible,
      barrierColor:
          DialogTheme.of(context).barrierColor ?? Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
      reduceMotion: reduceMotion,
    ),
  );
}

class _SodaliteDialogRoute<T> extends DialogRoute<T> {
  _SodaliteDialogRoute({
    required super.context,
    required super.builder,
    required super.themes,
    required super.barrierDismissible,
    required super.barrierColor,
    required bool reduceMotion,
  }) : _reduceMotion = reduceMotion,
       super(animationStyle: AnimationStyle(duration: reduceMotion ? Duration.zero : _openDuration));

  final bool _reduceMotion;
  CurvedAnimation? _curvedAnimation;

  @override
  Duration get reverseTransitionDuration => _reduceMotion ? Duration.zero : _closeDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reduceMotion) return child;

    if (_curvedAnimation?.parent != animation) {
      _curvedAnimation?.dispose();
      _curvedAnimation = CurvedAnimation(parent: animation, curve: _modalEase, reverseCurve: _modalEase);
    }
    return FadeTransition(
      opacity: _curvedAnimation!,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(_curvedAnimation!),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    super.dispose();
  }
}
