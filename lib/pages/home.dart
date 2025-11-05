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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _booksBox = Hive.box<BookMetadata>('books');
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookMetadata> get _filteredBooks {
    if (_searchQuery.isEmpty) {
      return _booksBox.values.toList()
        ..sort((a, b) => (b.lastRead ?? b.addedDate).compareTo(a.lastRead ?? a.addedDate));
    }
    return _booksBox.values.where((book) {
      final title = book.title.toLowerCase();
      final author = book.author.join(' ').toLowerCase();
      return title.contains(_searchQuery) || author.contains(_searchQuery);
    }).toList()
      ..sort((a, b) => (b.lastRead ?? b.addedDate).compareTo(a.lastRead ?? a.addedDate));
  }

  Future<void> _openBook(BookMetadata metadata) async {
    _showLoading('Opening "${metadata.title}"...');
    try {
      final content = await _loadContent(metadata.filePath);
      final book = await _parseBook(content, metadata.filePath);

      metadata.lastRead = DateTime.now();
      await metadata.save();

      _hideLoading();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RenderObjectReaderPage(
              book: book,
              metadata: metadata,
              ),
        ),
      );
    } catch (e) {
      _hideLoading();
      _showError('Failed to open book: $e');
    }
  }

  Future<void> _pickAndAddBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['fb2', 'zip', 'fb2.zip'],
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final fileName = path.split('/').last;

    _showLoading('Adding "$fileName"...');

    try {
      final content = await _loadContent(path);
      final parsed = Fb2Parse.parse(content);

      final metadata = BookMetadata(
        title: parsed.title,
        author: parsed.author,
        annotation: parsed.annotation,
        filePath: path,
        addedDate: DateTime.now(),
        lastRead: DateTime.now(),
        coverImage: parsed.coverImage,
      );

      await _booksBox.add(metadata);
      _hideLoading();

      _showSnackBar('Added: ${metadata.title}', Colors.green);
    } catch (e) {
      _hideLoading();
      _showError('Failed to add book: $e');
    }
  }

  Future<String> _loadContent(String filePath) async {
    final bytes = await File(filePath).readAsBytes();

    if (filePath.toLowerCase().endsWith('.zip') || filePath.toLowerCase().endsWith('.fb2.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.name.toLowerCase().endsWith('.fb2') && file.isFile) {
          return _decodeContent(file.content as List<int>);
        }
      }
      throw Exception('FB2 not found in ZIP');
    } else {
      return _decodeContent(bytes);
    }
  }

  Future<String> _decodeContent(List<int> data) async {
    final head = utf8.decode(data.take(200).toList(), allowMalformed: true);
    final encoding = RegExp(r'''encoding=["']([A-Za-z0-9_\-]+)["']''')
        .firstMatch(head)
        ?.group(1)
        ?.toLowerCase() ?? 'utf-8';

    try {
      return await CharsetConverter.decode(encoding, Uint8List.fromList(data));
    } catch (e) {
      return utf8.decode(data, allowMalformed: true);
    }
  }

  Book _parseBook(String content, String filePath) {
    final parsed = Fb2Parse.parse(content);
    return Book(
      title: parsed.title,
      author: parsed.author,
      annotation: parsed.annotation,
      sections: parsed.sections,
      content: content,
      filePath: filePath,
      coverImage: parsed.coverImage,
    );
  }

  Future<void> _deleteBook(int index) async {
    final book = _booksBox.getAt(index);
    if (book == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete book?'),
        content: Text('Remove "${book.title}" from library?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _booksBox.deleteAt(index);
    _showSnackBar('Deleted: ${book.title}', Colors.orange);
  }

  void _showLoading(String message) {
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });
  }

  void _hideLoading() {
    setState(() {
      _isLoading = false;
      _loadingMessage = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Widget _buildBookCover(BookMetadata book) {
    if (book.coverImage != null && book.coverImage!.isNotEmpty) {
      try {
        final bytes = base64.decode(book.coverImage!);
        return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultCover(book));
      } catch (_) {}
    }
    return _defaultCover(book);
  }

  Widget _defaultCover(BookMetadata book) {
    final hash = book.title.hashCode;
    final color = Color((hash & 0xFFFFFF) | 0xFF000000).withOpacity(0.3);
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.6)])),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 32,),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                book.title.split(' ').take(2).join('\n'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,),
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

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    return '${diff.inDays ~/ 30}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitalka'),
        elevation: 2,
        actions: [
          if (_booksBox.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(context: context, delegate: _BookSearchDelegate(_booksBox));
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: _booksBox.listenable(),
            builder: (context, box, _) {
              final books = _filteredBooks;
              if (books.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 80,),
                      const SizedBox(height: 20),
                      Text(
                        _searchQuery.isEmpty ? 'No books' : 'Not found',
                        style: TextStyle(fontSize: 18,),
                      ),
                      if (_searchQuery.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text('Tap + to add', style: TextStyle(fontSize: 14,)),
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
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final originalIndex = _booksBox.values.toList().indexOf(book);

                  return GestureDetector(
                    onTap: () => _openBook(book),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: _buildBookCover(book))),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(book.author.join(', '), style: TextStyle(fontSize: 11,), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('Read ${_formatDate(book.lastRead ?? book.addedDate)}', style: TextStyle(fontSize: 9,)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => _deleteBook(originalIndex),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
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

          if (_isLoading)
            Container(
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(40),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_loadingMessage ?? 'Loading...', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndAddBook,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BookSearchDelegate extends SearchDelegate<String> {
  final Box<BookMetadata> box;
  _BookSearchDelegate(this.box);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final results = box.values.where((b) =>
    b.title.toLowerCase().contains(query.toLowerCase()) ||
        b.author.any((a) => a.toLowerCase().contains(query.toLowerCase()))
    ).toList();

    if (results.isEmpty) {
      return const Center(child: Text('Not found'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final book = results[i];
        return ListTile(
          leading: book.coverImage != null
              ? Image.memory(base64.decode(book.coverImage!), width: 40, height: 40, fit: BoxFit.cover)
              : const Icon(Icons.book),
          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(book.author.join(', '), style: const TextStyle(fontSize: 12)),
          onTap: () {
            close(context, '');
            (context as Element).findAncestorStateOfType<_HomePageState>()?._openBook(book);
          },
        );
      },
    );
  }
}