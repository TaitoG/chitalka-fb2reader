import 'package:flutter/material.dart';
import 'package:chitalka/core/fb2.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/pages/reader.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book> _savedBooks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedBooks();
  }

  Future<void> _loadSavedBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final booksData = prefs.getStringList('books') ?? [];

    _savedBooks = booksData.map((b) {
      final data = jsonDecode(b);
      return Book(
        title: data['title'],
        author: List<String>.from(data['author']),
        annotation: data['annotation'],
        sections: [],
        content: '',
        filePath: data['path'],
      );
    }).toList();

    setState(() {});
  }

  Future<void> _saveBookMetadata(Book book) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> booksData = prefs.getStringList('books') ?? [];

    final bookJson = jsonEncode({
      'title': book.title,
      'author': book.author,
      'annotation': book.annotation,
      'path': book.filePath,
    });

    if (!booksData.any((b) => jsonDecode(b)['path'] == book.filePath)) {
      booksData.add(bookJson);
      await prefs.setStringList('books', booksData);
      _savedBooks.add(book);
      setState(() {});
    }
  }

  Future<void> _pickAndOpenBook() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fb2'],
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

      File file = File(path);
      String content = await file.readAsString();
      Book parsedBook = Fb2Parse.parse(content);

      Book book = Book(
        title: parsedBook.title,
        author: parsedBook.author,
        annotation: parsedBook.annotation,
        sections: parsedBook.sections,
        content: content,
        filePath: path,
      );

      await _saveBookMetadata(book);

      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderPage(book: book),
        ),
      );
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openSavedBook(Book book) async {
    if (book.sections.isEmpty && book.filePath != null) {
      File file = File(book.filePath!);
      String content = await file.readAsString();
      Book fullBook = Fb2Parse.parse(content);

      book = Book(
        title: fullBook.title,
        author: fullBook.author,
        annotation: fullBook.annotation,
        sections: fullBook.sections,
        content: content,
        filePath: book.filePath,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitalka'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedBooks.isEmpty
          ? const Center(child: Text('No books. Click + to add.'))
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _savedBooks.length,
        itemBuilder: (context, index) {
          final book = _savedBooks[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text(book.title),
              subtitle: Text(book.author.join(', ')),
              onTap: () => _openSavedBook(book),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndOpenBook,
        child: const Icon(Icons.add),
      ),
    );
  }
}
