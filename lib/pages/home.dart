import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
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
      if (path == null) return;

      // Читаем и парсим
      File file = File(path);
      String content = await file.readAsString();
      Book book = Fb2Parse.parse(content);

      // Сохраняем метаданные в Hive
      final metadata = BookMetadata(
        title: book.title,
        author: book.author,
        annotation: book.annotation,
        filePath: path,
        addedDate: DateTime.now(),
      );

      await _booksBox.add(metadata);

      setState(() => _isLoading = false);

      // Переходим к чтению
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
              filePath: path,
            ),
            metadata: metadata,
          ),
        ),
      );
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openBook(BookMetadata metadata) async {
    try {
      File file = File(metadata.filePath);
      String content = await file.readAsString();
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
    }
  }

  Future<void> _deleteBook(int index) async {
    await _booksBox.deleteAt(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitalka'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
        valueListenable: _booksBox.listenable(),
        builder: (context, Box<BookMetadata> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('No books. Click + to add.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: box.length,
            itemBuilder: (context, index) {
              final book = box.getAt(index)!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(book.title),
                  subtitle: Text(book.author.join(', ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteBook(index),
                  ),
                  onTap: () => _openBook(book),
                ),
              );
            },
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