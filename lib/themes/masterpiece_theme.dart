import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 MASTERPIECE APP THEME - Unified Design System
/// Ensures consistency across all screens with professional branding
class MasterpieceTheme {
  // ─── PRIMARY COLORS ─────────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color primaryGreenDark = Color(0xFF0D3B14);
  static const Color primaryGreenLight = Color(0xFF2E86C1); // Accent green
  static const Color secondaryGreen = Color(0xFF388E3C);
  
  // ─── ACCENT COLORS ──────────────────────────────────────────────────────────
  static const Map<String, Color> dayColors = {
    'Monday': Color(0xFF2E86C1),
    'Tuesday': Color(0xFF117A65),
    'Wednesday': Color(0xFF8E44AD),
    'Thursday': Color(0xFFD35400),
    'Friday': Color(0xFFC0392B),
    'Saturday': Color(0xFFD35400),
    'Sunday': Color(0xFF8E44AD),
  };
  
  static const Color successGreen = Color(0xFF27AE60);
  static const Color warningOrange = Color(0xFFF39C12);
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color inspirationalPurple = Color(0xFF8E44AD);
  static const Color triviaBlue = Color(0xFF2E86C1);
  static const Color bibleViolet = Color(0xFF8E44AD);
  
  // ─── NEUTRAL COLORS ─────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF0F4F8);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGray = Color(0xFF6C757D);
  
  // ─── SHADOWS ──────────────────────────────────────────────────────────────
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Color(0x15000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> harShadow = [
    BoxShadow(
      color: Color(0x20000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
  
  // ─── BORDER RADIUS ──────────────────────────────────────────────────────────
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXL = 20;
  
  // ─── TEXT STYLES ────────────────────────────────────────────────────────────
  static TextStyle get headingXL => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: primaryGreen,
  );
  
  static TextStyle get headingLarge => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: primaryGreen,
  );
  
  static TextStyle get headingMedium => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: primaryGreen,
  );
  
  static TextStyle get headingSmall => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: primaryGreen,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textDark,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textDark,
  );
  
  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textGray,
  );
  
  static TextStyle get labelLarge => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textDark,
  );
  
  static TextStyle get labelMedium => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textDark,
  );
  
  static TextStyle get labelSmall => GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textGray,
  );
  
  // ─── SPACING ────────────────────────────────────────────────────────────────
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 12;
  static const double spacingL = 16;
  static const double spacingXL = 24;
  static const double spacingXXL = 32;
  
  // ─── THEME DATA ─────────────────────────────────────────────────────────────
  // ─── THEME DATA ─────────────────────────────────────────────────────────────
  static ThemeData get themeData => _buildTheme(Brightness.light);
  static ThemeData get darkThemeData => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF2E7D32) : primaryGreen;
    final surface = isDark ? const Color(0xFF1E1E1E) : surfaceWhite;
    final background = isDark ? const Color(0xFF121212) : backgroundLight;
    final text = isDark ? Colors.white : textDark;
    final gray = isDark ? Colors.grey.shade400 : textGray;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: brightness,
        primary: primary,
        secondary: secondaryGreen,
        tertiary: inspirationalPurple,
        surface: surface,
        surfaceTint: primary,
      ),
      // Text theme
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: text,
        displayColor: text,
      ),
      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1B5E20) : primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Cards
      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        color: isDark ? const Color(0xFF2C2C2C) : surfaceWhite,
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          elevation: 2,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(color: gray),
        labelStyle: GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      // Scaffold
      scaffoldBackgroundColor: background,
      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : surfaceWhite,
        selectedItemColor: primary,
        unselectedItemColor: gray,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
        elevation: 8,
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF333333) : Colors.grey.shade100,
        selectedColor: primary,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    );
  }
  
  // ─── HELPER METHODS ─────────────────────────────────────────────────────────
  
  /// Get color for a specific day of week
  static Color getColorForDay(String day) {
    return dayColors[day] ?? primaryGreen;
  }
  
  /// Get emoji for a specific day
  static String getEmojiForDay(String day) {
    const emojis = {
      'Monday': '💡',
      'Tuesday': '📌',
      'Wednesday': '🎯',
      'Thursday': '🚀',
      'Friday': '🎉',
      'Saturday': '✨',
      'Sunday': '📖',
    };
    return emojis[day] ?? '📅';
  }
  
  /// Create a standardized card widget
  static Widget buildCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(spacingL),
    Color backgroundColor = surfaceWhite,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radiusLarge),
        boxShadow: shadows ?? mediumShadow,
      ),
      child: child,
    );
  }
  
  /// Create a KPI display card
  static Widget buildKPICard({
    required String label,
    required String value,
    required Color color,
    bool isCompact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(spacingL),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: isCompact ? 20 : 28,
              color: color,
            ),
          ),
          const SizedBox(height: spacingS),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 11 : 13,
              color: textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
