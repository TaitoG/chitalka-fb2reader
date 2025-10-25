import 'package:chitalka/models/word_token.dart';

class PageData {
  final String text;
  final List<WordToken> tokens;

  PageData({
    required this.text,
    required this.tokens,
  });

  PageData copyWith({
    String? text,
    List<WordToken>? tokens,
  }) {
    return PageData(
      text: text ?? this.text,
      tokens: tokens ?? this.tokens,
    );
  }
}