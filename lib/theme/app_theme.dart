import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color bgPrimary = Color(0xFF0F1117);
  static const Color bgSecondary = Color(0xFF181D2A);
  static const Color bgTertiary = Color(0xFF1E2435);
  static const Color bgCard = Color(0xFF1C2130);
  static const Color border = Color(0xFF2A3245);
  static const Color borderLight = Color(0xFF374260);

  static const Color textPrimary = Color(0xFFE8EAFF);
  static const Color textSecondary = Color(0xFF9EA3B2);
  static const Color textMuted = Color(0xFF5B6478);

  static const Color accent = Color(0xFF3D6FFF);
  static const Color accentLight = Color(0xFF5B9BFF);
  static const Color accentBg = Color(0xFF1E3A6E);

  // Method colors
  static const Color methodGet = Color(0xFF22C55E);
  static const Color methodGetBg = Color(0xFF0F2D1C);
  static const Color methodPost = Color(0xFF60A5FA);
  static const Color methodPostBg = Color(0xFF1A2D5A);
  static const Color methodPut = Color(0xFFF59E0B);
  static const Color methodPutBg = Color(0xFF2D200A);
  static const Color methodDelete = Color(0xFFF87171);
  static const Color methodDelBg = Color(0xFF2D0F0F);
  static const Color methodPatch = Color(0xFFA78BFA);
  static const Color methodPatchBg = Color(0xFF21133D);

  // Status colors
  static const Color statusOnline = Color(0xFF22C55E);
  static const Color statusOffline = Color(0xFF4B5563);
  static const Color statusWarning = Color(0xFFF59E0B);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentLight,
      surface: bgSecondary,
      background: bgPrimary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgSecondary,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: textMuted,
      indicatorColor: accent,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accent, width: 1),
      ),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentLight,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 14),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      bodySmall: TextStyle(color: textMuted, fontSize: 12),
      labelSmall: TextStyle(
        color: textMuted,
        fontSize: 11,
        letterSpacing: 0.06,
      ),
    ),
  );
}

// Helper extensions
extension MethodColor on String {
  Color get methodColor {
    switch (toUpperCase()) {
      case 'GET':
        return AppTheme.methodGet;
      case 'POST':
        return AppTheme.methodPost;
      case 'PUT':
        return AppTheme.methodPut;
      case 'DELETE':
        return AppTheme.methodDelete;
      case 'PATCH':
        return AppTheme.methodPatch;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color get methodBgColor {
    switch (toUpperCase()) {
      case 'GET':
        return AppTheme.methodGetBg;
      case 'POST':
        return AppTheme.methodPostBg;
      case 'PUT':
        return AppTheme.methodPutBg;
      case 'DELETE':
        return AppTheme.methodDelBg;
      case 'PATCH':
        return AppTheme.methodPatchBg;
      default:
        return AppTheme.bgTertiary;
    }
  }

  Color get statusCodeColor {
    final code = int.tryParse(this) ?? 0;
    if (code >= 200 && code < 300) return AppTheme.methodGet;
    if (code >= 300 && code < 400) return AppTheme.methodPut;
    if (code >= 400) return AppTheme.methodDelete;
    return AppTheme.textSecondary;
  }
}
