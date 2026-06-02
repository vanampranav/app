import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── ELEFIT Design System ─────────────────────────────────────────────────────
// Brand colors from official brand guide:
//   Lime    #C8DA2B  — primary CTA, active states, progress
//   Purple  #4E3580  — brand, AI/premium sections
//   Charcoal #4D4D4D — secondary surfaces, borders
// Dark-first theme matching brand guide aesthetic

class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────────────────────────────────────
  static const Color lime       = Color(0xFFC8DA2B); // Primary CTA / accent
  static const Color purple     = Color(0xFF4E3580); // Brand / AI / premium
  static const Color purpleLight= Color(0xFF6B50A8); // Hover / tinted purple
  static const Color charcoal   = Color(0xFF4D4D4D); // Card borders / secondary surfaces

  // Keep legacy names so existing code doesn't break
  static const Color primaryColor        = purple;
  static const Color accentColor         = lime;
  static const Color energyColor         = lime;
  static const Color successColor        = lime;
  static const Color saleColor           = lime;
  static const Color goldAccent          = lime;
  static const Color darkTeal            = purple;
  static const Color darkGrey            = charcoal;
  static const Color lightGrey           = Color(0xFF8A8A8A);
  static const Color secondaryTextColor  = Color(0xFF8A8A8A);
  static const Color lightSecondaryTextColor = Color(0xFF8A8A8A);

  // ── Dark surface scale (Nike/Apple Fitness inspired) ─────────────────────────
  static const Color bg         = Color(0xFF0D0D0D); // Page background
  static const Color surface1   = Color(0xFF1A1A1A); // Card / bottom sheet
  static const Color surface2   = Color(0xFF242424); // Elevated card
  static const Color surface3   = Color(0xFF2E2E2E); // Chip / tag
  static const Color divider    = Color(0xFF2A2A2A); // Dividers

  // ── Text scale ───────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9A9A);
  static const Color textTertiary  = Color(0xFF5A5A5A);

  // Legacy aliases
  static const Color backgroundColor       = bg;
  static const Color surfaceColor          = surface1;
  static const Color textColor             = textPrimary;
  static const Color lightBackgroundColor  = bg;
  static const Color lightSurfaceColor     = surface1;
  static const Color lightTextColor        = textPrimary;
  static const Color lightPrimaryColor     = purple;

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFAA00);
  static const Color info    = Color(0xFF3B9EFF);

  // ── Gradients ────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [purple, Color(0xFF3A2860)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient energyGradient = LinearGradient(
    colors: [lime, Color(0xFFD4E84F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accentGradient = LinearGradient(
    colors: [lime, Color(0xFFB8C625)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF0D0D0D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF4E3580), Color(0xFF2D1F4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Spacing tokens ───────────────────────────────────────────────────────────
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  // ── Border radius tokens ─────────────────────────────────────────────────────
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 20;
  static const double radiusXxl = 28;
  static const double radiusPill= 100;

  // ── Elevation shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> shadowLg = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 32, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> shadowLime = [
    BoxShadow(color: lime.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> shadowPurple = [
    BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  // ── Text styles (Aktiv Grotesk Ex approximated with tight tracking + heavy weight) ──
  static const TextStyle displayXL = TextStyle(
    fontSize: 52, fontWeight: FontWeight.w900, color: textPrimary,
    letterSpacing: -1.5, height: 1.0,
  );
  static const TextStyle displayLG = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w900, color: textPrimary,
    letterSpacing: -1.0, height: 1.1,
  );
  static const TextStyle displayMD = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w900, color: textPrimary,
    letterSpacing: -0.5, height: 1.15,
  );
  static const TextStyle headingLG = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary,
    letterSpacing: -0.3, height: 1.2,
  );
  static const TextStyle headingMD = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary,
    letterSpacing: -0.2, height: 1.25,
  );
  static const TextStyle headingSM = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary,
    letterSpacing: 0, height: 1.3,
  );
  static const TextStyle bodyLG = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
    letterSpacing: 0.1, height: 1.6,
  );
  static const TextStyle bodyMD = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary,
    letterSpacing: 0.1, height: 1.5,
  );
  static const TextStyle bodySM = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary,
    letterSpacing: 0.1, height: 1.5,
  );
  static const TextStyle labelLG = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary,
    letterSpacing: 0.8,
  );
  static const TextStyle labelMD = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary,
    letterSpacing: 1.0,
  );
  static const TextStyle labelSM = TextStyle(
    fontSize: 9, fontWeight: FontWeight.w900, color: textSecondary,
    letterSpacing: 1.2,
  );
  static const TextStyle numericXL = TextStyle(
    fontSize: 48, fontWeight: FontWeight.w900, color: textPrimary,
    letterSpacing: -2.0, height: 1.0,
  );
  static const TextStyle numericLG = TextStyle(
    fontSize: 36, fontWeight: FontWeight.w900, color: textPrimary,
    letterSpacing: -1.5, height: 1.0,
  );
  static const TextStyle numericMD = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w900, color: textPrimary,
    letterSpacing: -1.0, height: 1.0,
  );

  // ── Material ThemeData ───────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme();
  static ThemeData get lightTheme => _buildTheme(); // dark-first brand

  static ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: purple,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: lime,
        secondary: purple,
        surface: surface1,
        error: error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: headingMD.copyWith(letterSpacing: 0),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: xl, vertical: md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: labelLG.copyWith(fontSize: 15, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lime,
          side: const BorderSide(color: lime, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: xl, vertical: md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: labelLG.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lime,
          textStyle: labelLG,
        ),
      ),
      textTheme: TextTheme(
        displayLarge:  displayXL,
        displayMedium: displayLG,
        displaySmall:  displayMD,
        headlineLarge: headingLG,
        headlineMedium:headingMD,
        titleLarge:    headingSM,
        bodyLarge:     bodyLG,
        bodyMedium:    bodyMD,
        bodySmall:     bodySM,
        labelLarge:    labelLG,
        labelMedium:   labelMD,
        labelSmall:    labelSM,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lime, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: md, vertical: md),
        labelStyle: bodyMD,
        hintStyle: bodySM.copyWith(color: textTertiary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface3,
        selectedColor: lime.withValues(alpha: 0.2),
        labelStyle: labelMD.copyWith(color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: md, vertical: sm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface1,
        selectedItemColor: lime,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: bodySM.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXxl)),
        titleTextStyle: headingMD,
        contentTextStyle: bodyMD,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface1,
        modalBackgroundColor: surface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXxl)),
        ),
      ),
    );
  }
}
