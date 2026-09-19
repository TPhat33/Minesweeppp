import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/storage/player_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The board wants the whole screen; the system bars come back on a swipe.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final store = await PlayerStore.open();
  runApp(MinesweepppApp(store: store));
}
