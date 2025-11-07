import '../models/token.dart';

List<Token> tokenize(String text) {
  final tokens = <Token>[];
  final headerPattern = RegExp(r'§([^§]+)§');
  int lastEnd = 0;

  for (final match in headerPattern.allMatches(text)) {
    if (match.start > lastEnd) {
      final prefix = text.substring(lastEnd, match.start);
      tokens.addAll(_splitIntoTokens(prefix));
    }

    final title = match.group(1)!;
    tokens.add(Token(
      text: '$title\n',
      cleanWord: '',
      isHeader: true,
      headerTitle: title,
    ));

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    tokens.addAll(_splitIntoTokens(text.substring(lastEnd)));
  }
  return tokens;
}

List<Token> _splitIntoTokens(String text) {
  final tokens = <Token>[];
  final pattern = RegExp(
    r"""[a-zA-Zа-яА-ЯёЁ0-9'’\-]+|[^\sa-zA-Zа-яА-ЯёЁ0-9'’\-]+|\s+""",
    unicode: true,
  );

  for (final match in pattern.allMatches(text)) {
    final word = match.group(0)!;
    if (RegExp(r'\s').hasMatch(word)) {
      tokens.add(Token(text: word, cleanWord: ''));
      continue;
    }
    final clean = word
        .replaceAll(RegExp(r'[^\wа-яА-ЯёЁ]'), '')
        .toLowerCase();
    tokens.add(Token(text: word, cleanWord: clean));
  }
  return tokens;
}