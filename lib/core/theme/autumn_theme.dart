import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===========================
// 🍂 AUTUMN COLOR PALETTE v2.0 Modern
// Exact match from autumn_theme.py
// LIGHT cream otoñal theme
// ===========================
class AutumnColors {
  // Backgrounds — Crema otoñal cálida (LIGHT theme)
  static const Color bgPrimary   = Color(0xFFF5EFE6);
  static const Color bgSecondary = Color(0xFFEDE4D8);
  static const Color bgCard      = Color(0xFFFDFAF5);
  static const Color bgInput     = Color(0xFFF0E8DC);
  static const Color bgSurface   = Color(0xFFE8DDD0);

  // Accent colors
  static const Color accentOrange = Color(0xFFD4581A);
  static const Color accentGold   = Color(0xFFC8860A);
  static const Color accentRed    = Color(0xFFB03A2E);
  static const Color mossGreen    = Color(0xFF4A7A45);
  static const Color leafBrown    = Color(0xFF8B5E3C);
  static const Color barkDark     = Color(0xFFC4A882);

  // Text — dark on light background
  static const Color textPrimary   = Color(0xFF2C1A0E);
  static const Color textSecondary = Color(0xFF5C3D2A);
  static const Color textDisabled  = Color(0xFFA88B75);

  // Specials
  static const Color freeze  = Color(0xFF5B8DB8);
  static const Color streak  = Color(0xFFC8860A);
  static const Color xpColor = Color(0xFFD4581A);
  static const Color divider = Color(0xFFDDD0C0);
  static const Color shadow  = Color(0xFFD4C4B0);

  // Urgency
  static const Color urgentHigh   = Color(0xFFB03A2E);
  static const Color urgentMedium = Color(0xFFD4581A);
  static const Color urgentLow    = Color(0xFFC8860A);
}

// ══════════════════════════════════════════════════════════════════
// 🌙 AUTUMN DARK COLORS — Bosque nocturno
// ══════════════════════════════════════════════════════════════════

class AutumnDarkColors {
  static const Color bgPrimary   = Color(0xFF1A1410);
  static const Color bgSecondary = Color(0xFF221C16);
  static const Color bgCard      = Color(0xFF2A221A);
  static const Color bgInput     = Color(0xFF322820);
  static const Color bgSurface   = Color(0xFF3A2E24);

  static const Color accentOrange = Color(0xFFD4581A);
  static const Color accentGold   = Color(0xFFC8860A);
  static const Color accentRed    = Color(0xFFB03A2E);
  static const Color mossGreen    = Color(0xFF4A7A45);
  static const Color leafBrown    = Color(0xFF8B5E3C);
  static const Color barkDark     = Color(0xFFC4A882);

  static const Color textPrimary   = Color(0xFFF0E6D8);
  static const Color textSecondary = Color(0xFFB89880);
  static const Color textDisabled  = Color(0xFF7A6050);

  static const Color freeze  = Color(0xFF5B8DB8);
  static const Color streak  = Color(0xFFC8860A);
  static const Color xpColor = Color(0xFFD4581A);
  static const Color divider = Color(0xFF3D3028);
  static const Color shadow  = Color(0xFF0D0A08);

  static const Color urgentHigh   = Color(0xFFB03A2E);
  static const Color urgentMedium = Color(0xFFD4581A);
  static const Color urgentLow    = Color(0xFFC8860A);
}

// ══════════════════════════════════════════════════════════════════
// 🎨 THEME PROVIDER — persiste preferencia en SharedPreferences
// ══════════════════════════════════════════════════════════════════

const _kThemeModeKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey) ?? 'system';
    state = _parse(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _encode(mode));
  }

  ThemeMode _parse(String v) {
    if (v == 'light') return ThemeMode.light;
    if (v == 'dark')  return ThemeMode.dark;
    return ThemeMode.system;
  }

  String _encode(ThemeMode m) {
    if (m == ThemeMode.light) return 'light';
    if (m == ThemeMode.dark)  return 'dark';
    return 'system';
  }
}

final themeModeProvider =
StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
        (_) => ThemeModeNotifier());

class MobileSizes {
  static const double inputHeight       = 52.0;
  static const double buttonHeight      = 52.0;
  static const double buttonHeightSmall = 44.0;
  static const double spacingLarge      = 28.0;
  static const double spacingMedium     = 20.0;
  static const double spacingSmall      = 12.0;
  static const double fontLarge         = 22.0;
  static const double fontMedium        = 17.0;
  static const double fontNormal        = 15.0;
  static const double screenPadding     = 24.0;
  static const double borderRadius      = 16.0;
}

ThemeData autumnTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AutumnColors.bgPrimary,
    colorScheme: const ColorScheme.light(
      primary:   AutumnColors.accentOrange,
      secondary: AutumnColors.accentGold,
      surface:   AutumnColors.bgCard,
      error:     AutumnColors.accentRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AutumnColors.bgCard,
      foregroundColor: AutumnColors.textPrimary,
      elevation: 1,
    ),
    textTheme: GoogleFonts.pressStart2pTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AutumnColors.textPrimary),
        bodyMedium:   TextStyle(color: AutumnColors.textPrimary, fontSize: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AutumnColors.bgInput,
      hintStyle: TextStyle(
        color: AutumnColors.textDisabled,
        fontFamily: GoogleFonts.pressStart2p().fontFamily,
        fontSize: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        borderSide: BorderSide(color: AutumnColors.accentOrange.withValues(alpha: 0.4), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        borderSide: const BorderSide(color: AutumnColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        borderSide: const BorderSide(color: AutumnColors.accentOrange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AutumnColors.accentOrange,
        foregroundColor: AutumnColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MobileSizes.borderRadius)),
        elevation: 2,
      ),
    ),
    dividerColor: AutumnColors.divider,
    cardColor: AutumnColors.bgCard,
  );
}

// ══════════════════════════════════════════════════════════════════
// ThemeData — Dark
// ══════════════════════════════════════════════════════════════════

ThemeData autumnThemeDark() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AutumnDarkColors.bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary:   AutumnDarkColors.accentOrange,
      secondary: AutumnDarkColors.accentGold,
      surface:   AutumnDarkColors.bgCard,
      error:     AutumnDarkColors.accentRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AutumnDarkColors.bgCard,
      foregroundColor: AutumnDarkColors.textPrimary,
      elevation: 1,
    ),
    textTheme: GoogleFonts.pressStart2pTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AutumnDarkColors.textPrimary),
        bodyMedium:   TextStyle(color: AutumnDarkColors.textPrimary, fontSize: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AutumnDarkColors.bgInput,
      hintStyle: TextStyle(
        color: AutumnDarkColors.textDisabled,
        fontFamily: GoogleFonts.pressStart2p().fontFamily,
        fontSize: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        borderSide: BorderSide(color: AutumnDarkColors.accentOrange.withValues(alpha: 0.4), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        borderSide: const BorderSide(color: AutumnDarkColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MobileSizes.borderRadius),
        borderSide: const BorderSide(color: AutumnDarkColors.accentOrange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AutumnDarkColors.accentOrange,
        foregroundColor: AutumnDarkColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MobileSizes.borderRadius)),
        elevation: 2,
      ),
    ),
    dividerColor: AutumnDarkColors.divider,
    cardColor:    AutumnDarkColors.bgCard,
  );
}
// ══════════════════════════════════════════════════════════════════
// 🎨 BuildContext extension — paleta dinámica light/dark
// Uso: context.ac.bgCard, context.ac.textPrimary, etc.
// ══════════════════════════════════════════════════════════════════

extension AutumnContext on BuildContext {
  _AutumnPalette get ac {
    final dark = Theme.of(this).brightness == Brightness.dark;
    return _AutumnPalette(dark);
  }
}

class _AutumnPalette {
  final bool _dark;
  const _AutumnPalette(this._dark);

  Color get bgPrimary   => _dark ? AutumnDarkColors.bgPrimary   : AutumnColors.bgPrimary;
  Color get bgSecondary => _dark ? AutumnDarkColors.bgSecondary : AutumnColors.bgSecondary;
  Color get bgCard      => _dark ? AutumnDarkColors.bgCard      : AutumnColors.bgCard;
  Color get bgInput     => _dark ? AutumnDarkColors.bgInput     : AutumnColors.bgInput;
  Color get bgSurface   => _dark ? AutumnDarkColors.bgSurface   : AutumnColors.bgSurface;

  Color get accentOrange => AutumnColors.accentOrange;
  Color get accentGold   => AutumnColors.accentGold;
  Color get accentRed    => AutumnColors.accentRed;
  Color get mossGreen    => AutumnColors.mossGreen;
  Color get leafBrown    => AutumnColors.leafBrown;
  Color get barkDark     => AutumnColors.barkDark;

  Color get textPrimary   => _dark ? AutumnDarkColors.textPrimary   : AutumnColors.textPrimary;
  Color get textSecondary => _dark ? AutumnDarkColors.textSecondary : AutumnColors.textSecondary;
  Color get textDisabled  => _dark ? AutumnDarkColors.textDisabled  : AutumnColors.textDisabled;

  Color get freeze  => AutumnColors.freeze;
  Color get streak  => AutumnColors.streak;
  Color get xpColor => AutumnColors.xpColor;
  Color get divider => _dark ? AutumnDarkColors.divider : AutumnColors.divider;
  Color get shadow  => _dark ? AutumnDarkColors.shadow  : AutumnColors.shadow;

  Color get urgentHigh   => AutumnColors.urgentHigh;
  Color get urgentMedium => AutumnColors.urgentMedium;
  Color get urgentLow    => AutumnColors.urgentLow;
}