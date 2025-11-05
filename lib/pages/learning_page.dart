// learning_page.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final BookmarkService _bookmarkService = BookmarkService();
  late Box<Bookmark> _bookmarksBox;

  List<Bookmark> _flashcards = [];
  int _currentCardIndex = 0;
  bool _isRevealed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bookmarksBox = Hive.box<Bookmark>('bookmarks');
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    try {
      await _bookmarkService.initialize();
      final List<Bookmark> allBookmarks = await _bookmarkService.getAllBookmarks();
      final wordBookmarks = allBookmarks.where((bookmark) => bookmark.type == BookmarkType.word).toList();
      wordBookmarks.shuffle();

      setState(() {
        _flashcards = wordBookmarks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading flashcards: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextCard() {
    setState(() {
      _currentCardIndex = (_currentCardIndex + 1) % _flashcards.length;
      _isRevealed = false;
    });
  }

  void _prevCard() {
    setState(() {
      _currentCardIndex = (_currentCardIndex - 1) % _flashcards.length;
      if (_currentCardIndex < 0) _currentCardIndex = _flashcards.length - 1;
      _isRevealed = false;
    });
  }

  void _toggleReveal() {
    setState(() {
      _isRevealed = !_isRevealed;
    });
  }

  void _markRemembered() {
    _updateReviewCount();
    _nextCard();
  }

  void _markForgotten() {
    _updateReviewCount();
    _nextCard();
  }

  Future<void> _updateReviewCount() async {
    if (_flashcards.isEmpty) return;

    final currentBookmark = _flashcards[_currentCardIndex];
    await _bookmarkService.markAsReviewed(currentBookmark.id);

    _loadFlashcards();
  }

  void _resetProgress() {
    setState(() {
      _currentCardIndex = 0;
      _isRevealed = false;
      _flashcards.shuffle();
    });
  }

  Widget _buildFlashcardContent() {
    final currentBookmark = _flashcards[_currentCardIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Book title
        Text(
          currentBookmark.bookTitle,
          style: const TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Word
        Text(
          currentBookmark.text,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        if (_isRevealed)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    'Translation:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentBookmark.translation ?? 'No translation available',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Additional context if available
                  if (currentBookmark.context != null && currentBookmark.context!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        'Context: ${currentBookmark.context}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Notes if available
                  if (currentBookmark.notes != null && currentBookmark.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text(
                        'Notes: ${currentBookmark.notes}',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Tags if available
                  if (currentBookmark.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Wrap(
                        spacing: 8,
                        children: currentBookmark.tags.map((tag) => Chip(
                          label: Text(tag),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              const Icon(
                Icons.visibility_off,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                'Tap to reveal translation',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning'),
        actions: [
          if (_flashcards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: _resetProgress,
              tooltip: 'Shuffle cards',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _flashcards.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80,),
            SizedBox(height: 20),
            Text(
              'No flashcards available',
              style: TextStyle(fontSize: 18,),
            ),
            SizedBox(height: 10),
            Text(
              'Add some word bookmarks to start learning',
              style: TextStyle(fontSize: 14,),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _flashcards.isEmpty ? 0 : (_currentCardIndex + 1) / _flashcards.length,
            ),
            const SizedBox(height: 16),

            // Progress text and stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentCardIndex + 1} / ${_flashcards.length}',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Reviews: ${_flashcards[_currentCardIndex].reviewCount}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Flashcard
            Expanded(
              child: GestureDetector(
                onTap: _toggleReveal,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: _buildFlashcardContent(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Navigation and action buttons
            if (_isRevealed)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _markForgotten,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(
                        'Need Practice',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _markRemembered,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('I Remember'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevCard,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _toggleReveal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reveal Translation'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}