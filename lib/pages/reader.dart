// pages/reader/reader.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/models/page_data.dart';
import 'package:chitalka/services/pagination.dart';
import 'package:chitalka/services/dictionary.dart';
import 'package:chitalka/widgets/translation.dart';

class ReaderPage extends StatefulWidget {
  final Book book;
  final BookMetadata? metadata;

  const ReaderPage({
    Key? key,
    required this.book,
    this.metadata,
  }) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  // UI State
  int _currentSectionIndex = 0;
  int _currentPageIndex = 0;
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  bool _isInitialized = false;
  String? _selectedWord;
  int? _selectedWordIndex;

  // Services
  late final PaginationService _paginationService;
  late final DictionaryService _dictionaryService;

  @override
  void initState() {
    super.initState();

    // Загружаем последнюю позицию
    if (widget.metadata?.lastPosition != null) {
      _currentSectionIndex = widget.metadata!.lastPosition! ~/ 1000;
      _currentPageIndex = widget.metadata!.lastPosition! % 1000;
    }

    // Инициализируем сервисы
    _paginationService = PaginationService();
    _paginationService.onPaginationUpdate = () {
      if (mounted) setState(() {});
    };
    _paginationService.onBackgroundPaginationComplete = () {
      if (mounted) setState(() {});
    };

    _dictionaryService = DictionaryService();

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _paginationService.initializeCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadOrCreatePagination();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _savePosition();
    _paginationService.dispose();
    super.dispose();
  }

  Future<void> _savePosition() async {
    if (widget.metadata != null) {
      widget.metadata!.lastPosition =
          _currentSectionIndex * 1000 + _currentPageIndex;
      await widget.metadata!.save();
    }
  }

  Future<void> _loadOrCreatePagination() async {
    final size = MediaQuery.of(context).size;
    final cacheKey = widget.metadata?.filePath;

    await _paginationService.loadOrCreatePagination(
      book: widget.book,
      cacheKey: cacheKey,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      screenSize: size,
      currentSectionIndex: _currentSectionIndex,
    );
  }

  // Геттеры для текущего состояния
  BookSection get _currentSection => widget.book.sections[_currentSectionIndex];

  List<PageData> get _currentPages =>
      _paginationService.getSectionPages(_currentSectionIndex);

  bool get _hasNextPage {
    return _currentPageIndex < _currentPages.length - 1 ||
        _currentSectionIndex < widget.book.sections.length - 1;
  }

  bool get _hasPrevPage {
    return _currentPageIndex > 0 || _currentSectionIndex > 0;
  }

  // Навигация
  void _nextPage() {
    setState(() {
      if (_currentPageIndex < _currentPages.length - 1) {
        _currentPageIndex++;
      } else if (_currentSectionIndex < widget.book.sections.length - 1) {
        _currentSectionIndex++;
        _currentPageIndex = 0;
        _ensureSectionLoaded(_currentSectionIndex);
        _paginationService.preloadNearbySections(
          _currentSectionIndex,
          widget.book.sections.length,
        );
      }
      _selectedWord = null;
      _selectedWordIndex = null;
      _savePosition();
    });
  }

  void _prevPage() {
    setState(() {
      if (_currentPageIndex > 0) {
        _currentPageIndex--;
      } else if (_currentSectionIndex > 0) {
        _currentSectionIndex--;
        _ensureSectionLoaded(_currentSectionIndex);
        final pages = _currentPages;
        _currentPageIndex = pages.isEmpty ? 0 : pages.length - 1;
        _paginationService.preloadNearbySections(
          _currentSectionIndex,
          widget.book.sections.length,
        );
      }
      _selectedWord = null;
      _selectedWordIndex = null;
      _savePosition();
    });
  }

  void _ensureSectionLoaded(int sectionIndex) {
    if (!_paginationService.isSectionLoaded(sectionIndex)) {
      _paginationService.loadSectionFromCache(sectionIndex);
    }
  }

  // Обработка тапа по слову
  void _onWordTap(String word, int index) {
    setState(() {
      if (_selectedWordIndex == index) {
        // Если слово уже выделено, снимаем выделение
        _selectedWord = null;
        _selectedWordIndex = null;
      } else {
        // Выделяем новое слово и показываем перевод
        _selectedWord = word;
        _selectedWordIndex = index;
        _showTranslation(word);
      }
    });
  }

  void _showTranslation(String word) {
    // Убираем знаки пунктуации и приводим к нижнему регистру
    final cleanWord = word
        .replaceAll(RegExp(r'[^\wа-яА-ЯёЁ]'), '')
        .toLowerCase();

    if (cleanWord.isEmpty) return;

    TranslationBottomSheet.show(
      context,
      cleanWord,
      _dictionaryService,
    ).then((_) {
      // Снимаем выделение после закрытия bottom sheet
      if (mounted) {
        setState(() {
          _selectedWord = null;
          _selectedWordIndex = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPages = _currentPages;

    if (currentPages.isEmpty || currentPages.first.text.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.book.title),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentPage = currentPages[_currentPageIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_paginationService.isBackgroundPaginationRunning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        onTapUp: (details) {
          if (_selectedWordIndex == null) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 2) {
              if (_hasPrevPage) _prevPage();
            } else {
              if (_hasNextPage) _nextPage();
            }
          }
        },
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок секции
              if (_currentSection.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _currentSection.title,
                    style: TextStyle(
                      fontSize: _fontSize + 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Текст с токенами
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: _lineHeight,
                        color: Colors.black,
                      ),
                      children: currentPage.tokens.asMap().entries.map((entry) {
                        final index = entry.key;
                        final token = entry.value;
                        final isSelected = _selectedWordIndex == index;

                        return TextSpan(
                          text: token.text,
                          style: TextStyle(
                            backgroundColor: isSelected
                                ? Colors.yellow.withOpacity(0.5)
                                : null,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _onWordTap(token.word, index),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // Футер с номерами страниц
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Раздел ${_currentSectionIndex + 1}/${widget.book.sections.length}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      'Страница ${_currentPageIndex + 1}/${currentPages.length}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}