import 'package:flutter/material.dart';

class AppColors {
  // Background
  static const Color background = Color(0xFFFAF2EB);
  static const Color surface = Color(0xFFFFFFFF);

  // Primary
  static const Color primary = Color(0xFFFF7043);
  static const Color primaryLight = Color(0xFFFFAB91);
  static const Color primaryDark = Color(0xFFF4511E);
  // Readable ink for small labels on the warm, light surfaces.
  static const Color primaryInk = Color(0xFFAC3917);
  static const Color successInk = Color(0xFF246A38);
  static const Color warningInk = Color(0xFF855400);
  static const Color infoInk = Color(0xFF21649A);

  // Text
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF827267);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF2196F3);

  // Other
  static const Color divider = Color(0xFFEEEEEE);
  static const Color shadow = Color(0x1F000000);

  // Sıcak yüzeyler — açılış sahnesiyle (ScenePalette) aynı tonlar.
  // Krem zeminde saf siyah/gri soğuk bir yama gibi durduğu için bildirim ve
  // diyalog gibi "öne çıkan" yüzeyler bu mürekkebi ve kremi kullanır.
  static const Color ink = Color(0xFF2E2019);
  static const Color inkSoft = Color(0xFF8A7263);
  static const Color creamTop = Color(0xFFFFFDFA);
  static const Color creamBottom = Color(0xFFF7E9DB);
  static const Color sand = Color(0xFFEFC1A2);

  // Social buttons
  static const Color appleButton = Color(0xFF000000);
  static const Color googleButton = Color(0xFF00796B);
}

class AppTypography {
  static const String fontFamily = 'Korolev';

  // Headlines
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Button
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double screenPadding = 20;
  static const double cardPadding = 16;
  static const double sectionSpacing = 24;

  // Responsive spacing based on screen width
  static double responsivePadding(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.8;
    if (width > 600) return baseSize * 1.2;
    return baseSize;
  }
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}

/// Shared, quiet depth: warm contact shadow + a broad ambient shadow.
class AppDepth {
  static const card = [
    BoxShadow(color: Color(0x0D59361F), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0859361F), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x1859361F), blurRadius: 32, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0A59361F), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const border = Color(0xFFEEDFD3);
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.creamTop, AppColors.creamBottom],
  );
  static BoxDecoration iconTile({Color color = AppColors.primary}) =>
      BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      );
  static BoxDecoration surface({
    double radius = AppRadius.lg,
    bool warm = false,
    bool elevated = false,
  }) => BoxDecoration(
    color: warm ? null : AppColors.surface,
    gradient: warm ? gradient : null,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    boxShadow: elevated ? floating : card,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryLight,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryInk,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.sand),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryInk,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppDepth.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x2859361F),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppDepth.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppDepth.border,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.creamTop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.h3,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
}
