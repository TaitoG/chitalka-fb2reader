// services/theme_service.dart
import 'package:flutter/material.dart';

enum AppTheme { light, dark, sepia }

class ThemeService {
  static final Map<AppTheme, ThemeData> themes = {
    AppTheme.light: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF000000)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F8F8),
        foregroundColor: Color(0xFF000000),
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6200EE),
        secondary: Color(0xFF03DAC6),
      ),
    ),
    AppTheme.dark: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Color(0xFFE0E0E0),
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBB86FC),
        secondary: Color(0xFF03DAC6),
      ),
    ),
    AppTheme.sepia: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5E6CC),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF5C4033)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFE8D5B8),
        foregroundColor: Color(0xFF5C4033),
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF8B6F47),
        secondary: Color(0xFF8B6F47),
      ),
    ),
  };

  static Color getTextColor(AppTheme theme) {
    return themes[theme]!.textTheme.bodyMedium!.color!;
  }

  static Color getBackgroundColor(AppTheme theme) {
    return themes[theme]!.scaffoldBackgroundColor!;
  }

  static Color getHeaderBgColor(AppTheme theme) {
    return switch (theme) {
      AppTheme.light => const Color(0xFFF5F5F5),
      AppTheme.dark => const Color(0xFF131313),
      AppTheme.sepia => const Color(0xFFE8D5B8),
    };
  }

  static Color getHighlightColor(AppTheme theme) {
    return switch (theme) {
      AppTheme.light => Colors.yellow.withOpacity(0.5),
      AppTheme.dark => const Color(0xFFFFD700).withOpacity(0.4),
      AppTheme.sepia => const Color(0xFFFFEB99).withOpacity(0.5),
    };
  }
}