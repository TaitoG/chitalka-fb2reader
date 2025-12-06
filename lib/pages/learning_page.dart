// learning_page.dart
import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final BookmarkService _bookmarkService = BookmarkService();

  List<Bookmark> _sessionWords = [];
  int _currentIndex = 0;
  bool _isRevealed = false;
  bool _isLoading = true;
  int _totalRepetitions = 0;
  int _completedRepetitions = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      await _bookmarkService.initialize();

      final cardsForToday = await _bookmarkService.getCardsForToday();

      cardsForToday.sort((a, b) {
        if (a.masteryLevel == 0 && b.masteryLevel > 0) return 1;
        if (a.masteryLevel > 0 && b.masteryLevel == 0) return -1;
        return a.lastReviewedAt?.compareTo(b.lastReviewedAt ?? DateTime.now()) ?? 0;
      });

      int totalReps = 0;
      for (var word in cardsForToday) {
        totalReps += (3 - word.currentRepetition);
      }

      setState(() {
        _sessionWords = cardsForToday;
        _totalRepetitions = totalReps;
        _completedRepetitions = 0;
        _currentIndex = 0;
        _isLoading = false;
      });

      print('📚 Session loaded: ${_sessionWords.length} words, $_totalRepetitions repetitions needed');
    } catch (e) {
      print('Error loading session: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleReveal() {
    setState(() {
      _isRevealed = !_isRevealed;
    });
  }

  Future<void> _markRemembered() async {
    if (_sessionWords.isEmpty) return;

    final currentWord = _sessionWords[_currentIndex];
    final oldRepetition = currentWord.currentRepetition;

    await _bookmarkService.markAsCorrect(currentWord.id);

    setState(() {
      _completedRepetitions++;
    });

    await _reloadCurrentWord();

    final updatedWord = _sessionWords[_currentIndex];

    print('✅ Word answered correctly: ${updatedWord.text}');
    print('   Old repetition: $oldRepetition, New: ${updatedWord.currentRepetition}');
    print('   Progress: $_completedRepetitions/$_totalRepetitions');

    if (updatedWord.currentRepetition >= 3) {
      _showWordMasteredSnackbar(updatedWord);

      setState(() {
        _sessionWords.removeAt(_currentIndex);
        if (_sessionWords.isEmpty) {
          _currentIndex = 0;
        } else if (_currentIndex >= _sessionWords.length) {
          _currentIndex = _sessionWords.length - 1;
        }
        _isRevealed = false;
      });

      print('🎉 Word completed and removed from session');

      if (_sessionWords.isEmpty) {
        _showSessionComplete();
      }
    } else {
      _nextWord();
    }
  }

  Future<void> _markForgotten() async {
    if (_sessionWords.isEmpty) return;

    final currentWord = _sessionWords[_currentIndex];
    final oldRepetition = currentWord.currentRepetition;

    await _bookmarkService.markAsIncorrect(currentWord.id);

    final repetitionsToAdd = 3 - oldRepetition;

    setState(() {
      _completedRepetitions++;
      _totalRepetitions += repetitionsToAdd;
    });

    await _reloadCurrentWord();

    print('❌ Word answered incorrectly: ${currentWord.text}');
    print('   Repetitions reset, added $repetitionsToAdd to total');
    print('   Progress: $_completedRepetitions/$_totalRepetitions');

    _nextWord();
  }

  void _nextWord() {
    setState(() {
      if (_sessionWords.isNotEmpty) {
        _currentIndex = (_currentIndex + 1) % _sessionWords.length;
      }
      _isRevealed = false;
    });
  }

  void _prevWord() {
    setState(() {
      if (_sessionWords.isNotEmpty) {
        _currentIndex = (_currentIndex - 1) % _sessionWords.length;
        if (_currentIndex < 0) _currentIndex = _sessionWords.length - 1;
      }
      _isRevealed = false;
    });
  }

  Future<void> _reloadCurrentWord() async {
    if (_sessionWords.isEmpty) return;

    final currentId = _sessionWords[_currentIndex].id;
    final allBookmarks = await _bookmarkService.getAllBookmarks();

    try {
      final updated = allBookmarks.firstWhere((b) => b.id == currentId);
      setState(() {
        _sessionWords[_currentIndex] = updated;
      });
    } catch (e) {
      print('Error reloading word: $e');
    }
  }

  void _showWordMasteredSnackbar(Bookmark word) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🎉 "${word.text}" completed! Progress: ${word.progressPercent.toStringAsFixed(0)}%',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Great job! You\'ve completed all repetitions for today.'),
            const SizedBox(height: 16),
            Text('Total repetitions completed: $_completedRepetitions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadSession();
            },
            child: const Text('Continue Learning'),
          ),
        ],
      ),
    );
  }

  Future<void> _shuffleWords() async {
    for (var word in _sessionWords) {
      await _bookmarkService.resetSessionProgress(word.id);
    }

    final allBookmarks = await _bookmarkService.getAllBookmarks();
    for (int i = 0; i < _sessionWords.length; i++) {
      try {
        final updated = allBookmarks.firstWhere((b) => b.id == _sessionWords[i].id);
        _sessionWords[i] = updated;
      } catch (e) {
        print('Error reloading word during shuffle: $e');
      }
    }

    setState(() {
      _sessionWords.shuffle();
      _currentIndex = 0;
      _isRevealed = false;
      _totalRepetitions = _sessionWords.length * 3;
      _completedRepetitions = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cards shuffled! Progress reset.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMasteryIndicator(Bookmark word) {
    final masteryPercent = word.progressPercent;
    return Column(
      children: [
            Text(
              '${masteryPercent.toStringAsFixed(0)}% Mastered',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
      ],
    );
  }

  Widget _buildOverallProgress() {
    final progress = _totalRepetitions > 0
        ? _completedRepetitions / _totalRepetitions
        : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_completedRepetitions / $_totalRepetitions',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFlashcardContent() {
    final currentWord = _sessionWords[_currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          currentWord.bookTitle,
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          currentWord.text,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _buildMasteryIndicator(currentWord),
        const SizedBox(height: 30),
        if (_isRevealed)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'Translation:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentWord.translation ?? 'No translation available',
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (currentWord.context != null && currentWord.context!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        'Context: ${currentWord.context}',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (currentWord.notes != null && currentWord.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text(
                        'Notes: ${currentWord.notes}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (currentWord.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Wrap(
                        spacing: 8,
                        children: currentWord.tags
                            .map((tag) => Chip(
                          label: Text(tag),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              Icon(
                Icons.visibility_off,
                size: 40,
                color: Theme.of(context).iconTheme.color,
              ),
              const SizedBox(height: 10),
              Text(
                'Tap to reveal translation',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
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
          if (_sessionWords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: _shuffleWords,
              tooltip: 'Shuffle cards',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessionWords.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              'No cards due today!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildOverallProgress(),
            const SizedBox(height: 16),

            // Flashcard
            Expanded(
              child: GestureDetector(
                onTap: _toggleReveal,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: _buildFlashcardContent(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
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
                      child: const Text(
                        'I Remember',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sessionWords.length > 1 ? _prevWord : null,
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Reveal Translation',
                        style: TextStyle(color: Colors.white),
                      ),
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