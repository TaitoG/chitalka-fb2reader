
import 'package:chitalka/models/word_token.dart';

class TextTokenizer {
  static List<WordToken> tokenize(String text) {
    final tokens = <WordToken>[];
    final regex = RegExp(r'''(\w+(?:\'\w+)*|[^\w\s]|\s+)''');
    final matches = regex.allMatches(text);

    for (final match in matches) {
    final token = match.group(0)!;
    final startOffset = match.start;

    final isWord = RegExp(r'''^\w+(?:\'\w+)*$''').hasMatch(token);

    tokens.add(WordToken(
    text: token,
    word: isWord ? token : '',
    startOffset: startOffset,
    ));
    }

    return tokens;
  }
}