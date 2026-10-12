import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/sodalite_tooltip.dart';
import 'package:flutter/physics.dart';
import 'design_system.dart';

enum _ButtonKind { primary, secondary, ghost, destructive }

/// Sodalite Button 169:13786: L52, pressed 1.04/100ms,
/// release spring 290ms/bounce .55, disabled opacity .6.
class SodaliteButton extends StatelessWidget {
  const SodaliteButton.primary({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.style,
    this.inProgress = false,
  }) : kind = _ButtonKind.primary;
  const SodaliteButton.secondary({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.style,
    this.inProgress = false,
  }) : kind = _ButtonKind.secondary;
  const SodaliteButton.ghost({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.style,
    this.inProgress = false,
  }) : kind = _ButtonKind.ghost;
  const SodaliteButton.destructive({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.style,
    this.inProgress = false,
  }) : kind = _ButtonKind.destructive;

  final VoidCallback? onPressed;
  final Widget? child, label, icon;
  final ButtonStyle? style;
  final bool inProgress;
  final _ButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final foreground = kind == _ButtonKind.primary || kind == _ButtonKind.destructive
        ? SodaliteColors.surface
        : kind == _ButtonKind.ghost
        ? SodaliteColors.accent
        : SodaliteColors.text;
    final background = switch (kind) {
      _ButtonKind.primary => SodaliteColors.accent,
      _ButtonKind.secondary => SodaliteColors.surface,
      _ButtonKind.ghost => Colors.transparent,
      _ButtonKind.destructive => SodaliteColors.errorText,
    };
    final base =
        TextButton.styleFrom(
              minimumSize: const Size(100, 52),
              maximumSize: const Size(400, double.infinity),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              foregroundColor: foreground,
              disabledForegroundColor: foreground,
              backgroundColor: background,
              disabledBackgroundColor: background,
              textStyle: Theme.of(context).textTheme.titleMedium,
              iconSize: 20,
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            )
            .merge(style)
            .copyWith(
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused) && !states.contains(WidgetState.disabled)
                      ? foreground
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
            );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 4)],
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: child ?? label ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );
    return SodalitePress(
      disabled: onPressed == null && !inProgress,
      enabled: onPressed != null && !inProgress,
      builder: (states) => TextButton(
        statesController: states,
        onPressed: inProgress ? null : onPressed,
        style: base,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: !inProgress,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: content,
            ),
            if (inProgress)
              Semantics(
                label: 'Сохранение',
                liveRegion: true,
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon Button Alternative 89:15564: S has 44px hit target, 38px
/// surface and 20px icon. Production description supersedes old geometry.
class SodaliteIconButton extends StatelessWidget {
  const SodaliteIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.style,
    this.isSelected,
  });
  final VoidCallback? onPressed;
  final Widget icon;
  final String tooltip;
  final ButtonStyle? style;
  final bool? isSelected;

  @override
  Widget build(BuildContext context) => SodaliteTooltip(
    message: tooltip,
    excludeFromSemantics: true,
    child: MergeSemantics(
      child: Semantics(
        label: tooltip,
        button: true,
        child: SodalitePress(
          enabled: onPressed != null,
          disabled: onPressed == null,
          scale: 1.16,
          whiteOverlay: false,
          builder: (states) => IconButton(
            onPressed: onPressed,
            isSelected: isSelected,
            tooltip: null,
            statesController: states,
            style:
                IconButton.styleFrom(
                      minimumSize: const Size.square(44),
                      maximumSize: const Size.square(44),
                      padding: const EdgeInsets.all(3),
                      iconSize: 20,
                      foregroundColor: SodaliteColors.secondary,
                      disabledForegroundColor: SodaliteColors.secondary,
                      backgroundColor: Colors.transparent,
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const CircleBorder(),
                    )
                    .merge(style)
                    .copyWith(
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.focused)
                            ? SodaliteColors.accent.withValues(alpha: .12)
                            : Colors.transparent,
                      ),
                    ),
            icon: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected == true ? SodaliteColors.accentSubdued : SodaliteColors.canvas,
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Uses the same pressed state as Material's pointer, cancellation and
/// keyboard handling; layout and hit targets do not grow with the surface.
class SodalitePress extends StatefulWidget {
  const SodalitePress({
    super.key,
    required this.builder,
    this.enabled = true,
    this.disabled = false,
    this.scale = 1.04,
    this.whiteOverlay = true,
  }) : child = null;

  /// Hover-only interaction for cards; fields and menu rows stay static.
  const SodalitePress.hover({super.key, required this.child, this.enabled = true})
    : builder = null,
      disabled = false,
      scale = 1,
      whiteOverlay = false;

  final Widget Function(WidgetStatesController states)? builder;
  final Widget? child;
  final bool enabled, disabled, whiteOverlay;
  final double scale;

  @override
  State<SodalitePress> createState() => _SodalitePressState();
}

class _SodalitePressState extends State<SodalitePress> with TickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final _motion = AnimationController.unbounded(vsync: this);
  late final _hover = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
  bool _hovered = false;
  bool _pressed = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_stateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _motion.value = _pressed ? 1 : 0;
  }

  @override
  void didUpdateWidget(SodalitePress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _hovered = false;
      _hover.value = 0;
      _pressed = false;
      _motion.value = 0;
    }
  }

  void _setHover(bool value) {
    final next = widget.enabled && value;
    if (next == _hovered) return;
    setState(() => _hovered = next);
    if (_reduceMotion) {
      _hover.value = 0;
    } else {
      _hover.animateTo(next ? 1 : 0, curve: Curves.easeOut);
    }
  }

  void _stateChanged() {
    final pressed = widget.enabled && _states.value.contains(WidgetState.pressed);
    if (pressed == _pressed) return;
    _pressed = pressed;
    if (_reduceMotion) {
      _motion.value = pressed ? 1 : 0;
      return;
    }
    if (pressed) {
      _motion.animateTo(1, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    } else {
      _motion.animateWith(
        SpringSimulation(
          SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 290), bounce: .55),
          _motion.value,
          0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _states.removeListener(_stateChanged);
    _states.dispose();
    _motion.dispose();
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentHovered = context.dependOnInheritedWidgetOfExactType<_SodaliteHoverScope>()?.active ?? false;
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: _SodaliteHoverScope(
        active: parentHovered || _hovered,
        child: Opacity(
          opacity: widget.disabled ? .6 : 1,
          child: AnimatedBuilder(
            animation: Listenable.merge([_motion, _hover]),
            child: widget.builder?.call(_states) ?? widget.child!,
            builder: (context, child) => Transform.scale(
              // Nested controls inherit the parent's 2%, never compound it to 4%.
              // Pressed state retains the existing Figma motion independently.
              scale: _reduceMotion
                  ? 1
                  : 1 +
                        (parentHovered ? 0 : .02 * _hover.value) * (1 - _motion.value.clamp(0, 1)) +
                        (widget.scale - 1) * _motion.value,
              transformHitTests: false,
              child: widget.whiteOverlay
                  ? Stack(
                      children: [
                        child!,
                        if (widget.whiteOverlay)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .12 * _motion.value.clamp(0, 1)),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SodaliteHoverScope extends InheritedWidget {
  const _SodaliteHoverScope({required this.active, required super.child});
  final bool active;
  @override
  bool updateShouldNotify(_SodaliteHoverScope oldWidget) => active != oldWidget.active;
}

class SodaliteMenuButton<T> extends StatefulWidget {
  const SodaliteMenuButton({
    super.key,
    required this.tooltip,
    required this.itemBuilder,
    required this.onSelected,
    this.icon = const Icon(Icons.more_horiz, size: 20),
    this.trigger,
  });
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final Widget icon;
  final Widget Function(VoidCallback open)? trigger;
  @override
  State<SodaliteMenuButton<T>> createState() => _SodaliteMenuButtonState<T>();
}

class _SodaliteMenuButtonState<T> extends State<SodaliteMenuButton<T>> {
  final _menu = GlobalKey<PopupMenuButtonState<T>>();
  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    key: _menu,
    tooltip: '',
    constraints: const BoxConstraints.tightFor(width: 256),
    position: PopupMenuPosition.under,
    offset: const Offset(0, 8),
    clipBehavior: Clip.antiAlias,
    itemBuilder: widget.itemBuilder,
    onSelected: widget.onSelected,
    child:
        widget.trigger?.call(() => _menu.currentState?.showButtonMenu()) ??
        SodaliteIconButton(
          tooltip: widget.tooltip,
          icon: widget.icon,
          onPressed: () => _menu.currentState?.showButtonMenu(),
        ),
  );
}

/// Figma Context Menu / Action 1189:7855. Native popup routing and
/// keyboard traversal are retained; Material's default row styling is replaced.
class SodaliteMenuItem<T> extends PopupMenuItem<T> {
  const SodaliteMenuItem({
    super.key,
    required T value,
    required this.label,
    this.icon,
    this.destructive = false,
    bool enabled = true,
  }) : super(value: value, enabled: enabled, height: 48, child: null);

  final String label;
  final IconData? icon;
  final bool destructive;

  @override
  PopupMenuItemState<T, SodaliteMenuItem<T>> createState() => _SodaliteMenuItemState<T>();
}

class _SodaliteMenuItemState<T> extends PopupMenuItemState<T, SodaliteMenuItem<T>> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = !widget.enabled
        ? SodaliteColors.disabledText
        : widget.destructive
        ? SodaliteColors.negative
        : SodaliteColors.text;
    final icon = widget.icon;
    return MergeSemantics(
      child: buildSemantics(
        child: InkWell(
          onTap: widget.enabled ? handleTap : null,
          canRequestFocus: widget.enabled,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(24),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? SodaliteColors.canvas : Colors.transparent,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(horizontal: widget.destructive ? 16 : 12, vertical: 12),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _focused ? SodaliteColors.accent : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                if (icon != null && !widget.destructive) ...[
                  Icon(icon, size: 24, color: color),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(widget.label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
                ),
                if (icon != null && widget.destructive) ...[
                  const SizedBox(width: 12),
                  Icon(icon, size: 24, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SodaliteMenuDivider<T> extends PopupMenuEntry<T> {
  const SodaliteMenuDivider({super.key});
  @override
  double get height => 8;
  @override
  bool represents(T? value) => false;
  @override
  State<SodaliteMenuDivider<T>> createState() => _SodaliteMenuDividerState<T>();
}

class _SodaliteMenuDividerState<T> extends State<SodaliteMenuDivider<T>> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 8, child: ColoredBox(color: SodaliteColors.canvas));
}
