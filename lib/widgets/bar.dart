//bar.dart
import 'package:flutter/material.dart';
import 'package:chitalka/pages/home.dart';
import 'package:chitalka/pages/bookmark_page.dart';
import 'package:chitalka/pages/learning_page.dart';
import 'package:chitalka/services/bookmark_service.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  void initState() {
    super.initState();
    _bookmarkService.initialize();
  }

  List<Widget> get _pages => [
    const HomePage(),
    BookmarksPage(bookmarkService: _bookmarkService),
    const LearningPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmarks),
            label: 'Bookmarks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Learning',
          ),
        ],
      ),
    );
  }
}