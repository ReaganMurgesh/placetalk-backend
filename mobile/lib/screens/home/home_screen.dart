import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/widgets/pokemon_style_map.dart';

/// Full-screen exploration mode — no AppBar, no BottomNavBar.
/// Navigation to Community/Diary lives inside PokemonGoMap's ≡ menu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PokemonGoMap();
  }
}
