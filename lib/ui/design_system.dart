import 'package:flutter/material.dart';

/// Sodalite 2.0 / Theme variables. Figma: JsnlUudhlN3ZuGGWYcHKU8.
abstract final class SodaliteColors {
  static const accent = Color(0xFF0075FF);
  // Local accessible extensions of the Figma palette, approved during review.
  static const accentStrong = Color(0xFF0065DC);
  static const errorText = Color(0xFFB42318);
  static const accentMuted = Color(0xFFD9EAFF);
  static const accentSubdued = Color(0xFFF2F7FF);
  static const canvas = Color(0xFFF6F6F6);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFFEAEAEA);
  static const border = Color(0xFFD7D7D7);
  static const text = Color(0xFF191A1B);
  static const secondary = Color(0xFF5E5E5E);
  static const icon = Color(0xFF888888);
  static const error = Color(0xFFF04438);
  // Context Menu variables: text/negative and text/neutral-subdued.
  static const negative = Color(0xFFD8400C);
  static const disabledText = Color(0xFFBEBEBE);
  static const success = Color(0xFF40C267);
}

TextStyle _type(double size, double line, {bool strong = false}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  height: line / size,
  fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
  letterSpacing: -size * .01,
  color: SodaliteColors.text,
);

/// Card 1387:30267 has an 18/26 heading with zero tracking.
TextStyle? sodaliteCardTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge?.copyWith(height: 26 / 18, letterSpacing: 0);

ThemeData sodaliteTheme() {
  final text = TextTheme(
    displaySmall: _type(28, 34, strong: true),
    headlineLarge: _type(28, 34, strong: true),
    headlineMedium: _type(24, 30, strong: true),
    headlineSmall: _type(20, 26, strong: true),
    titleLarge: _type(18, 24, strong: true),
    titleMedium: _type(16, 24, strong: true),
    titleSmall: _type(14, 20, strong: true),
    bodyLarge: _type(16, 24),
    bodyMedium: _type(14, 20),
    bodySmall: _type(12, 16),
    labelLarge: _type(16, 24, strong: true),
    labelMedium: _type(14, 20, strong: true),
    labelSmall: _type(12, 16),
  );
  const scheme = ColorScheme.light(
    primary: SodaliteColors.accentStrong,
    onPrimary: SodaliteColors.surface,
    primaryContainer: SodaliteColors.accentMuted,
    onPrimaryContainer: SodaliteColors.text,
    secondary: SodaliteColors.accent,
    onSecondary: SodaliteColors.surface,
    secondaryContainer: SodaliteColors.accentSubdued,
    onSecondaryContainer: SodaliteColors.text,
    surface: SodaliteColors.surface,
    onSurface: SodaliteColors.text,
    onSurfaceVariant: SodaliteColors.secondary,
    surfaceContainerLowest: SodaliteColors.surface,
    surfaceContainerLow: SodaliteColors.canvas,
    surfaceContainer: SodaliteColors.canvas,
    surfaceContainerHigh: SodaliteColors.muted,
    surfaceContainerHighest: SodaliteColors.muted,
    outline: SodaliteColors.border,
    outlineVariant: SodaliteColors.muted,
    error: SodaliteColors.errorText,
    onError: SodaliteColors.surface,
    errorContainer: SodaliteColors.canvas,
    onErrorContainer: SodaliteColors.errorText,
    surfaceTint: Colors.transparent,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    textTheme: text,
    colorScheme: scheme,
    scaffoldBackgroundColor: SodaliteColors.canvas,
    hoverColor: Colors.transparent,
    disabledColor: SodaliteColors.icon,
    appBarTheme: AppBarTheme(
      backgroundColor: SodaliteColors.surface,
      foregroundColor: SodaliteColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 80,
      titleTextStyle: text.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: SodaliteColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SodaliteColors.accent,
        minimumSize: const Size(100, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: text.titleMedium,
        disabledBackgroundColor: SodaliteColors.muted,
        disabledForegroundColor: SodaliteColors.secondary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(100, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        backgroundColor: SodaliteColors.surface,
        foregroundColor: SodaliteColors.text,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        textStyle: text.titleMedium,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SodaliteColors.accent,
        minimumSize: const Size(100, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        textStyle: text.titleMedium,
        shape: const StadiumBorder(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: SodaliteColors.secondary,
        minimumSize: const Size(44, 44),
        iconSize: 20,
        shape: const CircleBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hoverColor: Colors.transparent,
      filled: true,
      fillColor: SodaliteColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: SodaliteColors.accent, width: 1.5)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: SodaliteColors.error)),
      focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: SodaliteColors.error, width: 1.5)),
      labelStyle: text.bodyMedium?.copyWith(color: SodaliteColors.secondary),
      hintStyle: text.bodyMedium?.copyWith(color: SodaliteColors.secondary),
      errorStyle: text.bodySmall?.copyWith(color: SodaliteColors.errorText),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    switchTheme: SwitchThemeData(
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) &&
                !states.contains(WidgetState.focused) &&
                !states.contains(WidgetState.pressed)
            ? Colors.transparent
            : null,
      ),
      thumbColor: const WidgetStatePropertyAll(SodaliteColors.surface),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? SodaliteColors.accent : SodaliteColors.border,
      ),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    dividerTheme: const DividerThemeData(color: SodaliteColors.muted, thickness: 1, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: SodaliteColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SodaliteColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: SodaliteColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: text.bodyLarge,
      labelTextStyle: WidgetStatePropertyAll(text.bodyLarge),
      menuPadding: const EdgeInsets.all(8),
      elevation: 8,
      shadowColor: SodaliteColors.text.withValues(alpha: .05),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SodaliteColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: text.bodyMedium?.copyWith(color: SodaliteColors.surface),
      actionTextColor: SodaliteColors.accentMuted,
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 80), exitDuration: Duration.zero),
  );
}

class SodaliteBrand extends StatelessWidget {
  const SodaliteBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset('assets/images/sodalite.png', width: 40, height: 40, excludeFromSemantics: true),
      if (!compact) ...[
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sodalite', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Конфигуратор',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
            ),
          ],
        ),
      ],
    ],
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.icon, this.color = SodaliteColors.text});
  final String label;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: SodaliteColors.canvas, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
      ],
    ),
  );
}
