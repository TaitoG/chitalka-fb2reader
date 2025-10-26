// widgets/reader/bookmark_dialog.dart

import 'package:flutter/material.dart';
import 'package:chitalka/models/bookmark.dart';
import 'package:chitalka/services/bookmark_service.dart';

class BookmarkDialog extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String selectedText;
  final String? context;
  final String? translation;
  final int sectionIndex;
  final int pageIndex;
  final BookmarkService bookmarkService;
  final Bookmark? existingBookmark;

  const BookmarkDialog({
    Key? key,
    required this.bookId,
    required this.bookTitle,
    required this.selectedText,
    this.context,
    this.translation,
    required this.sectionIndex,
    required this.pageIndex,
    required this.bookmarkService,
    this.existingBookmark,
  }) : super(key: key);

  @override
  State<BookmarkDialog> createState() => _BookmarkDialogState();

  static Future<bool?> show(
      BuildContext context, {
        required String bookId,
        required String bookTitle,
        required String selectedText,
        String? contextText,
        String? translation,
        required int sectionIndex,
        required int pageIndex,
        required BookmarkService bookmarkService,
        Bookmark? existingBookmark,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BookmarkDialog(
        bookId: bookId,
        bookTitle: bookTitle,
        selectedText: selectedText,
        context: contextText,
        translation: translation,
        sectionIndex: sectionIndex,
        pageIndex: pageIndex,
        bookmarkService: bookmarkService,
        existingBookmark: existingBookmark,
      ),
    );
  }
}

class _BookmarkDialogState extends State<BookmarkDialog> {
  late BookmarkType _selectedType;
  late TextEditingController _notesController;
  late TextEditingController _tagController;
  late List<String> _tags;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.existingBookmark?.type ?? BookmarkType.word;
    _notesController = TextEditingController(
      text: widget.existingBookmark?.notes ?? '',
    );
    _tagController = TextEditingController();
    _tags = List.from(widget.existingBookmark?.tags ?? []);
    _isFavorite = widget.existingBookmark?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _saveBookmark() async {
    if (widget.existingBookmark != null) {
      final updated = widget.existingBookmark!.copyWith(
        type: _selectedType,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        tags: _tags,
        isFavorite: _isFavorite,
      );
      await widget.bookmarkService.updateBookmark(updated);
    } else {
      await widget.bookmarkService.createBookmark(
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        type: _selectedType,
        text: widget.selectedText,
        context: widget.context,
        translation: widget.translation,
        sectionIndex: widget.sectionIndex,
        pageIndex: widget.pageIndex,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        tags: _tags,
      );
    }

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark saved!')),
      );
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bookmark_add, size: 24),
          const SizedBox(width: 8),
          Text(widget.existingBookmark != null ? 'Edit Bookmark' : 'Add Bookmark'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                widget.selectedText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (widget.translation != null) ...[
              const Text(
                'Translation:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.translation!,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add your notes here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            CheckboxListTile(
              value: _isFavorite,
              onChanged: (value) {
                setState(() {
                  _isFavorite = value ?? false;
                });
              },
              title: const Row(
                children: [
                  Icon(Icons.star, size: 20, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Add to favorites'),
                ],
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saveBookmark,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }
}