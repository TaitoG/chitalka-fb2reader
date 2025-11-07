// translation_sheet.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chitalka/services/dictionary.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

class TranslationBottomSheet extends StatefulWidget {
  final String word;
  final DictionaryService dictionaryService;
  final BookmarkService bookmarkService;
  final String bookId;
  final VoidCallback? onBookmarkPressed;

  const TranslationBottomSheet({
    Key? key,
    required this.word,
    required this.dictionaryService,
    required this.bookmarkService,
    required this.bookId,
    required this.onBookmarkPressed,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String word,
    required DictionaryService dictionaryService,
    required BookmarkService bookmarkService,
    required String bookId,
    VoidCallback? onBookmarkPressed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TranslationBottomSheet(
        word: word,
        dictionaryService: dictionaryService,
        bookmarkService: bookmarkService,
        bookId: bookId,
        onBookmarkPressed: onBookmarkPressed,
      ),
    );
  }

  @override
  State<TranslationBottomSheet> createState() => _TranslationBottomSheetState();
}

class _TranslationBottomSheetState extends State<TranslationBottomSheet> {
  bool _isLoading = true;
  List<DictionaryEntry> _entries = [];
  String? _error;
  String _selectedDictionary = 'rus-eng';
  bool _isBookmarked = false;
  bool _useOnlineTranslation = false;
  String? _onlineTranslation;
  List<String>? _fuzzyMatches;

  final Map<String, String> _availableDictionaries = {
    'Русский → English': 'rus-eng',
    'English → Русский': 'eng-rus',
    'Italiano → Русский': 'ita-rus',
    'Русский → Italiano': 'rus-ita',
    'English → Italiano': 'eng-ita',
    'Italiano → English': 'ita-eng',
  };

  // Language codes for online translation
  final Map<String, Map<String, String>> _langCodes = {
    'rus-eng': {'source': 'ru', 'target': 'en'},
    'eng-rus': {'source': 'en', 'target': 'ru'},
    'ita-rus': {'source': 'it', 'target': 'ru'},
    'rus-ita': {'source': 'ru', 'target': 'it'},
    'eng-ita': {'source': 'en', 'target': 'it'},
    'ita-eng': {'source': 'it', 'target': 'en'},
  };

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDict = prefs.getString('lastDictionary') ?? 'rus-eng';
    _selectedDictionary = lastDict;
    _useOnlineTranslation = prefs.getBool('useOnlineTranslation') ?? false;

    await _checkIfBookmarked();
    try {
      await widget.dictionaryService.loadDictionary(_selectedDictionary);
      await _loadTranslation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading dictionary: $e';
      });
    }
  }

  Future<void> _checkIfBookmarked() async {
    final existing = await widget.bookmarkService.findBookmark(
      widget.bookId,
      widget.word.toLowerCase(),
    );

    if (mounted) {
      setState(() {
        _isBookmarked = existing != null;
      });
    }
  }

  Future<void> _addBookmark() async {
    try {
      final translation = _onlineTranslation ??
          (_entries.isNotEmpty ? _entries.first.definition : null);

      await widget.bookmarkService.createBookmark(
        bookId: widget.bookId,
        bookTitle: '',
        type: BookmarkType.word,
        text: widget.word,
        context: translation,
        translation: translation,
        sectionIndex: 0,
        pageIndex: 0,
      );

      if (mounted) {
        setState(() {
          _isBookmarked = true;
        });
      }

      widget.onBookmarkPressed?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${widget.word}" added to bookmarks'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add bookmark: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadTranslation() async {

    setState(() {
      _isLoading = true;
      _error = null;
      _onlineTranslation = null;
      _fuzzyMatches = null;
    });

    try {
      if (_useOnlineTranslation) {
        await _fetchOnlineTranslation();

        if (mounted) {
          setState(() {
            _entries = [];
            _isLoading = false;
            if (_onlineTranslation == null) {
              _error = 'Online translation failed';
            }
          });
        }
        return;
      }

      final entries = await widget.dictionaryService.lookupWord(widget.word);

      if (entries.isEmpty) {
        await _performFuzzySearch();
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
          if (entries.isEmpty && _fuzzyMatches == null) {
            _error = 'Translation is not found';
          }
        });
      }
    } catch (e) {
      print('❌ Error in _loadTranslation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  Future<void> _performFuzzySearch() async {
    try {
      // Use the built-in method from DictionaryService
      final matches = await widget.dictionaryService.getFuzzyMatches(
        widget.word,
        limit: 5,
        threshold: 0.6,
      );

      if (mounted && matches.isNotEmpty) {
        setState(() {
          _fuzzyMatches = matches;
        });
      }
    } catch (e) {
      print('Fuzzy search error: $e');
    }
  }

  Future<void> _fetchOnlineTranslation() async {
    final langCodes = _langCodes[_selectedDictionary];
    if (langCodes == null) {
      print('❌ No language codes for: $_selectedDictionary');
      return;
    }

    String? translation;

    translation = await _tryMyMemoryTranslation(langCodes);

    if (translation == null) {
      print('🌐 MyMemory failed, trying Lingva...');
      translation = await _tryLingvaTranslation(langCodes);
    }

    if (mounted && translation != null) {
      setState(() {
        _onlineTranslation = translation;
      });
    } else {
      print('❌ No translation obtained or widget not mounted');
    }
  }

  Future<String?> _tryMyMemoryTranslation(Map<String, String> langCodes) async {
    try {
      final source = langCodes['source']!;
      final target = langCodes['target']!;

      final url = Uri.parse(
          'https://api.mymemory.translated.net/get'
              '?q=${Uri.encodeComponent(widget.word)}'
              '&langpair=$source|$target'
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['responseStatus'] == 200 || data['responseData'] != null) {
          final translated = data['responseData']['translatedText'];
          return translated;
        }
      }
    } catch (e) {
      print('❌ MyMemory translation error: $e');
    }
    return null;
  }

  Future<String?> _tryLingvaTranslation(Map<String, String> langCodes) async {
    try {
      final source = langCodes['source']!;
      final target = langCodes['target']!;

      final url = Uri.parse(
          'https://lingva.ml/api/v1/$source/$target/${Uri.encodeComponent(widget.word)}'
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['translation'];
        return translated;
      }
    } catch (e) {
      print('❌ Lingva translation error: $e');
    }
    return null;
  }

  Future<void> _changeDictionary(String newDict) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDictionary', newDict);

    setState(() {
      _selectedDictionary = newDict;
      _isLoading = true;
    });

    await widget.dictionaryService.loadDictionary(newDict);
    await _loadTranslation();
  }

  Future<void> _toggleOnlineTranslation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useOnlineTranslation', value);

    setState(() {
      _useOnlineTranslation = value;
    });

    if (value && _entries.isEmpty && _onlineTranslation == null) {
      setState(() => _isLoading = true);
      await _fetchOnlineTranslation();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.word,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isBookmarked)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.bookmark,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _selectedDictionary,
                            isExpanded: true,
                            items: _availableDictionaries.entries
                                .map((e) => DropdownMenuItem<String>(
                              value: e.value,
                              child: Text(e.key),
                            ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) _changeDictionary(value);
                            },
                          ),
                          Row(
                            children: [
                              Switch(
                                value: _useOnlineTranslation,
                                onChanged: _toggleOnlineTranslation,
                              ),
                              const Text('Online translation'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
                        color: _isBookmarked ? Colors.blue : null,
                      ),
                      onPressed: _addBookmark,
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildContent(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (_entries.isNotEmpty) ...[
          const Text(
            'Dictionary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._entries.map((entry) => Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(entry.definition, style: const TextStyle(fontSize: 16)),
            ),
          )),
        ],

        if (_onlineTranslation != null) ...[
          const Text(
            'Online Translation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_onlineTranslation!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Powered by MyMemory/Lingva',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (_fuzzyMatches != null && _fuzzyMatches!.isNotEmpty) ...[
          const Text(
            'Did you mean?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fuzzyMatches!.map((match) => ActionChip(
              label: Text(match),
              onPressed: () async {
                final entries = await widget.dictionaryService.lookupWord(match);
                if (mounted) {
                  setState(() {
                    _entries = entries;
                    _fuzzyMatches = null;
                  });
                }
              },
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],

        if (_entries.isEmpty && _onlineTranslation == null && _fuzzyMatches == null)
          Center(
            child: Text(_error ?? 'Translation is not found',
                style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}