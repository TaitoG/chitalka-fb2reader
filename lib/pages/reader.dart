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
  // Constants
  static const double _lineHeight = 1.4;
  static const TextStyle _pageInfoStyle = TextStyle(color: Colors.grey, fontSize: 12);
  static const EdgeInsets _contentPadding = EdgeInsets.symmetric(horizontal: 24.0);

  // UI State
  int _currentSectionIndex = 0;
  int _currentPageIndex = 0;
  double _fontSize = 18.0;
  bool _isInitialized = false;
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
  double? _measuredTextHeight;

  int _estimatedTotalPages = 0;
  Timer? _paginationDebounce;

  final Map<int, TapGestureRecognizer> _gestureRecognizers = {};

  @override
  void initState() {
    super.initState();

    if (widget.metadata?.lastPosition != null) {
      _currentSectionIndex = widget.metadata!.lastPosition! ~/ 1000;
      _currentPageIndex = widget.metadata!.lastPosition! % 1000;
    }

    _paginationService = PaginationService();
    _paginationService.addListener(_onPaginationUpdate);

    _dictionaryService = DictionaryService();
    _bookmarkService = BookmarkService();
  }

  void _onPaginationUpdate() {
    if (mounted) setState(() {});
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

  void _cleanupRecognizers() {
    for (final r in _gestureRecognizers.values) {
      r.dispose();
    }
    _gestureRecognizers.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadBookmarkedWords();
      _isInitialized = true;
    }
  }

  Future<void> _loadPaginationWithMeasuredHeight(double textHeight) async {
    if (_measuredTextHeight == textHeight) return;

    _paginationDebounce?.cancel();
    _paginationDebounce = Timer(const Duration(milliseconds: 50), () async {
      _measuredTextHeight = textHeight;

      final size = MediaQuery.of(context).size;

      // Запускаем пагинацию текущей секции
      _paginationService.paginateSection(
        book: widget.book,
        sectionIndex: _currentSectionIndex,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        screenSize: size,
        textContainerHeight: textHeight,
      );

      // Предзагружаем соседние секции
      _preloadAdjacentSections(size, textHeight);

      // Оцениваем общее количество страниц
      if (_estimatedTotalPages == 0) {
        final estimated = await _paginationService.estimateTotalPages(
          book: widget.book,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          availableWidth: size.width - _contentPadding.horizontal,
          availableHeight: textHeight,
        );
        if (mounted) {
          setState(() => _estimatedTotalPages = estimated);
        }
      }
    });
  }

  void _preloadAdjacentSections(Size size, double textHeight) {
    for (int i = 1; i <= 2; i++) {
      if (_currentSectionIndex - i >= 0) {
        _paginationService.paginateSection(
          book: widget.book,
          sectionIndex: _currentSectionIndex - i,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          screenSize: size,
          textContainerHeight: textHeight,
        ).catchError((e) => print('Preload error: $e'));
      }
      if (_currentSectionIndex + i < widget.book.sections.length) {
        _paginationService.paginateSection(
          book: widget.book,
          sectionIndex: _currentSectionIndex + i,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          screenSize: size,
          textContainerHeight: textHeight,
        ).catchError((e) => print('Preload error: $e'));
      }
    }
  }

  @override
  void dispose() {
    _savePosition();
    _paginationService.removeListener(_onPaginationUpdate);
    _paginationService.dispose();
    _paginationDebounce?.cancel();
    _cleanupRecognizers();
    super.dispose();
  }

  Future<void> _savePosition() async {
    if (widget.metadata != null) {
      widget.metadata!.lastPosition = _currentSectionIndex * 1000 + _currentPageIndex;
      await widget.metadata!.save();
    }
  }

  BookSection get _currentSection => widget.book.sections[_currentSectionIndex];
  List<PageData> get _currentPages => _paginationService.getSectionPages(_currentSectionIndex);

  bool get _hasNextPage =>
      _currentPageIndex < _currentPages.length - 1 ||
          _currentSectionIndex < widget.book.sections.length - 1;
  bool get _hasPrevPage => _currentPageIndex > 0 || _currentSectionIndex > 0;

  Future<void> _nextPage() async {
    final currentPages = _currentPages;

    if (_currentPageIndex < currentPages.length - 1) {
      setState(() {
        _currentPageIndex++;
        _resetSelectionState();
      });
    } else if (_currentSectionIndex < widget.book.sections.length - 1) {
      final nextSectionIndex = _currentSectionIndex + 1;

      setState(() {
        _currentSectionIndex = nextSectionIndex;
        _currentPageIndex = 0;
        _resetSelectionState();
      });

      if (_measuredTextHeight != null && !_paginationService.isSectionReady(nextSectionIndex)) {
        final size = MediaQuery.of(context).size;
        _paginationService.paginateSection(
          book: widget.book,
          sectionIndex: nextSectionIndex,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          screenSize: size,
          textContainerHeight: _measuredTextHeight!,
        );
        _preloadAdjacentSections(size, _measuredTextHeight!);
      }
    }
    _savePosition();
  }

  Future<void> _prevPage() async {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
        _resetSelectionState();
      });
    } else if (_currentSectionIndex > 0) {
      final prevSectionIndex = _currentSectionIndex - 1;

      if (_measuredTextHeight != null && !_paginationService.isSectionReady(prevSectionIndex)) {
        final size = MediaQuery.of(context).size;
        _paginationService.paginateSection(
          book: widget.book,
          sectionIndex: prevSectionIndex,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          screenSize: size,
          textContainerHeight: _measuredTextHeight!,
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));

      final pages = _paginationService.getSectionPages(prevSectionIndex);

      setState(() {
        _currentSectionIndex = prevSectionIndex;
        _currentPageIndex = pages.isEmpty ? 0 : pages.length - 1;
        _resetSelectionState();
      });

      if (_measuredTextHeight != null) {
        final size = MediaQuery.of(context).size;
        _preloadAdjacentSections(size, _measuredTextHeight!);
      }
    }
    _savePosition();
  }

  void _resetSelectionState() {
    _selectedWord = null;
    _selectedWordIndex = null;
    _invalidateCache();
  }

  void _resetSelection() {
    setState(() {
      _resetSelectionState();
    });
  }

  void _onWordTap(String word, int index) {
    setState(() {
      if (_selectedWordIndex == index) {
        _resetSelectionState();
      } else {
        _selectedWord = word;
        _selectedWordIndex = index;
        _invalidateCache();
      }
    });
    if (_selectedWord != null) _showTranslation(word);
  }

  void _showTranslation(String word) {
    final clean = word.replaceAll(RegExp(r'[^\wа-яА-ЯёЁ]'), '').toLowerCase();
    if (clean.isEmpty) return;

    TranslationBottomSheet.show(
      context: context,
      word: clean,
      dictionaryService: _dictionaryService,
      bookmarkService: _bookmarkService,
      bookId: widget.metadata?.filePath ?? widget.book.title,
      onBookmarkPressed: _loadBookmarkedWords,
    ).then((_) => _resetSelection());
  }

  void _handleTap(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;

    if (_selectedWordIndex != null) {
      _resetSelection();
      return;
    }

    if (x < width * 0.3 && _hasPrevPage) {
      _prevPage();
    } else if (x > width * 0.7 && _hasNextPage) {
      _nextPage();
    } else {
      setState(() => _showAppBar = !_showAppBar);
    }
  }

  List<InlineSpan> _buildTextSpans(PageData page) {
    final hash = Object.hash(
        _currentSectionIndex,
        _currentPageIndex,
        _selectedWordIndex,
        _bookmarkedWords.length
    );

    if (_cachedTextSpans != null && _cachedPageHash == hash) {
      return _cachedTextSpans!;
    }

    final spans = <InlineSpan>[];
    final tokens = page.tokens;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final isSelected = _selectedWordIndex == i;
      final isBookmarked = _bookmarkedWords.contains(token.word.toLowerCase());

      final recognizer = _gestureRecognizers.putIfAbsent(
          i,
              () => TapGestureRecognizer()
      )..onTap = () => _onWordTap(token.word, i);

      spans.add(TextSpan(
        text: token.text,
        style: TextStyle(
          backgroundColor: isSelected ? Colors.yellow.withOpacity(0.5) : null,
          decoration: isBookmarked ? TextDecoration.underline : null,
          decorationColor: isBookmarked ? Colors.blue.withOpacity(0.5) : null,
          decorationStyle: isBookmarked ? TextDecorationStyle.dotted : null,
        ),
        recognizer: recognizer,
      ));
    }

    _cachedTextSpans = spans;
    _cachedPageHash = hash;
    return spans;
  }

  void _showFontSizeDialog() {
    double temp = _fontSize;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Font size'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${temp.toInt()} pt'),
              Slider(
                min: 14, max: 28, divisions: 14,
                value: temp,
                onChanged: (v) => setDialogState(() => temp = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _fontSize = temp;
                _measuredTextHeight = null;
                _paginationService.clear();
                _estimatedTotalPages = 0;
                _invalidateCache();
                _cleanupRecognizers();
              });
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    const appBarHeight = kToolbarHeight;

    const bottomInfoHeight = 32.0;

    const verticalPadding = 16.0;

    final totalUsedHeight = topPadding + appBarHeight + verticalPadding + bottomInfoHeight + verticalPadding + bottomPadding;
    final availableTextHeight = screenHeight - totalUsedHeight;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _handleTap,
        child: Stack(
          children: [
            Container(color: Colors.white),

            Padding(
              padding: EdgeInsets.only(
                top: topPadding + appBarHeight + verticalPadding,
                left: _contentPadding.left,
                right: _contentPadding.right,
                bottom: bottomPadding + verticalPadding,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: availableTextHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textHeight = constraints.maxHeight - bottomInfoHeight;

                        if (_measuredTextHeight != textHeight) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _loadPaginationWithMeasuredHeight(textHeight);
                          });
                        }

                        final currentPages = _currentPages;
                        final isPaginating = _paginationService.isSectionPaginating(_currentSectionIndex);
                        final currentPageCount = _paginationService.getSectionPageCount(_currentSectionIndex);

                        Widget content;

                        if (currentPages.isEmpty && isPaginating) {
                          content = const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading pages...', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        } else if (currentPages.isEmpty) {
                          content = SingleChildScrollView(
                            child: Text(
                              _currentSection.paragraphs.join('\n\n'),
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: _lineHeight,
                                color: Colors.black,
                              ),
                            ),
                          );
                        } else {
                          final pageIndex = _currentPageIndex.clamp(0, currentPages.length - 1);
                          content = Align(
                            alignment: Alignment.topLeft,
                            child: RichText(
                              textAlign: TextAlign.justify,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: _fontSize,
                                  height: _lineHeight,
                                  color: Colors.black,
                                ),
                                children: _buildTextSpans(currentPages[pageIndex]),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            SizedBox(
                              height: textHeight,
                              child: content,
                            ),

                            SizedBox(
                              height: bottomInfoHeight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Section ${_currentSectionIndex + 1}/${widget.book.sections.length}',
                                    style: _pageInfoStyle,
                                  ),
                                  Text(
                                    isPaginating && currentPageCount > 0
                                        ? 'Page ${_currentPageIndex + 1}/$currentPageCount+ (loading...)'
                                        : currentPages.isNotEmpty
                                        ? 'Page ${_currentPageIndex + 1}/${currentPages.length}'
                                        : 'Page ${_currentPageIndex + 1}/~$_estimatedTotalPages',
                                    style: _pageInfoStyle,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // AppBar
            if (_showAppBar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: appBarHeight + topPadding,
                  color: Theme.of(context).colorScheme.inversePrimary,
                  child: AppBar(
                    title: Text(widget.book.title),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.text_fields),
                        tooltip: 'Font size',
                        onPressed: _showFontSizeDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmarks),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookmarksPage(bookmarkService: _bookmarkService),
                            ),
                          );
                          await _loadBookmarkedWords();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}