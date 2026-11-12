import 'package:flutter/material.dart';

/// Geny design system — a premium "Slate" deep theme with a violet-fuchsia
/// genie gradient, in both dark and light variants.
class AppTheme {
  AppTheme._();

  // Slate palette
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  // Brand accents — Geny violet & fuchsia genie palette
  static const indigo = Color(0xFF8B5CF6); // primary violet (kept name for compat)
  static const indigoLight = Color(0xFFA78BFA);
  static const fuchsia = Color(0xFFD946EF); // secondary accent
  static const cyan = Color(0xFF22D3EE); // tertiary glow
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  /// Signature Geny gradient (violet → fuchsia) used by HUDs, buttons and
  /// the splash identity.
  static const LinearGradient genieGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, fuchsia],
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: indigo,
      brightness: Brightness.dark,
      surface: slate900,
    ).copyWith(
      primary: indigoLight,
      onPrimary: slate950,
      secondary: fuchsia,
      tertiary: cyan,
      surface: slate900,
      surfaceContainerHighest: slate800,
      onSurface: slate100,
      onSurfaceVariant: slate400,
      outline: slate700,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: slate950,
      cardColor: slate900,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: indigo,
      brightness: Brightness.light,
      surface: slate50,
    ).copyWith(
      primary: const Color(0xFF7C3AED),
      secondary: const Color(0xFFC026D3),
      tertiary: const Color(0xFF0891B2),
      surface: slate50,
      surfaceContainerHighest: Colors.white,
      onSurface: slate900,
      onSurfaceVariant: slate600,
      outline: slate300,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: slate50,
      cardColor: Colors.white,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.4),
        thickness: 1,
      ),
    );
  }
}
