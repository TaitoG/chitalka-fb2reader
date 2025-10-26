// home.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import '../core/fb2.dart';
import '../models/book.dart';
import 'reader.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<BookMetadata> _booksBox;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _booksBox = Hive.box<BookMetadata>('books');
  }

  Future<String> _extractFb2FromZip(String zipPath) async {
    try {
      final file = File(zipPath);
      final bytes = await file.readAsBytes();

      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name.toLowerCase();
        if (filename.endsWith('.fb2') && file.isFile) {
          final data = file.content as List<int>;
          return utf8.decode(data);
        }
      }

      throw Exception('FB2 file not found in ZIP archive');
    } catch (e) {
      print('Error extracting ZIP: $e');
      throw Exception('Failed to extract FB2 from ZIP: $e');
    }
  }

  Future<void> _pickAndOpenBook() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fb2', 'zip', 'fb2.zip'],
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      String? path = result.files.single.path;
      if (path == null) return;

      String content;
      String filePath = path;

      if (path.toLowerCase().endsWith('.zip') || path.toLowerCase().endsWith('.fb2.zip')) {
        content = await _extractFb2FromZip(path);
      } else {
        File file = File(path);
        content = await file.readAsString();
      }

      Book book = Fb2Parse.parse(content);

      final metadata = BookMetadata(
        title: book.title,
        author: book.author,
        annotation: book.annotation,
        filePath: filePath,
        addedDate: DateTime.now(),
        coverImage: book.coverImage,
      );

      await _booksBox.add(metadata);

      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderPage(
            book: Book(
              title: book.title,
              author: book.author,
              annotation: book.annotation,
              sections: book.sections,
              content: content,
              filePath: filePath,
            ),
            metadata: metadata,
          ),
        ),
      );
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка открытия файла: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openBook(BookMetadata metadata) async {
    try {
      String content;

      if (metadata.filePath.toLowerCase().endsWith('.zip') ||
          metadata.filePath.toLowerCase().endsWith('.fb2.zip')) {
        content = await _extractFb2FromZip(metadata.filePath);
      } else {
        File file = File(metadata.filePath);
        content = await file.readAsString();
      }

      Book book = Fb2Parse.parse(content);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderPage(
            book: Book(
              title: book.title,
              author: book.author,
              annotation: book.annotation,
              sections: book.sections,
              content: content,
              filePath: metadata.filePath,
            ),
            metadata: metadata,
          ),
        ),
      );
    } catch (e) {
      print('Error opening book: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка открытия книги: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteBook(int index) async {
    await _booksBox.deleteAt(index);
    setState(() {});
  }

  Widget _buildBookCover(BookMetadata book) {
    if (book.coverImage != null && book.coverImage!.isNotEmpty) {
      try {
        final imageBytes = base64.decode(book.coverImage!);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultCover(book);
          },
        );
      } catch (e) {
        return _buildDefaultCover(book);
      }
    }
    return _buildDefaultCover(book);
  }

  Widget _buildDefaultCover(BookMetadata book) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              book.title.split(' ').map((word) => word.isNotEmpty ? word[0] : '').take(3).join(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitalka'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
        valueListenable: _booksBox.listenable(),
        builder: (context, Box<BookMetadata> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'No books in library',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap + to add your first book',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: box.length,
            itemBuilder: (context, index) {
              final book = box.getAt(index)!;
              return GestureDetector(
                onTap: () => _openBook(book),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Book Cover
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: _buildBookCover(book),
                        ),
                      ),

                      // Book Info
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book.author.join(', '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Added ${_formatDate(book.addedDate)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18),
                                  onPressed: () => _deleteBook(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndOpenBook,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'today';
    if (difference.inDays == 1) return 'yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7}w ago';
    return '${difference.inDays ~/ 30}mo ago';
  }
}