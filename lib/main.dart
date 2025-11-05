//main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/book.dart';
import 'models/bookmark.dart';
import 'pages/home.dart';
import 'themes/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/bar.dart';
import 'themes/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('app_theme') ?? 'light';

  await Hive.initFlutter();
  Hive.registerAdapter(BookMetadataAdapter());
  await Hive.openBox<BookMetadata>('books');
  Hive.registerAdapter(BookmarkAdapter());
  Hive.registerAdapter(BookmarkTypeAdapter());

  runApp(MyApp(initialTheme: savedTheme));
}

class MyApp extends StatefulWidget {
  final String initialTheme;
  const MyApp({required this.initialTheme, super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initialTheme;
  }

  void _changeTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
    setState(() => _currentTheme = theme);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _currentTheme == 'dark';
    final isSepia = _currentTheme == 'sepia';

    return ThemeProvider(
      currentTheme: _currentTheme,
      changeTheme: _changeTheme,
      child: MaterialApp(
        title: 'Chitalka',
        theme: AppThemes.light,
        darkTheme: AppThemes.dark,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: const MainNavigationPage(),
        builder: (context, child) {
          if (isSepia) {
            return Theme(data: AppThemes.sepia, child: child!);
          }
          return child!;
        },
      ),
    );
  }
}