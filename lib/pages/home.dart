// home.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:charset_converter/charset_converter.dart';
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
  late Box<String> _contentCache;
  final Map<String, Book> _parsedBooksCache = {};
  bool _isLoading = false;
  bool _cacheInitialized = false;

  @override
  void initState() {
    super.initState();
    _booksBox = Hive.box<BookMetadata>('books');
    _initContentCache();
  }

  Future<void> _initContentCache() async {
    try {
      _contentCache = await Hive.openBox<String>('book_contents');
      _cacheInitialized = true;
      print('✅ Content cache initialized with ${_contentCache.length} entries');
    } catch (e) {
      print('❌ Error opening content cache: $e');
    }
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

          // Detect encoding from XML header
          final head = utf8.decode(data.take(200).toList(), allowMalformed: true);
          final encodingMatch =
          RegExp(r'''encoding=["\']([A-Za-z0-9_\-]+)["\']''').firstMatch(head);
          final encoding = encodingMatch?.group(1)?.toLowerCase() ?? 'utf-8';

          try {
            // Decode using proper encoding
            final decoded = await CharsetConverter.decode(
              encoding,
              Uint8List.fromList(data),
            );
            print('✅ Decoded ZIP entry with $encoding');
            return decoded;
          } catch (e) {
            print('⚠️ Charset decode failed ($encoding), fallback to UTF-8: $e');
            return utf8.decode(data, allowMalformed: true);
          }
        }
      }

      throw Exception('FB2 file not found in ZIP archive');
    } catch (e) {
      print('❌ Error extracting ZIP: $e');
      throw Exception('Failed to extract FB2 from ZIP: $e');
    }
  }

  Future<String> _loadContent(String filePath) async {
    if (_cacheInitialized && _contentCache.containsKey(filePath)) {
      print('⚡ Loading content from cache: $filePath');
      return _contentCache.get(filePath)!;
    }

    print('📖 Loading content from file: $filePath');

    String content;
    if (filePath.toLowerCase().endsWith('.zip') ||
        filePath.toLowerCase().endsWith('.fb2.zip')) {
      content = await _extractFb2FromZip(filePath);
    } else {
      final bytes = await File(filePath).readAsBytes();

      // Detect encoding from header
      final head = utf8.decode(bytes.take(200).toList(), allowMalformed: true);
      final encodingMatch =
      RegExp(r'''encoding=["\']([A-Za-z0-9_\-]+)["\']''').firstMatch(head);
      final encoding = encodingMatch?.group(1)?.toLowerCase() ?? 'utf-8';

      try {
        content = await CharsetConverter.decode(encoding, bytes);
        print('✅ Decoded file with $encoding');
      } catch (e) {
        print('⚠️ Charset decode failed ($encoding), fallback to UTF-8');
        content = utf8.decode(bytes, allowMalformed: true);
      }
    }

    if (_cacheInitialized) {
      await _contentCache.put(filePath, content);
      print('💾 Content cached');
    }

    return content;
  }

  Book _parseBook(String content, String filePath) {
    if (_parsedBooksCache.containsKey(filePath)) {
      print('⚡ Using parsed book from memory cache');
      return _parsedBooksCache[filePath]!;
    }

    print('🔄 Parsing FB2...');

    final parsedBook = Fb2Parse.parse(content);
    final book = Book(
      title: parsedBook.title,
      author: parsedBook.author,
      annotation: parsedBook.annotation,
      sections: parsedBook.sections,
      content: content,
      filePath: filePath,
      coverImage: parsedBook.coverImage,
    );

    _parsedBooksCache[filePath] = book;
    print('✅ Book parsed and cached');

    return book;
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
      if (path == null) {
        setState(() => _isLoading = false);
        return;
      }

      print('📚 Opening new book: $path');

      String content = await _loadContent(path);

      Book book = _parseBook(content, path);

      final metadata = BookMetadata(
        title: book.title,
        author: book.author,
        annotation: book.annotation,
        filePath: path,
        addedDate: DateTime.now(),
        coverImage: book.coverImage,
      );

      await _booksBox.add(metadata);

      setState(() => _isLoading = false);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderPage(
            book: book,
            metadata: metadata,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка открытия файла: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openBook(BookMetadata metadata) async {
    try {
      setState(() => _isLoading = true);

      print('📖 Opening book: ${metadata.title}');

      String content = await _loadContent(metadata.filePath);

      Book book = _parseBook(content, metadata.filePath);

      setState(() => _isLoading = false);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderPage(
            book: book,
            metadata: metadata,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error opening book: $e');
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка открытия книги: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteBook(int index) async {
    final book = _booksBox.getAt(index);
    if (book != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete book?'),
          content: Text('Remove "${book.title}" from library?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (_cacheInitialized) {
        await _contentCache.delete(book.filePath);
      }
      _parsedBooksCache.remove(book.filePath);

      print('🗑️ Deleted book and caches: ${book.title}');
    }

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
    final hash = book.title.hashCode;
    final color = Color.fromARGB(
      255,
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      hash & 0x0000FF,
    ).withOpacity(0.3);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                book.title.split(' ').take(2).join('\n'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
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
        actions: [
          if (_cacheInitialized && _contentCache.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_contentCache.length} cached',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading book...'),
          ],
        ),
      )
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
              final isCached = _cacheInitialized &&
                  _contentCache.containsKey(book.filePath);

              return GestureDetector(
                onTap: () => _openBook(book),
                onLongPress: () => _deleteBook(index),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Column(
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
                                    Expanded(
                                      child: Text(
                                        'Added ${_formatDate(book.addedDate)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () => _deleteBook(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Delete book',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (isCached)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flash_on,
                              size: 16,
                              color: Colors.white,
                            ),
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
        tooltip: 'Add book',
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