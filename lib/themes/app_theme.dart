// themes/app_themes.dart
import 'package:flutter/material.dart';

class AppThemes {
  static final light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F8F8),
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black),
      titleLarge: TextStyle(color: Colors.black),
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.black,
      textColor: Colors.black,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
       backgroundColor: Colors.deepPurple,
       foregroundColor: Color(0xFFE0E0E0)
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFF8F8F8),
      selectedItemColor: Colors.deepPurple
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.deepPurple,
      surface: Colors.white,
      surfaceContainer: const Color(0xFFF5F5F5),
      surfaceContainerHighest: const Color(0xFFF8F9FA),
      outline: Colors.grey.shade400,
      onSurfaceVariant: Colors.grey.shade600,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F3F5), // surfaceContainer
      hintStyle: TextStyle(color: Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _searchBorder(Colors.grey.shade400),
      enabledBorder: _searchBorder(Colors.grey.shade400),
      focusedBorder: _searchBorder(Colors.deepPurple, width: 2),
      errorBorder: _searchBorder(Colors.red),
      prefixIconColor: Colors.grey.shade600,
      suffixIconColor: Colors.grey.shade600,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.deepPurple,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.deepPurple,
      linearTrackColor: Colors.grey.shade300,
      linearMinHeight: 6,
    ),
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2D2D2D),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      titleLarge: TextStyle(color: Color(0xFFE0E0E0)),
    ),
    iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFE0E0E0),
      textColor: Color(0xFFE0E0E0),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2D2D2D),
      foregroundColor: Color(0xFFE0E0E0)
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF2D2D2D),
      selectedItemColor: Colors.white
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.deepPurple,
      surface: const Color(0xFF1A1A1A),
      surfaceContainer: const Color(0xFF252525),
      surfaceContainerHighest: const Color(0xFF2D2D2D),
      outline: Colors.grey.shade700,
      onSurfaceVariant: Colors.grey.shade400,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF252525),
      hintStyle: TextStyle(color: Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _searchBorder(Colors.grey.shade700),
      enabledBorder: _searchBorder(Colors.grey.shade700),
      focusedBorder: _searchBorder(Colors.deepPurple, width: 2),
      errorBorder: _searchBorder(Colors.red),
      prefixIconColor: Colors.grey.shade400,
      suffixIconColor: Colors.grey.shade400,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.deepPurpleAccent,
      // cursorColor: Colors.purple.shade300,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.deepPurple.shade300,
      linearTrackColor: Colors.grey.shade800,
      linearMinHeight: 6,
    ),
  );

  static final sepia = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5E6CC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFE8D5B8),
      foregroundColor: Color(0xFF5C4033),
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFF5C4033)),
      titleLarge: TextStyle(color: Color(0xFF5C4033)),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF5C4033)),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF5C4033),
      textColor: Color(0xFF5C4033),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFE8D5B8),
      foregroundColor: Colors.brown
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFE8D5B8),
      selectedItemColor: Colors.brown
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.brown,
      surface: const Color(0xFFF5E6CC),
      surfaceContainer: const Color(0xFFFFF8E7),
      surfaceContainerHighest: const Color(0xFFFFF8E7),
      outline: const Color(0xFF8B6F47).withOpacity(0.4),
      onSurfaceVariant: const Color(0xFF8B6F47),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFF5E1),
      hintStyle: TextStyle(color: const Color(0xFF8D6E63)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _searchBorder(const Color(0xFF8B6F47).withOpacity(0.5)),
      enabledBorder: _searchBorder(const Color(0xFF8B6F47).withOpacity(0.5)),
      focusedBorder: _searchBorder(Colors.brown, width: 2),
      errorBorder: _searchBorder(Colors.red.shade700),
      prefixIconColor: const Color(0xFF8D6E63),
      suffixIconColor: const Color(0xFF8D6E63),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFF8D6E63),
      // или: Colors.brown.shade700
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: const Color(0xFF8D6E63),
      linearTrackColor: const Color(0xFF8B6F47).withOpacity(0.3),
      linearMinHeight: 6,
    ),
  );

  static OutlineInputBorder _searchBorder(Color color, {double width = 1.5}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color.withOpacity(0.6), width: width),
    );
  }
}