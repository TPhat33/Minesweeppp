import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/game/audio/sound_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every effect points at a distinct file under sfx/', () {
    final assets = SoundEffect.values.map((e) => e.asset).toSet();
    expect(assets.length, SoundEffect.values.length);
    for (final asset in assets) {
      expect(asset, startsWith('sfx/'));
      expect(asset, endsWith('.wav'));
    }
  });

  test('every effect has a matching file checked into the repo', () {
    // Guards against a renamed or deleted wav going unnoticed: pubspec only
    // declares the folder, so a typo here would otherwise just play nothing.
    for (final effect in SoundEffect.values) {
      final file = File('assets/audio/${effect.asset}');
      expect(
        file.existsSync(),
        isTrue,
        reason: '${file.path} is missing for SoundEffect.${effect.name}',
      );
      expect(file.lengthSync(), greaterThan(0));
    }
  });

  test('play() never throws even with no audio backend available', () {
    // The test environment has no platform audio plugin registered, which is
    // exactly the case this class exists to survive.
    final sound = SoundManager();
    for (final effect in SoundEffect.values) {
      expect(() => sound.play(effect), returnsNormally);
    }
  });

  test('preload() never throws even with no audio backend available', () async {
    await expectLater(SoundManager.preload(), completes);
  });
}
