//translation.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chitalka/services/dictionary.dart';

class TranslationBottomSheet extends StatefulWidget {
  final String word;
  final DictionaryService dictionaryService;

  const TranslationBottomSheet({
    Key? key,
    required this.word,
    required this.dictionaryService,
  }) : super(key: key);

  static Future<void> show(
      BuildContext context,
      String word,
      DictionaryService dictionaryService,
      ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TranslationBottomSheet(
        word: word,
        dictionaryService: dictionaryService,
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

  final Map<String, String> _availableDictionaries = {
    'Русский → Английский': 'rus-eng',
    'Английский → Русский': 'eng-rus',
    'Итальянский → Русский': 'ita-rus',
    'Русский → Итальянский': 'rus-ita',
    'Английский → Итальянский': 'eng-ita',
    'Итальянский → Английский': 'ita-eng',
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

    try {
      await widget.dictionaryService.loadDictionary(_selectedDictionary);
      await _loadTranslation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки словаря: $e';
      });
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
          if (entries.isEmpty) _error = 'Перевод не найден';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Ошибка: $e';
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
                          Text(
                            widget.word,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
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
            Text('Загрузка перевода...'),
          ],
        ),
      );
    }

    if (_error != null || _entries.isEmpty) {
      return Center(
        child: Text(_error ?? 'Перевод не найден', style: const TextStyle(fontSize: 16)),
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
