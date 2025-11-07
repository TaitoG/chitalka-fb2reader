class Token {
  final String text;
  final String cleanWord;
  final bool isHeader;
  final String? headerTitle;

  Token({
    required this.text,
    this.cleanWord = '',
    this.isHeader = false,
    this.headerTitle,
  });
}