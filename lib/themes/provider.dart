import 'package:flutter/material.dart';

class ThemeProvider extends InheritedWidget {
  final String currentTheme;
  final void Function(String theme) changeTheme;

  const ThemeProvider({
    Key? key,
    required this.currentTheme,
    required this.changeTheme,
    required Widget child,
  }) : super(key: key, child: child);

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return currentTheme != oldWidget.currentTheme;
  }
}
