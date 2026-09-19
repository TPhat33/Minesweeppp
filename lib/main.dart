import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/storage/player_store.dart';
import 'game/audio/sound_manager.dart';

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

  // Fire-and-forget: warms the audio cache so the first sound effect in a run
  // has no latency, but nothing in startup waits on it.
  unawaited(SoundManager.preload());

  final store = await PlayerStore.open();
  runApp(MinesweepppApp(store: store));
}
