import 'package:flutter/material.dart';
import 'package:chitalka/models/book.dart';

class ReaderPage extends StatefulWidget {
  final Book book;
  const ReaderPage({Key? key, required this.book}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  int _currentSectionIndex = 0;
  int _currentPageIndex = 0;
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  List<String> _pages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginateCurrentSection();
    });
  }

  BookSection get _currentSection => widget.book.sections[_currentSectionIndex];

  bool get _hasNextPage {
    return _currentPageIndex < _pages.length - 1 ||
           _currentSectionIndex < widget.book.sections.length - 1;
  }
  bool get _hasPrevPage {
    return _currentPageIndex > 0 || _currentSectionIndex > 0;
  }

  void _nextPage() {
    setState(() {
      if (_currentPageIndex < _pages.length - 1) {
        _currentPageIndex++;
      } else if (_currentSectionIndex < widget.book.sections.length -1) {
        _currentSectionIndex++;
        _currentPageIndex = 0;
        _paginateCurrentSection();
      }
    });
  }
  void _prevPage() {
    setState(() {
      if (_currentPageIndex > 0) {
        _currentPageIndex--;
      } else if (_currentSectionIndex > 0) {
        _currentSectionIndex--;
        _paginateCurrentSection(lastPage: true);
      }
    });
  }
  void _paginateCurrentSection({bool lastPage = false}) async {
    final text = _currentSection.paragraphs.join('\n\n');
    final size = MediaQuery.of(context).size;
    final padding = const EdgeInsets.all(24.0);
    final availableHeight = size.height -
        kToolbarHeight -
        padding.vertical -
        MediaQuery.of(context).padding.vertical -
        60;

    final textStyle = TextStyle(fontSize: _fontSize, height: _lineHeight);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final words = text.split(RegExp(r'(\s+)'));
    List<String> pages = [];
    StringBuffer currentPage = StringBuffer();

    for (var word in words) {
      final tentative = '${currentPage.toString()}$word';
      textPainter.text = TextSpan(text: tentative, style: textStyle);
      textPainter.layout(maxWidth: size.width - padding.horizontal);

      if (textPainter.height > availableHeight && currentPage.isNotEmpty) {
        pages.add(currentPage.toString());
        currentPage = StringBuffer(word);
      } else {
        currentPage.write('$word ');
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage.toString().trim());
    }

    setState(() {
      _pages = pages;
      _currentPageIndex = lastPage ? pages.length - 1 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
      ),
      body: GestureDetector(
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            if (_hasPrevPage) _prevPage();
          } else {
            if (_hasNextPage) _nextPage();
          }
        },
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(
                    _pages[_currentPageIndex],
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: _lineHeight
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Section ${_currentSectionIndex+1}/${widget.book.sections.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('Page ${_currentPageIndex+1}/${_pages.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),)
                ],
              ),)
            ],
          ),
        ),
      ),
    );
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paginateCurrentSection();
  }
}