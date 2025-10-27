// reader.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/models/page_data.dart';
import 'package:chitalka/services/pagination.dart';
import 'package:chitalka/services/dictionary.dart';
import 'package:chitalka/services/bookmark_service.dart';
import 'package:chitalka/widgets/translation.dart';
import 'package:chitalka/pages/bookmark_page.dart';

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
  double _lineHeight = 1.4;
  bool _isInitialized = false;
  String? _selectedWord;
  int? _selectedWordIndex;
  bool _showAppBar = true;

  // Services
  late final PaginationService _paginationService;
  late final DictionaryService _dictionaryService;
  late final BookmarkService _bookmarkService;

  Set<String> _bookmarkedWords = {};

  @override
  void initState() {
    super.initState();

    if (widget.metadata?.lastPosition != null) {
      _currentSectionIndex = widget.metadata!.lastPosition! ~/ 1000;
      _currentPageIndex = widget.metadata!.lastPosition! % 1000;
    }

    _paginationService = PaginationService();
    _paginationService.onPaginationUpdate = () {
      if (mounted) setState(() {});
    };
    _paginationService.onBackgroundPaginationComplete = () {
      if (mounted) setState(() {});
    };

    _dictionaryService = DictionaryService();
    _bookmarkService = BookmarkService();

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _paginationService.initializeCache();
    await _bookmarkService.initialize();
    await _loadBookmarkedWords();
  }

  Future<void> _loadBookmarkedWords() async {
    final bookId = widget.metadata?.filePath ?? widget.book.title;
    final bookmarks = await _bookmarkService.getBookmarksByBook(bookId);
    setState(() {
      _bookmarkedWords = bookmarks.map((b) => b.text.toLowerCase()).toSet();
    });
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

  void _onWordTap(String word, int index) async {
    setState(() {
      if (_selectedWordIndex == index) {
        _selectedWord = null;
        _selectedWordIndex = null;
      } else {
        _selectedWord = word;
        _selectedWordIndex = index;
      }
    });

    if (_selectedWord != null) {
      _showTranslation(word);
    }
  }

  void _showTranslation(String word) {
    final cleanWord = word
        .replaceAll(RegExp(r'[^\wа-яА-ЯёЁ]'), '')
        .toLowerCase();

    if (cleanWord.isEmpty) return;

    TranslationBottomSheet.show(
      context: context,
      word: cleanWord,
      dictionaryService: _dictionaryService,
      bookmarkService: _bookmarkService,
      bookId: widget.metadata?.filePath ?? widget.book.title,
      onBookmarkPressed: () {
        _loadBookmarkedWords();
        setState(() {});
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedWord = null;
          _selectedWordIndex = null;
        });
      }
    });
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (_selectedWordIndex != null) {
      setState(() {
        _selectedWord = null;
        _selectedWordIndex = null;
      });
      return;
    }

    final leftPart = screenWidth * 0.3;
    final rightPart = screenWidth * 0.7;

    if (tapX < leftPart) {
      if (_hasPrevPage) _prevPage();
    } else if (tapX > rightPart) {
      if (_hasNextPage) _nextPage();
    } else {
      setState(() {
        _showAppBar = !_showAppBar;
      });
    }
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
      body: Stack(
        children: [
          GestureDetector(
            onTapUp: _handleTap,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*if (_currentSection.title.isNotEmpty && _currentPageIndex == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _currentSection.title,
                        style: TextStyle(
                          fontSize: _fontSize + 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),*/

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
                            final isBookmarked = _bookmarkedWords.contains(
                              token.word.toLowerCase(),
                            );

                            return TextSpan(
                              text: token.text,
                              style: TextStyle(
                                backgroundColor: isSelected
                                    ? Colors.yellow.withOpacity(0.5)
                                    : isBookmarked
                                    ? Colors.blue.withOpacity(0.1)
                                    : null,
                                decoration: isBookmarked
                                    ? TextDecoration.underline
                                    : null,
                                decorationColor: Colors.blue.withOpacity(0.5),
                                decorationStyle: TextDecorationStyle.dotted,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _onWordTap(token.word, index),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Section ${_currentSectionIndex + 1}/${widget.book.sections.length}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          'Page ${_currentPageIndex + 1}/${currentPages.length}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showAppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: kToolbarHeight + MediaQuery.of(context).padding.top,
                color: Theme.of(context).colorScheme.inversePrimary,
                child: AppBar(
                  title: Text(widget.book.title),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.bookmarks),
                      tooltip: 'View bookmarks',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookmarksPage(
                              bookmarkService: _bookmarkService,
                            ),
                          ),
                        );
                        await _loadBookmarkedWords();
                        setState(() {});
                      },
                    ),
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
              ),
            ),
        ],
      ),
    );
  }
}