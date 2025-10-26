// pages/bookmarks/bookmarks_page.dart
import 'package:flutter/material.dart';
import 'package:chitalka/models/bookmark.dart';
import 'package:chitalka/services/bookmark_service.dart';
import 'package:chitalka/widgets/bookmark_dialog.dart';

class BookmarksPage extends StatefulWidget {
  final BookmarkService bookmarkService;

  const BookmarksPage({
    Key? key,
    required this.bookmarkService,
  }) : super(key: key);

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Bookmark> _bookmarks = [];
  List<Bookmark> _filteredBookmarks = [];
  String _searchQuery = '';
  BookmarkType? _filterType;
  bool _showFavoritesOnly = false;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await widget.bookmarkService.getAllBookmarks();
    setState(() {
      _bookmarks = bookmarks;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _bookmarks;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((b) =>
      b.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (b.translation?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    if (_filterType != null) {
      filtered = filtered.where((b) => b.type == _filterType).toList();
    }

    if (_showFavoritesOnly) {
      filtered = filtered.where((b) => b.isFavorite).toList();
    }

    if (_selectedTag != null) {
      filtered = filtered.where((b) => b.tags.contains(_selectedTag)).toList();
    }

    setState(() {
      _filteredBookmarks = filtered;
    });
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bookmark?'),
        content: Text('Delete "${bookmark.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.bookmarkService.deleteBookmark(bookmark.id);
      _loadBookmarks();
    }
  }

  Future<void> _editBookmark(Bookmark bookmark) async {
    final result = await BookmarkDialog.show(
      context,
      bookId: bookmark.bookId,
      bookTitle: bookmark.bookTitle,
      selectedText: bookmark.text,
      contextText: bookmark.context,
      translation: bookmark.translation,
      sectionIndex: bookmark.sectionIndex,
      pageIndex: bookmark.pageIndex,
      bookmarkService: widget.bookmarkService,
      existingBookmark: bookmark,
    );

    if (result == true) {
      _loadBookmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search bookmarks...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _filteredBookmarks.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _bookmarks.isEmpty
                        ? 'No bookmarks yet'
                        : 'No bookmarks found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredBookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = _filteredBookmarks[index];
                return _BookmarkCard(
                  bookmark: bookmark,
                  onTap: () => _editBookmark(bookmark),
                  onDelete: () => _deleteBookmark(bookmark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkCard({
    required this.bookmark,
    required this.onTap,
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bookmark.bookTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                bookmark.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              if (bookmark.translation != null) ...[
                const SizedBox(height: 8),
                Text(
                  bookmark.translation!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              if (bookmark.notes != null && bookmark.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bookmark.notes!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],

              if (bookmark.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: bookmark.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple[900],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(bookmark.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (bookmark.reviewCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.repeat, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${bookmark.reviewCount}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} weeks ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}