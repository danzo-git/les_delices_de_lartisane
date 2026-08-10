import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Styles de texte réutilisables selon le Design System
  static TextStyle get titreH1 => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.texte,
        height: 32 / 24,
      );

  static TextStyle get titreH2 => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.texte,
        height: 28 / 20,
      );

  static TextStyle get titreH3 => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.texte,
        height: 24 / 16,
      );

  static TextStyle get corps => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.texte,
        height: 20 / 14,
      );

  /// Thème global ThemeData de l'application
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    final customTextTheme = baseTextTheme.copyWith(
      displayLarge: titreH1,
      headlineMedium: titreH2,
      titleMedium: titreH3,
      bodyMedium: corps,
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.secondaire,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaire,
        onPrimary: Colors.white,
        secondary: AppColors.primaireClair,
        onSecondary: AppColors.texte,
        surface: AppColors.fond,
        onSurface: AppColors.texte,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      textTheme: customTextTheme,
      
      // Style Bouton Principal (Filled / ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaire,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Style Bouton Outline (OutlinedButton)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaire,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.primaire, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Style Bouton Texte (TextButton)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaire,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Champs de saisie (TextField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.secondaire.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.secondaire.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaire, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.secondaire,
        ),
      ),
    );
  }
}
