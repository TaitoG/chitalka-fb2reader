import 'dart:ui';

class LayoutWord {
  final String text;
  final String cleanWord;
  final Offset position;
  final Size size;
  final int documentOffset;
  final bool isHeader;

  LayoutWord({
    required this.text,
    required this.cleanWord,
    required this.position,
    required this.size,
    required this.documentOffset,
    this.isHeader = false,
  });

  Rect get bounds => position & size;
}

class LayoutLine {
  final List<LayoutWord> words;
  final double y;
  final double height;

  LayoutLine({
    required this.words,
    required this.y,
    required this.height,
  });
}