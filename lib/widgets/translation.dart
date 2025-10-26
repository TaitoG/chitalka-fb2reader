import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chitalka/services/dictionary.dart';
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

  final Map<String, String> _availableDictionaries = {
    'Русский → English': 'rus-eng',
    'English → Русский': 'eng-rus',
    'Italiano → Русский': 'ita-rus',
    'Русский → Italiano': 'rus-ita',
    'English → Italiano': 'eng-ita',
    'Italiano → English': 'ita-eng',
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
      await widget.bookmarkService.createBookmark(
        bookId: widget.bookId,
        bookTitle: '',
        type: BookmarkType.word,
        text: widget.word,
        context: _entries.isNotEmpty ? _entries.first.definition : null,
        translation: _entries.isNotEmpty ? _entries.first.definition : null,
        sectionIndex: 0,
        pageIndex: 0,
      );

      if (mounted) {
        setState(() {
          _isBookmarked = true;
        });
      }

      widget.onBookmarkPressed?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.word}" added to bookmarks'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add bookmark: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadTranslation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await widget.dictionaryService.lookupWord(widget.word);
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
          if (entries.isEmpty) _error = 'Translation is not found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
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
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
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

    if (_error != null || _entries.isEmpty) {
      return Center(
        child: Text(_error ?? 'Translation is not found', style: const TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(entry.definition, style: const TextStyle(fontSize: 16)),
          ),
        );
      },
    );
  }
}