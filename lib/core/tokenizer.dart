
import 'package:chitalka/models/word_token.dart';

class TextTokenizer {
  static List<WordToken> tokenize(String text) {
    final tokens = <WordToken>[];
    final regex = RegExp(r'(\S+\s*)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final fullToken = match.group(0)!;
      final wordMatch = RegExp(r'\S+').firstMatch(fullToken);
      if (wordMatch != null) {
        tokens.add(WordToken(
          text: fullToken,
          word: wordMatch.group(0)!,
          startOffset: 0,
        ));
      }
    }

    return tokens;
  }
}