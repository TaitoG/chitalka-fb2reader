import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/book.dart';
import 'models/pagination_cache.dart';
import 'models/bookmark.dart';
import 'pages/home.dart';
import 'widgets/bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(BookMetadataAdapter());
  await Hive.openBox<BookMetadata>('books');
  Hive.registerAdapter(PaginationCacheAdapter());
  Hive.registerAdapter(SectionPaginationDataAdapter());
  Hive.registerAdapter(PageTokenDataAdapter());
  Hive.registerAdapter(TokenDataAdapter());
  Hive.registerAdapter(BookmarkAdapter());
  Hive.registerAdapter(BookmarkTypeAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chitalka',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainNavigationPage(),
    );
  }
}