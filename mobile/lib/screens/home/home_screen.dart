import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/widgets/pokemon_style_map.dart';
import 'package:placetalk/screens/social/community_screen.dart';
import 'package:placetalk/screens/social/diary_screen.dart';
import 'package:placetalk/theme/japanese_theme.dart';
import 'package:placetalk/providers/locale_provider.dart';
import 'package:placetalk/l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    PokemonGoMap(),
    CommunityListScreen(),
    DiaryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appTitle),
        actions: [
          // Language toggle button
          IconButton(
            onPressed: () {
              ref.read(localeProvider.notifier).toggleLanguage();
            },
            icon: Icon(locale.languageCode == 'en' ? Icons.translate : Icons.language),
            tooltip: locale.languageCode == 'en' ? '日本語' : 'English',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: JapaneseColors.wakatake,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore),
            label: localizations.discover,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups),
            label: localizations.community,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.auto_stories),
            label: localizations.diary,
          ),
        ],
      ),
    );
  }
}
