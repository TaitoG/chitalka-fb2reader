import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

class DictionaryEntry {
  final String word;
  final String definition;
  final String? pronunciation;
  final List<String> examples;

  DictionaryEntry({
    required this.word,
    required this.definition,
    this.pronunciation,
    this.examples = const [],
  });
}

class DictionaryService {
  final Map<String, dynamic> _indexCache = {};
  final Map<String, String> _dictCache = {};
  late ByteData _dictData;
  String _currentDictionary = '';

  // Cache for word list
  List<String>? _cachedWordList;
  String? _cachedDictionaryId;

  String get currentDictionary => _currentDictionary;

  Future<void> loadDictionary(String dictCode) async {
    try {
      _currentDictionary = dictCode;
      _indexCache.clear();
      _dictCache.clear();

      // Clear word list cache when loading new dictionary
      _cachedWordList = null;
      _cachedDictionaryId = null;

      final indexPath = 'assets/dicts/$dictCode/$dictCode.index';
      final dictPath = 'assets/dicts/$dictCode/$dictCode.dict';

      final indexContent = await rootBundle.loadString(indexPath);
      _dictData = await rootBundle.load(dictPath);

      _parseIndex(indexContent);
      print('📚 Dictionary "$dictCode" loaded (${_indexCache.length} entries)');
    } catch (e) {
      print('❌ Error loading dictionary: $e');
      rethrow;
    }
  }

  void _parseIndex(String content) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    int decodeBase(String s) {
      int result = 0;
      for (var c in s.codeUnits) {
        final idx = alphabet.indexOf(String.fromCharCode(c));
        if (idx < 0) continue;
        result = result * 64 + idx;
      }
      return result;
    }

    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length >= 3) {
        final word = parts[0].trim().toLowerCase();
        final offset = decodeBase(parts[1]);
        final length = decodeBase(parts[2]);
        _indexCache[word] = {'offset': offset, 'length': length};
      } else if (parts.length == 2) {
        final word = parts[0].trim().toLowerCase();
        final offset = decodeBase(parts[1]);
        _indexCache[word] = {'offset': offset, 'length': 1024};
      }
    }
  }

  Future<List<DictionaryEntry>> lookupWord(String word) async {
    final cleanWord = word.trim().toLowerCase();
    MapEntry<String, dynamic>? bestMatch;

    if (_indexCache.containsKey(cleanWord)) {
      bestMatch = MapEntry(cleanWord, _indexCache[cleanWord]);
    } else {
      final best = _indexCache.entries
          .map((e) => MapEntry(e.key, _similarity(e.key, cleanWord)))
          .sorted((a, b) => b.value.compareTo(a.value))
          .take(3)
          .toList();

      if (best.isNotEmpty && best.first.value > 0.6) {
        bestMatch = MapEntry(best.first.key, _indexCache[best.first.key]);
        print('🔍 Fuzzy matched "$cleanWord" → "${best.first.key}" (${best.first.value.toStringAsFixed(2)})');
      }
    }

    if (bestMatch == null) return [];

    final offset = bestMatch.value['offset'] as int;
    final length = bestMatch.value['length'] as int;

    final definition = await _readDefinition(offset, length);
    if (definition == null) return [];

    return [DictionaryEntry(word: bestMatch.key, definition: definition)];
  }

  Future<String?> _readDefinition(int offset, int length) async {
    if (offset + length > _dictData.lengthInBytes) {
      length = _dictData.lengthInBytes - offset;
    }
    try {
      final bytes = _dictData.buffer.asUint8List(offset, length);
      String text;
      try {
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      return text.split('\x00').first.trim();
    } catch (e) {
      print('❌ Read definition error: $e');
      return null;
    }
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    int matches = 0;
    int maxDist = (a.length / 2 - 1).round();
    final aMatches = List<bool>.filled(a.length, false);
    final bMatches = List<bool>.filled(b.length, false);

    for (int i = 0; i < a.length; i++) {
      int start = (i - maxDist).clamp(0, b.length);
      int end = (i + maxDist + 1).clamp(0, b.length);
      for (int j = start; j < end; j++) {
        if (bMatches[j]) continue;
        if (a[i] != b[j]) continue;
        aMatches[i] = true;
        bMatches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    double t = 0;
    int k = 0;
    for (int i = 0; i < a.length; i++) {
      if (!aMatches[i]) continue;
      while (!bMatches[k]) k++;
      if (a[i] != b[k]) t++;
      k++;
    }
    t /= 2;

    double m = matches.toDouble();
    double jaro = (m / a.length + m / b.length + (m - t) / m) / 3.0;

    int prefix = 0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] == b[i]) prefix++;
      else break;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  /// Returns all words from the currently loaded dictionary
  /// Used for fuzzy matching and autocomplete
  Future<List<String>> getAllWords() async {
    // Return cached list if dictionary hasn't changed
    if (_cachedWordList != null && _cachedDictionaryId == _currentDictionary) {
      return _cachedWordList!;
    }

    // Make sure dictionary is loaded
    if (_indexCache.isEmpty) {
      return [];
    }

    // Extract all keys (words) from the index cache
    final words = _indexCache.keys.toList();

    // Cache the result
    _cachedWordList = words;
    _cachedDictionaryId = _currentDictionary;

    return words;
  }

  /// Get words matching a prefix (efficient for autocomplete)
  Future<List<String>> getWordsWithPrefix(String prefix) async {
    if (_indexCache.isEmpty) {
      return [];
    }

    final lowerPrefix = prefix.toLowerCase();
    return _indexCache.keys
        .where((word) => word.startsWith(lowerPrefix))
        .toList();
  }

  /// Get fuzzy matches for a word with configurable threshold
  Future<List<String>> getFuzzyMatches(
      String searchWord, {
        int limit = 5,
        double threshold = 0.6,
      }) async {
    final allWords = await getAllWords();

    if (allWords.isEmpty) {
      return [];
    }

    final matches = <String, double>{};
    final search = searchWord.toLowerCase();

    // Calculate similarity for each word
    for (final word in allWords) {
      final similarity = _similarity(search, word);
      if (similarity > threshold) {
        matches[word] = similarity;
      }
    }

    // Sort by similarity descending and return top matches
    final sortedMatches = matches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedMatches
        .take(limit)
        .map((e) => e.key)
        .toList();
  }

  /// Get multiple fuzzy matches with their similarity scores
  /// Useful for showing "Did you mean?" suggestions
  Future<List<MapEntry<String, double>>> getFuzzyMatchesWithScores(
      String searchWord, {
        int limit = 5,
        double threshold = 0.6,
      }) async {
    final allWords = await getAllWords();

    if (allWords.isEmpty) {
      return [];
    }

    final matches = <String, double>{};
    final search = searchWord.toLowerCase();

    for (final word in allWords) {
      final similarity = _similarity(search, word);
      if (similarity > threshold) {
        matches[word] = similarity;
      }
    }

    final sortedMatches = matches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedMatches.take(limit).toList();
  }
}
