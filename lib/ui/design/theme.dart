// LedgerLock design system: tokens + Material 3 theme (SPEC §5).
// One accent, calm neutrals, 20 px cards, tabular numerals for money.
import 'package:flutter/material.dart';

/// Spacing scale (4 pt grid).
abstract final class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const gutter = 20.0;
}

abstract final class Radii {
  static const card = 20.0, input = 14.0, pill = 999.0, button = 16.0;
}

/// Brand colours not covered by ColorScheme.
@immutable
class LLColors extends ThemeExtension<LLColors> {
  final Color background, surface, surfaceAlt, border, text, muted;
  final Color accent, onAccent, accentSoft, income, expense, warning, heroStart, heroEnd;

  const LLColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.income,
    required this.expense,
    required this.warning,
    required this.heroStart,
    required this.heroEnd,
  });

  static const light = LLColors(
    background: Color(0xFFF5F7F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDF1EF),
    border: Color(0xFFE1E7E4),
    text: Color(0xFF0F1714),
    muted: Color(0xFF5E6B65),
    accent: Color(0xFF0C7A63),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDDF0EA),
    income: Color(0xFF0C7A63),
    expense: Color(0xFFB4432F),
    warning: Color(0xFFA86A12),
    heroStart: Color(0xFF0C7A63),
    heroEnd: Color(0xFF0A5C4C),
  );

  static const dark = LLColors(
    background: Color(0xFF0A0F0D),
    surface: Color(0xFF131A17),
    surfaceAlt: Color(0xFF1B2420),
    border: Color(0xFF26312C),
    text: Color(0xFFE9EFEC),
    muted: Color(0xFF93A29B),
    accent: Color(0xFF3FCBA6),
    onAccent: Color(0xFF042119),
    accentSoft: Color(0xFF12352C),
    income: Color(0xFF3FCBA6),
    expense: Color(0xFFF08A73),
    warning: Color(0xFFE5B158),
    heroStart: Color(0xFF115846),
    heroEnd: Color(0xFF0B3B30),
  );

  @override
  LLColors copyWith() => this;

  @override
  LLColors lerp(LLColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LLColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      income: l(income, other.income),
      expense: l(expense, other.expense),
      warning: l(warning, other.warning),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
    );
  }
}

extension LLContext on BuildContext {
  LLColors get ll {
    final t = Theme.of(this);
    return t.extension<LLColors>() ?? (t.brightness == Brightness.dark ? LLColors.dark : LLColors.light);
  }
  TextTheme get text => Theme.of(this).textTheme;
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? LLColors.light : LLColors.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: b,
        primary: c.accent,
        onPrimary: c.onAccent,
        surface: c.surface,
        onSurface: c.text,
        error: c.expense,
      ).copyWith(
        surfaceContainerLowest: c.background,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surfaceAlt,
        surfaceContainerHighest: c.surfaceAlt,
        outline: c.border,
        outlineVariant: c.border,
        onSurfaceVariant: c.muted,
        secondaryContainer: c.accentSoft,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final t = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);
  final text = t.copyWith(
    displaySmall: t.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      fontFeatures: tabular,
    ),
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyMedium: t.bodyMedium?.copyWith(color: c.text, height: 1.4),
    bodySmall: t.bodySmall?.copyWith(color: c.muted, height: 1.35),
    labelMedium: t.labelMedium?.copyWith(color: c.muted, letterSpacing: 0.2),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.input),
    borderSide: BorderSide(color: c.border),
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: c.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        textStyle: text.titleMedium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        textStyle: text.titleMedium,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: text.labelLarge),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.muted,
      minVerticalPadding: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.input)),
    ),
    switchTheme: SwitchThemeData(trackOutlineColor: WidgetStateProperty.all(Colors.transparent)),
  );
}
