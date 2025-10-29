// reader.dart
import 'dart:async';
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
  static const double _fontSize = 18.0;
  static const double _lineHeight = 1.4;
  bool _isInitialized = false;
  bool _servicesInitialized = false;
  String? _selectedWord;
  int? _selectedWordIndex;
  bool _showAppBar = true;

  // Services
  late final PaginationService _paginationService;
  late final DictionaryService _dictionaryService;
  late final BookmarkService _bookmarkService;

  Set<String> _bookmarkedWords = {};

  List<InlineSpan>? _cachedTextSpans;
  int? _cachedPageHash;

  final GlobalKey _textContainerKey = GlobalKey();

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();

    if (widget.metadata?.lastPosition != null) {
      _currentSectionIndex = widget.metadata!.lastPosition! ~/ 1000;
      _currentPageIndex = widget.metadata!.lastPosition! % 1000;
    }

    _paginationService = PaginationService();
    _paginationService.onPaginationUpdate = _handlePaginationUpdate;
    _paginationService.onBackgroundPaginationComplete = _handleBackgroundComplete;

    _dictionaryService = DictionaryService();
    _bookmarkService = BookmarkService();

  }

  void _handlePaginationUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _invalidateCache();
        });
      }
    });
  }

  void _handleBackgroundComplete() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    if (_servicesInitialized) {
      print('⚠️ Services already initialized, skipping...');
      return;
    }

    print('🔧 Initializing services...');

    await _paginationService.initializeCache();
    print('✅ Pagination service initialized');

    await _loadBookmarkedWords();
    print('✅ Bookmarks loaded');

    _servicesInitialized = true;
  }

  Future<void> _loadBookmarkedWords() async {
    final bookId = widget.metadata?.filePath ?? widget.book.title;
    final bookmarks = await _bookmarkService.getBookmarksByBook(bookId);
    if (mounted) {
      setState(() {
        _bookmarkedWords = bookmarks.map((b) => b.text.toLowerCase()).toSet();
        _invalidateCache();
      });
    }
  }

  void _invalidateCache() {
    _cachedTextSpans = null;
    _cachedPageHash = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeAndLoadPagination();
      _isInitialized = true;
    }
  }

  Future<void> _initializeAndLoadPagination() async {
    await _initializeServices();

    await _loadOrCreatePagination();
  }

  Future<void> _waitAndLoadPagination() async {
    while (_paginationService.currentCache == null &&
        !await _isPaginationServiceReady()) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _loadOrCreatePagination();
  }

  Future<bool> _isPaginationServiceReady() async {
    try {
      await _paginationService.initializeCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
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

  double _getTextContainerHeight() {
    final renderBox = _textContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.size.height;
    }

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    const additionalTopPadding = 16.0;
    const bottomInfoHeight = 16.0 + 20.0;

    return mediaQuery.size.height -
        topPadding -
        24.0 -
        additionalTopPadding -
        48.0 -
        bottomInfoHeight;
  }

  Future<void> _loadOrCreatePagination() async {
    final size = MediaQuery.of(context).size;
    final cacheKey = widget.metadata?.filePath;
    final textHeight = _getTextContainerHeight();

    await _paginationService.loadOrCreatePagination(
      book: widget.book,
      cacheKey: cacheKey,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      screenSize: size,
      textContainerHeight: textHeight,
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
    _invalidateCache();
    _savePosition();
    setState(() {});
  }

  void _prevPage() {
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
    _invalidateCache();
    _savePosition();
    setState(() {});
  }

  void _ensureSectionLoaded(int sectionIndex) {
    if (!_paginationService.isSectionLoaded(sectionIndex)) {
      _paginationService.loadSectionFromCache(sectionIndex);
    }
  }

  void _onWordTap(String word, int index) {
    if (_selectedWordIndex == index) {
      setState(() {
        _selectedWord = null;
        _selectedWordIndex = null;
        _invalidateCache();
      });
    } else {
      setState(() {
        _selectedWord = word;
        _selectedWordIndex = index;
        _invalidateCache();
      });
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
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedWord = null;
          _selectedWordIndex = null;
          _invalidateCache();
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
        _invalidateCache();
      });
      return;
    }

    const leftPart = 0.3;
    const rightPart = 0.7;

    if (tapX < screenWidth * leftPart) {
      if (_hasPrevPage) _prevPage();
    } else if (tapX > screenWidth * rightPart) {
      if (_hasNextPage) _nextPage();
    } else {
      setState(() {
        _showAppBar = !_showAppBar;
      });
    }
  }

  List<InlineSpan> _buildTextSpans(PageData currentPage) {
    final pageHash = Object.hash(
      _currentSectionIndex,
      _currentPageIndex,
      _selectedWordIndex,
      _bookmarkedWords.length,
    );

    if (_cachedTextSpans != null && _cachedPageHash == pageHash) {
      return _cachedTextSpans!;
    }

    final spans = List<InlineSpan>.generate(
      currentPage.tokens.length,
          (index) {
        final token = currentPage.tokens[index];
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
            decoration: isBookmarked ? TextDecoration.underline : null,
            decorationColor: Colors.blue.withOpacity(0.5),
            decorationStyle: TextDecorationStyle.dotted,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _onWordTap(token.word, index),
        );
      },
    );

    _cachedTextSpans = spans;
    _cachedPageHash = pageHash;

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final currentPages = _currentPages;

    if (currentPages.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.book.title),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentPage = currentPages[_currentPageIndex.clamp(0, currentPages.length - 1)];
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    const additionalTopPadding = 16.0;

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTapUp: _handleTap,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top: topPadding + 24.0 + additionalTopPadding,
                left: 24.0,
                right: 24.0,
                bottom: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RepaintBoundary(
                      child: Container(
                        key: _textContainerKey,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: RichText(
                            textAlign: TextAlign.justify,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: _fontSize,
                                height: _lineHeight,
                                color: Colors.black,
                              ),
                              children: _buildTextSpans(currentPage),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
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
                height: kToolbarHeight + topPadding,
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