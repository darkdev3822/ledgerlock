// LedgerLock design system: tokens + Material 3 theme (SPEC §5, docs/DESIGN.md).
// Warm paper neutrals, one emerald accent + "sun" for attention, Fraunces voice + Manrope UI/numbers.
import 'package:flutter/material.dart';

/// Spacing scale (4 pt grid).
abstract final class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const gutter = 20.0;
}

/// Fonts (bundled, SIL OFL). Fraunces = voice (titles, greetings); Manrope = UI and every number.
abstract final class Fonts {
  static const voice = 'Fraunces', ui = 'Manrope';
}

/// Motion tokens (docs/DESIGN.md). Calm: no wobble except success moments.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 700);
  static const stagger = Duration(milliseconds: 40);
  static const enter = Curves.easeOutCubic;
  static const success = Curves.easeOutBack;

  /// Slow looping ambience (hero glow). Tests switch it off so pumpAndSettle can finish.
  static bool ambient = true;

  /// System "remove animations" setting.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

abstract final class Radii {
  static const card = 20.0, input = 14.0, pill = 999.0, button = 16.0;
}

/// Brand colours not covered by ColorScheme.
@immutable
class LLColors extends ThemeExtension<LLColors> {
  final Color background, surface, surfaceAlt, border, text, muted;
  final Color accent, onAccent, accentSoft, income, expense, warning, heroStart, heroEnd, heroGlow;

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
    required this.heroGlow,
  });

  // Warm paper neutrals. muted on background >= 4.5:1 (WCAG AA).
  static const light = LLColors(
    background: Color(0xFFF6F4EE),
    surface: Color(0xFFFFFEFB),
    surfaceAlt: Color(0xFFEFECE4),
    border: Color(0xFFE5E1D6),
    text: Color(0xFF16190F),
    muted: Color(0xFF66665C),
    accent: Color(0xFF0B7A62),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDCEFE7),
    income: Color(0xFF0B7A62),
    expense: Color(0xFFB4432F),
    warning: Color(0xFFA5670F),
    heroStart: Color(0xFF0E7A61),
    heroEnd: Color(0xFF0A4F41),
    heroGlow: Color(0xFFE9C46A),
  );

  static const dark = LLColors(
    background: Color(0xFF0E0F0C),
    surface: Color(0xFF171914),
    surfaceAlt: Color(0xFF20231C),
    border: Color(0xFF2B2F27),
    text: Color(0xFFEEECE3),
    muted: Color(0xFFA3A396),
    accent: Color(0xFF47D1AC),
    onAccent: Color(0xFF04221A),
    accentSoft: Color(0xFF14362D),
    income: Color(0xFF47D1AC),
    expense: Color(0xFFF08A73),
    warning: Color(0xFFE9B65C),
    heroStart: Color(0xFF125B48),
    heroEnd: Color(0xFF0A2E25),
    heroGlow: Color(0xFFD9A441),
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
      heroGlow: l(heroGlow, other.heroGlow),
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
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: Fonts.ui);
  final t = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);
  TextStyle? voice(TextStyle? x, double size) => x?.copyWith(
    fontFamily: Fonts.voice,
    fontWeight: FontWeight.w600,
    fontSize: size,
    letterSpacing: -0.4,
    height: 1.15,
  );
  final text = t.copyWith(
    // Hero money: Manrope, tabular, tight.
    displaySmall: t.displaySmall?.copyWith(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      height: 1.05,
      fontFeatures: tabular,
    ),
    displayMedium: voice(t.displayMedium, 34),
    headlineMedium: voice(t.headlineMedium, 30),
    headlineSmall: voice(t.headlineSmall, 26),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: t.bodyMedium?.copyWith(color: c.text, height: 1.45),
    bodySmall: t.bodySmall?.copyWith(color: c.muted, height: 1.4),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    labelMedium: t.labelMedium?.copyWith(color: c.muted, letterSpacing: 0.3, fontWeight: FontWeight.w600),
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
      backgroundColor: b == Brightness.light ? const Color(0xFF23261F) : const Color(0xFFE9E6DC),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: b == Brightness.light ? const Color(0xFFF4F2EA) : const Color(0xFF16190F),
      ),
      actionTextColor: c.accent == LLColors.light.accent ? const Color(0xFF7FE0C2) : const Color(0xFF0B7A62),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.input)),
    ),
    switchTheme: SwitchThemeData(trackOutlineColor: WidgetStateProperty.all(Colors.transparent)),
  );
}
