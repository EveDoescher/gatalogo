import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Cores exatas extraídas do Figma (402x874)
  static const Color background = Color(0xFFFBF6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFAF3F0);
  static const Color cardAltBackground = Color(0xFFFDF8F5);

  // Rosa Principal Figma
  static const Color primary = Color(0xFFDC8BA1);
  static const Color primaryDark = Color(0xFFC7607E);
  static const Color primaryLight = Color(0xFFFCEBE8);
  static const Color primarySoftBg = Color(0xFFFCEDED);

  // Verdes Figma
  static const Color green = Color(0xFF7E9B70);
  static const Color greenButton = Color(0xFF72856A);
  static const Color greenLight = Color(0xFFF1F5ED);
  static const Color greenLink = Color(0xFF5D7A58);
  static const Color greenProgress = Color(0xFF6B8A5A);

  // Textos Neutros Figma
  static const Color textDark = Color(0xFF382923);
  static const Color textTitle = Color(0xFF4A352F);
  static const Color textMedium = Color(0xFF786B67);
  static const Color textLight = Color(0xFF948C87);
  static const Color border = Color(0xFFEDDEDB);
  static const Color borderLight = Color(0xFFF3ECE6);

  // Atalhos / Badges Figma
  static const Color shortcutGreenBg = Color(0xFFF0F4EC);
  static const Color shortcutGreenIcon = Color(0xFF5A734D);
  static const Color shortcutBlueBg = Color(0xFFEAF2FD);
  static const Color shortcutBlueIcon = Color(0xFF4976BA);
  static const Color shortcutYellowBg = Color(0xFFFEF9D9);
  static const Color shortcutYellowIcon = Color(0xFFA48936);
  static const Color shortcutPinkBg = Color(0xFFFDEEED);
  static const Color shortcutPinkIcon = Color(0xFFB84F6E);

  // Fundo dos Inputs Figma
  static const Color inputBg = Color(0xFFFDF6F5);

  // Card "Explorar sem conta"
  static const Color guestCardBg = Color(0xFFF0EEE3);
  static const Color guestCardText = Color(0xFF4A5844);
  static const Color guestCardSubtext = Color(0xFF7A8772);
}

class AppTheme {
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
        error: Color(0xFFD32F2F),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.nunito(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        displayMedium: GoogleFonts.nunito(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleSmall: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textMedium,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textLight,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFCFAF7),
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textLight,
        ),
        prefixIconColor: AppColors.textMedium,
        suffixIconColor: AppColors.textMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
    );
  }
}
