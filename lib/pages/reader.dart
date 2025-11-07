// pages/reader.dart
import 'package:flutter/material.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/services/custom_renderer.dart';
import 'package:chitalka/services/dictionary.dart';
import 'package:chitalka/services/bookmark_service.dart';
import 'package:chitalka/widgets/translation.dart';
import '../models/layout.dart';
import '../themes/provider.dart';

class RenderObjectReaderPage extends StatefulWidget {
  final Book book;
  final BookMetadata? metadata;

  const RenderObjectReaderPage({
    Key? key,
    required this.book,
    this.metadata
  }) : super(key: key);

  @override
  State<RenderObjectReaderPage> createState() => _RenderObjectReaderPageState();
}

class _RenderObjectReaderPageState extends State<RenderObjectReaderPage> {
  static const double _lineHeight = 1.4;
  static const double _defaultFontSize = 18.0;
  static const EdgeInsets _contentPadding = EdgeInsets.symmetric(horizontal: 24.0);

  late final DictionaryService _dictionaryService;
  late final BookmarkService _bookmarkService;

  double _fontSize = _defaultFontSize;
  bool _showAppBar = true;
  double _scrollOffset = 0;

  final List<int> _sectionOffsets = [];
  final List<String> _sectionTitles = [];

  int? _selectedWordOffset;
  Set<String> _bookmarkedWords = {};

  late final String _fullText;

  final GlobalKey _renderKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _dictionaryService = DictionaryService();
    _bookmarkService = BookmarkService();

    final buffer = StringBuffer();
    int offset = 0;

    for (final section in widget.book.sections) {
      final headerText = '§${section.title}§\n';
      buffer.write(headerText);
      offset += headerText.length;

      _sectionOffsets.add(offset - headerText.length);
      _sectionTitles.add(section.title);

      for (final para in section.paragraphs) {
        buffer.write(para);
        buffer.write('\n\n');
        offset += para.length + 2;
      }
    }

    _fullText = buffer.toString();
    _loadBookmarkedWords();

    if (widget.metadata?.lastPosition != null) {
      _scrollOffset = widget.metadata!.lastPosition!.toDouble();
    }
  }

  String _getCurrentSectionTitle() {
    final renderObject = _renderObject;
    if (renderObject == null) return widget.book.sections.first.title;

    final visibleWord = _findFirstVisibleWord();
    if (visibleWord == null) return widget.book.sections.first.title;

    final wordOffset = visibleWord.documentOffset;

    for (int i = _sectionOffsets.length - 1; i >= 0; i--) {
      if (wordOffset >= _sectionOffsets[i]) {
        return _sectionTitles[i];
      }
    }

    return widget.book.sections.first.title;
  }

  LayoutWord? _findFirstVisibleWord() {
    final renderObject = _renderObject;
    if (renderObject == null) return null;

    for (final line in renderObject.lines) {
      final lineScreenY = line.y - _scrollOffset;

      if (lineScreenY >= 0 && lineScreenY < renderObject.size.height) {
        if (line.words.isNotEmpty) {
          return line.words.first;
        }
      }
    }

    return null;
  }

  Future<void> _loadBookmarkedWords() async {
    final bookId = widget.metadata?.filePath ?? widget.book.title;
    final bookmarks = await _bookmarkService.getBookmarksByBook(bookId);
    if (mounted) {
      setState(() {
        _bookmarkedWords = bookmarks.map((b) => b.text.toLowerCase()).toSet();
      });
    }
  }

  @override
  void dispose() {
    _savePosition();
    super.dispose();
  }

  Future<void> _savePosition() async {
    if (widget.metadata != null) {
      widget.metadata!.lastPosition = _scrollOffset.round();
      await widget.metadata!.save();
    }
  }

  RenderCustomText? get _renderObject {
    final context = _renderKey.currentContext;
    if (context == null) return null;
    return context.findRenderObject() as RenderCustomText?;
  }

  void _handleTap(TapUpDetails details, double viewportHeight) {
    final width = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;

    final renderBox = _renderKey.currentContext?.findRenderObject() as RenderBox?;
    final renderObject = _renderObject;

    if (renderBox != null && renderObject != null) {
      final localPos = renderBox.globalToLocal(details.globalPosition);

      if (localPos.dx >= 0 && localPos.dx <= renderBox.size.width &&
          localPos.dy >= 0 && localPos.dy <= renderBox.size.height) {

        final word = renderObject.findWordAt(localPos);

        if (word != null && word.cleanWord.isNotEmpty) {
          setState(() {
            if (_selectedWordOffset == word.documentOffset) {
              _selectedWordOffset = null;
            } else {
              _selectedWordOffset = word.documentOffset;
              _showTranslation(word.cleanWord);
            }
          });
          return;
        }
      }
    }

    if (_selectedWordOffset != null) {
      setState(() => _selectedWordOffset = null);
      return;
    }

    if (x < width * 0.3) {
      final newOffset = _getSmartScrollOffset(renderObject, viewportHeight, forward: false);
      setState(() {
        _scrollOffset = newOffset.clamp(0.0, double.infinity);
      });
      _savePosition();
    } else if (x > width * 0.7) {
      final newOffset = _getSmartScrollOffset(renderObject, viewportHeight, forward: true);
      setState(() {
        _scrollOffset = newOffset.clamp(0.0, double.infinity);
      });
      _savePosition();
    } else {
      setState(() => _showAppBar = !_showAppBar);
    }
  }

  double _getSmartScrollOffset(RenderCustomText? renderObject, double viewportHeight, {required bool forward}) {
    if (renderObject == null) {
      return forward ? (_scrollOffset + viewportHeight) : (_scrollOffset - viewportHeight);
    }

    return renderObject.getAlignedScrollOffset(_scrollOffset, viewportHeight, forward: forward);
  }

  void _showTranslation(String word) {
    final clean = word.toLowerCase();
    if (clean.isEmpty) return;

    TranslationBottomSheet.show(
      context: context,
      word: clean,
      dictionaryService: _dictionaryService,
      bookmarkService: _bookmarkService,
      bookId: widget.metadata?.filePath ?? widget.book.title,
      onBookmarkPressed: _loadBookmarkedWords,
    ).then((_) {
      setState(() => _selectedWordOffset = null);
    });
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _fontSize = temp;
              });
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final currentTheme = ThemeProvider.of(context)?.currentTheme ?? 'dark';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('light', 'Light', Icons.light_mode,
                Colors.white, Colors.black, currentTheme == 'light'),
            const SizedBox(height: 8),
            _buildThemeOption('dark', 'Dark', Icons.dark_mode,
                const Color(0xFF1A1A1A), const Color(0xFFE0E0E0), currentTheme == 'dark'),
            const SizedBox(height: 8),
            _buildThemeOption('sepia', 'Sepia', Icons.menu_book,
                const Color(0xFFF5E6CC), const Color(0xFF5C4033), currentTheme == 'sepia'),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String themeKey, String label, IconData icon,
      Color bgColor, Color textColor, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(label, style: TextStyle(color: textColor)),
        trailing: isSelected ? Icon(Icons.check, color: textColor) : null,
        onTap: () {
          ThemeProvider.of(context)?.changeTheme(themeKey);
          Navigator.pop(context);
        },
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

    final totalUsedHeight = topPadding + appBarHeight +
        verticalPadding + bottomInfoHeight +
        verticalPadding + bottomPadding;
    final availableTextHeight = screenHeight - totalUsedHeight;

    final renderObject = _renderObject;
    final totalHeight = renderObject?.totalHeight ?? 0;

    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details, availableTextHeight),
        child: Stack(
          children: [
            Positioned(
              top: topPadding + appBarHeight + verticalPadding,
              left: _contentPadding.left,
              right: _contentPadding.right,
              bottom: bottomPadding + verticalPadding + bottomInfoHeight,
              child: ClipRect(
                child: CustomTextWidget(
                  key: _renderKey,
                  text: _fullText,
                  textStyle: TextStyle(
                    fontSize: _fontSize,
                    height: _lineHeight,
                    color: textColor,
                  ),
                  scrollOffset: _scrollOffset,
                  selectedWordOffset: _selectedWordOffset,
                  bookmarkedWords: _bookmarkedWords,
                  textAlign: TextAlign.justify,
                  viewportHeight: availableTextHeight,
                ),
              ),
            ),
            Positioned(
              left: _contentPadding.left,
              right: _contentPadding.right,
              bottom: bottomPadding + verticalPadding,
              height: bottomInfoHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      _getCurrentSectionTitle(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.0),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    totalHeight > 0
                        ? '${(_scrollOffset / totalHeight * 100).clamp(0, 100).toStringAsFixed(1)}%'
                        : '0%',
                    style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.0),
                  ),
                ],
              ),
            ),

            if (_showAppBar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: appBarHeight + topPadding,
                  child: AppBar(
                    title: Text(widget.book.title),
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.palette),
                        onPressed: _showThemeDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_fields),
                        tooltip: 'Font size',
                        onPressed: _showFontSizeDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmarks),
                        onPressed: () async {
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