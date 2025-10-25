class WordToken {
  final String text;
  final String word;
  final int startOffset;

  WordToken({
    required this.text,
    required this.word,
    required this.startOffset,
  });

  WordToken copyWithOffset(int offset) {
    return WordToken(
      text: text,
      word: word,
      startOffset: offset,
    );
  }
}