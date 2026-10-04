import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens do Gatálogo — "O Herbário Felino Acolhedor"
///
/// Regras fundamentais:
/// - Zero preto puro (#000000) em qualquer lugar
/// - Papel com elevação suave nas áreas de jogo; formulários mantêm leitura limpa
/// - Cantos arredondados contínuos (14–24px)
/// - Fredoka para títulos, Nunito para corpo
class AppColors {
  AppColors._();

  // ─── Superfícies ─────────────────────────────────────────────
  static const Color background = Color(0xFFFBF6E8);
  static const Color surface = Color(0xFFFFF9EC);
  static const Color cardBackground = Color(0xFFF8F0DF);
  static const Color cardAltBackground = Color(0xFFFFFAEF);

  // ─── Rosa Principal (CTAs e acentos de marca) ────────────────
  static const Color primary = Color(0xFFDC8BA1);
  static const Color primaryDark = Color(0xFFC7607E);
  static const Color primaryLight = Color(0xFFFCEBE8);
  static const Color primarySoftBg = Color(0xFFFCEDED);

  // ─── Verde Botânico ──────────────────────────────────────────
  static const Color green = Color(0xFF6A914C);
  static const Color greenButton = Color(0xFF52783C);
  static const Color greenLight = Color(0xFFECF2D8);
  static const Color greenLink = Color(0xFF426538);
  static const Color greenProgress = Color(0xFF6B8A5A);

  // ─── Textos Neutros (marrons quentes, nunca preto) ──────────
  static const Color textDark = Color(0xFF4B281B);
  static const Color textTitle = Color(0xFF4B281B);
  static const Color textMedium = Color(0xFF80654E);
  static const Color textLight = Color(0xFF948C87);

  // ─── Bordas e Divisores ──────────────────────────────────────
  static const Color border = Color(0xFFBCA381);
  static const Color borderLight = Color(0xFFE2D4B7);
  static const Color borderProfile = Color(0xFFBCA381);

  // ─── Inputs ──────────────────────────────────────────────────
  static const Color inputBg = Color(0xFFFFF8E9);

  // ─── Atalhos / Badges (Home Page) ────────────────────────────
  static const Color shortcutGreenBg = Color(0xFFF0F4EC);
  static const Color shortcutGreenIcon = Color(0xFF5A734D);
  static const Color shortcutBlueBg = Color(0xFFEAF2FD);
  static const Color shortcutBlueIcon = Color(0xFF4976BA);
  static const Color shortcutYellowBg = Color(0xFFFEF9D9);
  static const Color shortcutYellowIcon = Color(0xFFA48936);
  static const Color shortcutPinkBg = Color(0xFFFDEEED);
  static const Color shortcutPinkIcon = Color(0xFFB84F6E);

  // ─── Card "Explorar sem conta" ───────────────────────────────
  static const Color guestCardBg = Color(0xFFF0EEE3);
  static const Color guestCardText = Color(0xFF4A5844);
  static const Color guestCardSubtext = Color(0xFF7A8772);

  // ═══ GAMIFICAÇÃO — tons quentes e acolhedores ════════════════

  // ─── Conquistas (troféus e progresso) ────────────────────────
  static const Color achievement = Color(0xFFF5C853);
  static const Color achievementBg = Color(0xFFFEF9E7);
  static const Color achievementText = Color(0xFF8B6914);
  static const Color achievementDark = Color(0xFFD4A828);
  static const Color amberDark = Color(0xFFD48B28);
  static const Color amberBorder = Color(0xFFF3D298);

  // ─── Social (amigos e interação) ─────────────────────────────
  static const Color socialPurple = Color(0xFF8DAB66);
  static const Color socialPurpleBg = Color(0xFFEEF1DA);
  static const Color socialPurpleText = Color(0xFF526C3A);

  // ─── Raridades de Gatos ──────────────────────────────────────
  static const Color rarityCommon = Color(0xFF6A914C);
  static const Color rarityCommonBg = Color(0xFFECF2D8);
  static const Color rarityUncommon = Color(0xFF5BA3C4);
  static const Color rarityUncommonBg = Color(0xFFE8F4FD);
  static const Color rarityRare = Color(0xFFDC8BA1);
  static const Color rarityRareBg = Color(0xFFFCEBE8);
  static const Color rarityLegendary = Color(0xFFF5C853);
  static const Color rarityLegendaryBg = Color(0xFFFEF9E7);

  // ─── Erros e Alertas (terroso, não vermelho puro) ────────────
  static const Color error = Color(0xFFD4543C);
  static const Color errorBg = Color(0xFFFDE8E8);
  static const Color errorText = Color(0xFFAA3327);

  // ─── Sucesso ─────────────────────────────────────────────────
  static const Color success = Color(0xFF5D8A4E);
  static const Color successBg = Color(0xFFEDF5E8);

  // ─── Sombras tonais (café sutil, NUNCA preto) ────────────────
  static const Color shadowWarm = Color(0x14382923);
  static const Color shadowMedium = Color(0x28382923);

  // ─── Superfícies Dark Mode (Espresso Aconchegante) ───────────
  static const Color darkBackground = Color(0xFF181412);
  static const Color darkSurface = Color(0xFF231E1B);
  static const Color darkCardBackground = Color(0xFF2E2724);
  static const Color darkCardAltBackground = Color(0xFF362E2A);
  static const Color darkBorder = Color(0xFF3D3531);
  static const Color darkBorderLight = Color(0xFF4A403A);
  static const Color darkInputBg = Color(0xFF28221F);

  // ─── Textos Dark Mode (off-white quente, nunca branco puro) ──
  static const Color darkTextDark = Color(0xFFF5EFEB);
  static const Color darkTextTitle = Color(0xFFFAF6F2);
  static const Color darkTextMedium = Color(0xFFD4C9C1);
  static const Color darkTextLight = Color(0xFFA89F99);
}

/// Escala de espaçamento padronizada (base 4px)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Raios de borda padronizados (14–24px contínuos)
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 14;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 24;
  static const double card = 18;
  static const double input = 16;
  static const double photo = 16;
  static const double button = 24;
  static const double dialog = 24;
}

/// Durations padrão para animações suaves (cozy)
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration celebration = Duration(milliseconds: 600);
}

/// Curves padrão — suaves, sem bounce agressivo
class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve bounce = Curves.elasticOut;
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.green,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textDark,
        error: AppColors.error,
      ),

      // ─── Tipografia: Fredoka (títulos) + Nunito (corpo) ──────
      textTheme: baseTextTheme.copyWith(
        // Fredoka para hierarquia de títulos
        headlineLarge: GoogleFonts.fredoka(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          height: 1.15,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          height: 1.15,
        ),
        headlineSmall: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          height: 1.2,
        ),
        displayLarge: GoogleFonts.fredoka(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.fredoka(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          height: 1.15,
        ),
        titleLarge: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          height: 1.1,
        ),
        titleMedium: GoogleFonts.fredoka(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        titleSmall: GoogleFonts.fredoka(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        // Nunito para corpo, labels e captions
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          height: 1.3,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textMedium,
          height: 1.3,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textLight,
          height: 1.2,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMedium,
        ),
      ),

      // ─── Inputs ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textLight,
        ),
        prefixIconColor: AppColors.textMedium,
        suffixIconColor: AppColors.textMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),

      // ─── Botões: formato pílula, elevação zero ───────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textTitle,
          elevation: 0,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.greenLink,
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ─── Cards: cantos suaves, sem elevação ──────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.greenLight,
        disabledColor: AppColors.borderLight,
        checkmarkColor: AppColors.greenLink,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: GoogleFonts.nunito(
          color: AppColors.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),

      // ─── Dividers: borda quente ──────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: AppSpacing.xl,
      ),

      // ─── AppBar: transparente, sem sombra ────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark, size: 24),
      ),

      // ─── Switch: verde botânico quando ativo ─────────────────
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.green;
          return AppColors.textLight;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.green;
          return AppColors.textLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.greenLight;
          }
          return AppColors.borderLight;
        }),
      ),

      // ─── Slider: rosa Gatálogo ───────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.borderLight,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x22DC8BA1),
      ),

      // ─── ProgressIndicator: verde botânico ───────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.greenProgress,
        linearTrackColor: AppColors.greenLight,
        circularTrackColor: AppColors.greenLight,
      ),

      // ─── Dialog: fundo pergaminho, cantos generosos ──────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textMedium,
        ),
      ),

      // ─── SnackBar: estilizado ────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textDark,
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ─── Badge: rosa Gatálogo ────────────────────────────────
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.primary,
        textColor: Colors.white,
      ),

      // ─── BottomSheet ─────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.green,
        onSecondary: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextDark,
        error: AppColors.error,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.fredoka(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
          height: 1.15,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
          height: 1.15,
        ),
        headlineSmall: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
          height: 1.2,
        ),
        displayLarge: GoogleFonts.fredoka(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextDark,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.fredoka(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextDark,
          height: 1.15,
        ),
        titleLarge: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
          height: 1.1,
        ),
        titleMedium: GoogleFonts.fredoka(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
        ),
        titleSmall: GoogleFonts.fredoka(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
          height: 1.3,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextMedium,
          height: 1.3,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextLight,
          height: 1.2,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextDark,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputBg,
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextLight,
        ),
        prefixIconColor: AppColors.darkTextMedium,
        suffixIconColor: AppColors.darkTextMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextTitle,
          elevation: 0,
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.darkBorderLight, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.green.withValues(alpha: 0.3),
        disabledColor: AppColors.darkBorderLight,
        checkmarkColor: AppColors.darkTextDark,
        side: const BorderSide(color: AppColors.darkBorderLight, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: GoogleFonts.nunito(
          color: AppColors.darkTextDark,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: AppSpacing.xl,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextDark, size: 24),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.green;
          return AppColors.darkTextLight;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.green;
          return AppColors.darkTextLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.green.withValues(alpha: 0.3);
          }
          return AppColors.darkBorderLight;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextDark,
        ),
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextMedium,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
    );
  }
}
