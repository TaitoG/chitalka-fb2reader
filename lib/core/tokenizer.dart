//tokenizer.dart
import 'package:chitalka/models/word_token.dart';

class TextTokenizer {
  static List<WordToken> tokenize(String text) {
    final tokens = <WordToken>[];
    final regex = RegExp(
      r'''([\p{L}\p{N}]+(?:'[\p{L}\p{N}]*)*|[^\p{L}\p{N}\s]|\s+)''',
      unicode: true,
    );
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final token = match.group(0)!;
      final startOffset = match.start;

      final isWord = RegExp(
        r'''^[\p{L}\p{N}]+(?:'[\p{L}\p{N}]*)*$''',
        unicode: true,
      ).hasMatch(token);

      tokens.add(WordToken(
        text: token,
        word: isWord ? token : '',
        startOffset: startOffset,
      ));
    }

    return tokens;
  }
}