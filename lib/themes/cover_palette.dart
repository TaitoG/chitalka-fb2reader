import 'package:flutter/material.dart';

class CoverPalettes {
  static final List<Map<String, Color>> light = [
    _palette(0xFFE8EAF6, 0xFFC5CAE9, 0xFF3F51B5, 0xFF1A237E), // Indigo
    _palette(0xFFF3E5F5, 0xFFCE93D8, 0xFF7B1FA2, 0xFF4A148C), // Purple
    _palette(0xFFE0F2F1, 0xFF80CBC4, 0xFF00695C, 0xFF004D40), // Teal
    _palette(0xFFFFF3E0, 0xFFFFCC80, 0xFFFF6F00, 0xFFBF360C), // Orange
    _palette(0xFFE8F5E8, 0xFFA5D6A7, 0xFF388E3C, 0xFF1B5E20), // Green
    _palette(0xFFFFEBEE, 0xFFFF8A80, 0xFFD32F2F, 0xFF9A0007), // Red
    _palette(0xFFE3F2FD, 0xFF90CAF9, 0xFF1976D2, 0xFF0D47A1), // Blue
    _palette(0xFFFBE9E7, 0xFFFFAB91, 0xFFFF5722, 0xFFDD2C00), // Deep Orange
    _palette(0xFFF1F8E9, 0xFFDCEDC8, 0xFF689F38, 0xFF33691E), // Light Green
    _palette(0xFFF3E5F5, 0xFFEA80FC, 0xFF9C27B0, 0xFF4A148C), // Deep Purple
    _palette(0xFFE0F7FA, 0xFF80DEEA, 0xFF00ACC1, 0xFF006064), // Cyan
    _palette(0xFFFFF8E1, 0xFFFFE082, 0xFFFF8F00, 0xFFCC6B00), // Amber
  ];

  static final List<Map<String, Color>> dark = [
    _palette(0xFF1A237E, 0xFF3F51B5, 0xFF7986CB, 0xFFE8EAF6),
    _palette(0xFF4A148C, 0xFF7B1FA2, 0xFFBA68C8, 0xFFF3E5F5),
    _palette(0xFF004D40, 0xFF00695C, 0xFF80CBC4, 0xFFE0F2F1),
    _palette(0xFFBF360C, 0xFFFF6F00, 0xFFFFCC80, 0xFFFFF3E0),
    _palette(0xFF1B5E20, 0xFF388E3C, 0xFFA5D6A7, 0xFFE8F5E8),
    _palette(0xFF9A0007, 0xFFD32F2F, 0xFFFF8A80, 0xFFFFEBEE),
    _palette(0xFF0D47A1, 0xFF1976D2, 0xFF90CAF9, 0xFFE3F2FD),
    _palette(0xFFDD2C00, 0xFFFF5722, 0xFFFFAB91, 0xFFFBE9E7),
    _palette(0xFF33691E, 0xFF689F38, 0xFFDCEDC8, 0xFFF1F8E9),
    _palette(0xFF4A148C, 0xFF9C27B0, 0xFFEA80FC, 0xFFF3E5F5),
    _palette(0xFF006064, 0xFF00ACC1, 0xFF80DEEA, 0xFFE0F7FA),
    _palette(0xFFCC6B00, 0xFFFF8F00, 0xFFFFE082, 0xFFFFF8E1),
  ];

  static final List<Map<String, Color>> sepia = [
    _palette(0xFFD7CCC8, 0xFFBCAAA4, 0xFF8D6E63, 0xFF5D4037),
    _palette(0xFFEEECE1, 0xFFD7CCC8, 0xFF8D6E63, 0xFF5D4037),
    _palette(0xFFFFF8E1, 0xFFFFF0C7, 0xFF8D6E63, 0xFF5D4037),
    _palette(0xFFE6D9C1, 0xFFCCB9A3, 0xFF8B6F47, 0xFF5D4037),
    _palette(0xFFF5F0E8, 0xFFE8E0D0, 0xFF8B6F47, 0xFF5D4037),
    _palette(0xFFFFF5E6, 0xFFFFE8CC, 0xFF8B6F47, 0xFF5D4037),
    _palette(0xFFE8E8D8, 0xFFD8D8C0, 0xFF8B6F47, 0xFF5D4037),
    _palette(0xFFF0E6D9, 0xFFE0D0C0, 0xFF8B6F47, 0xFF5D4037),
  ];

  static Map<String, Color> _palette(int p, int s, int i, int t) {
    return {
      'primary': Color(p),
      'secondary': Color(s),
      'icon': Color(i),
      'text': Color(t),
    };
  }

  static Map<String, Color> getForBook(String title, ThemeData theme) {
    final hash = title.hashCode.abs();
    final isDark = theme.brightness == Brightness.dark;
    final isSepia = theme.scaffoldBackgroundColor == const Color(0xFFF5E6CC);

    final palette = isDark
        ? dark
        : (isSepia ? sepia : light);

    final index = hash % palette.length;
    return palette[index];
  }
}