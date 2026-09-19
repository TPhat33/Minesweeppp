import 'package:flutter/material.dart';

import 'core/storage/player_store.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

class MinesweepppApp extends StatelessWidget {
  const MinesweepppApp({super.key, required this.store});

  final PlayerStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minesweeppp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: HomeScreen(store: store),
    );
  }
}
