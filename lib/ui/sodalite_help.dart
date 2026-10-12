import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/help_copy.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';

/// One open help card for the editor. The open id is not part of the module document.
class HelpScope extends StatefulWidget {
  const HelpScope({super.key, required this.child});

  final Widget child;

  @override
  State<HelpScope> createState() => _HelpScopeState();
}

class _HelpScopeState extends State<HelpScope> {
  final _active = ValueNotifier<Object?>(null);

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _HelpSession(active: _active, child: widget.child);
}

class _HelpSession extends InheritedWidget {
  const _HelpSession({required this.active, required super.child});

  final ValueNotifier<Object?> active;

  static _HelpSession? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_HelpSession>();

  @override
  bool updateShouldNotify(_HelpSession oldWidget) => active != oldWidget.active;
}

/// Question mark that opens a three-line help card on hover and keyboard focus.
class SodaliteHelpButton extends StatefulWidget {
  const SodaliteHelpButton({super.key, required this.name, required this.text});

  final String name;
  final HelpText text;

  @override
  State<SodaliteHelpButton> createState() => _SodaliteHelpButtonState();
}

class _SodaliteHelpButtonState extends State<SodaliteHelpButton> with SingleTickerProviderStateMixin {
  final _token = Object();
  final _buttonKey = GlobalKey();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _focus = FocusNode();
  late final AnimationController _motion;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;
  Timer? _showTimer;
  Timer? _hideTimer;
  ScrollPosition? _scroll;
  _HelpSession? _session;
  var _overButton = false;
  var _overCard = false;
  var _focused = false;
  var _escapeLatch = false;
  var _reduceMotion = false;
  var _hideGeneration = 0;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 50),
    );
    _curve = CurvedAnimation(parent: _motion, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.98, end: 1).animate(_curve);
    _focus.addListener(_onFocus);
    _focus.onKeyEvent = _onKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    final session = _HelpSession.maybeOf(context);
    if (!identical(session, _session)) {
      _session?.active.removeListener(_onSession);
      _session = session;
      _session?.active.addListener(_onSession);
    }
    final scroll = Scrollable.maybeOf(context)?.position;
    if (!identical(scroll, _scroll)) {
      _scroll?.removeListener(_onScroll);
      _scroll = scroll;
      _scroll?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _session?.active.removeListener(_onSession);
    _scroll?.removeListener(_onScroll);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  bool get _wantsOpen => !_escapeLatch && (_focused || _overButton || _overCard);

  void _onScroll() {
    if (_portal.isShowing && mounted) setState(() {});
  }

  void _onSession() {
    if (_session?.active.value == _token || !_portal.isShowing) return;
    _hideGeneration++;
    _motion.value = 0;
    _portal.hide();
  }

  void _onFocus() {
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    _focused = focused;
    if (focused) {
      _escapeLatch = false;
      _present(immediate: true);
    } else {
      _scheduleHide();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape || !_portal.isShowing) {
      return KeyEventResult.ignored;
    }
    _escapeLatch = true;
    _dismiss();
    return KeyEventResult.handled;
  }

  void _enterButton() {
    _overButton = true;
    _present(immediate: _focused || _portal.isShowing);
  }

  void _exitButton() {
    _overButton = false;
    _escapeLatch = false;
    _scheduleHide();
  }

  void _setOverCard(bool value) {
    _overCard = value;
    if (value) {
      _hideTimer?.cancel();
      return;
    }
    _scheduleHide();
  }

  void _present({required bool immediate}) {
    if (!_wantsOpen || !mounted) return;
    _hideTimer?.cancel();
    _hideGeneration++;
    if (!immediate && !_portal.isShowing) {
      _showTimer ??= Timer(const Duration(milliseconds: 80), () {
        _showTimer = null;
        if (_wantsOpen) _open();
      });
      return;
    }
    _showTimer?.cancel();
    _showTimer = null;
    _open();
  }

  void _open() {
    if (!mounted || !_wantsOpen) return;
    _session?.active.value = _token;
    if (!_portal.isShowing) _portal.show();
    if (_reduceMotion) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    _showTimer = null;
    if (_wantsOpen) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_wantsOpen) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    _showTimer?.cancel();
    _showTimer = null;
    final generation = ++_hideGeneration;
    if (!_portal.isShowing) return;
    if (_reduceMotion) {
      _motion.value = 0;
    } else {
      await _motion.reverse();
    }
    if (!mounted || generation != _hideGeneration) return;
    if (_wantsOpen) {
      _open();
      return;
    }
    _portal.hide();
    if (_session?.active.value == _token) _session?.active.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final description = 'Что это: ${widget.text.what}. Где видно: ${widget.text.where}. Пример: ${widget.text.example}';
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      overlayLocation: OverlayChildLocation.nearestOverlay,
      child: Semantics(
        button: true,
        label: 'Пояснение. ${widget.name}',
        hint: description,
        child: ExcludeSemantics(
          child: MouseRegion(
            onEnter: (_) => _enterButton(),
            onExit: (_) => _exitButton(),
            child: CompositedTransformTarget(
              link: _link,
              child: SodalitePress(
                enabled: true,
                whiteOverlay: false,
                builder: (states) => IconButton(
                  key: _buttonKey,
                  focusNode: _focus,
                  onPressed: () {},
                  tooltip: null,
                  statesController: states,
                  style:
                      IconButton.styleFrom(
                        minimumSize: const Size.square(32),
                        maximumSize: const Size.square(32),
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        foregroundColor: SodaliteColors.secondary,
                        backgroundColor: Colors.transparent,
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: const CircleBorder(),
                      ).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                        side: WidgetStateProperty.resolveWith(
                          (states) => BorderSide(
                            color: states.contains(WidgetState.focused) ? SodaliteColors.text : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                      ),
                  icon: const Icon(Icons.help_outline),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    return _AnchoredHelpCard(
      link: _link,
      buttonKey: _buttonKey,
      child: MouseRegion(
        onEnter: (_) => _setOverCard(true),
        onExit: (_) => _setOverCard(false),
        child: FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.bottomCenter,
            child: ExcludeSemantics(
              child: SelectionArea(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SodaliteColors.text,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 42,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HelpLine(label: 'Что это', body: widget.text.what),
                          const SizedBox(height: 8),
                          _HelpLine(label: 'Где видно', body: widget.text.where),
                          const SizedBox(height: 8),
                          _HelpLine(label: 'Пример', body: widget.text.example),
                        ],
                      ),
                    ),
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

class _AnchoredHelpCard extends StatefulWidget {
  const _AnchoredHelpCard({required this.link, required this.buttonKey, required this.child});

  final LayerLink link;
  final GlobalKey buttonKey;
  final Widget child;

  @override
  State<_AnchoredHelpCard> createState() => _AnchoredHelpCardState();
}

class _AnchoredHelpCardState extends State<_AnchoredHelpCard> {
  final _cardKey = GlobalKey();
  var _above = true;
  var _dx = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
  }

  void _place() {
    final card = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    final button = widget.buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || card == null || button == null || !card.hasSize || !button.hasSize || !button.attached) return;
    final buttonRect = button.localToGlobal(Offset.zero) & button.size;
    final screen = MediaQuery.sizeOf(context);
    const gap = 8.0;
    final above = buttonRect.top - card.size.height - gap >= gap;
    var left = buttonRect.center.dx - card.size.width / 2;
    final room = screen.width - card.size.width - gap;
    final maxLeft = room < gap ? gap : room;
    left = left.clamp(gap, maxLeft);
    final dx = left - (buttonRect.center.dx - card.size.width / 2);
    if (above == _above && (dx - _dx).abs() < 0.5) return;
    setState(() {
      _above = above;
      _dx = dx;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      targetAnchor: _above ? Alignment.topCenter : Alignment.bottomCenter,
      followerAnchor: _above ? Alignment.bottomCenter : Alignment.topCenter,
      offset: Offset(_dx, _above ? -8 : 8),
      child: KeyedSubtree(key: _cardKey, child: widget.child),
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: small?.copyWith(color: const Color(0xFFB8B8B8))),
        const SizedBox(height: 2),
        Text(body, style: small?.copyWith(color: const Color(0xFFF0F0F0))),
      ],
    );
  }
}
