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
    )
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
    )
  );
}