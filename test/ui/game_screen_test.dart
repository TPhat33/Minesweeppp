import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';
import 'package:minesweeppp/core/models/game_settings.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/game/game_session.dart';
import 'package:minesweeppp/game/minesweeper_game.dart';
import 'package:minesweeppp/ui/screens/game_screen.dart';
import 'package:minesweeppp/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/test_boards.dart';

const _field = <String>[
  '.*.......',
  '..*......',
  '.*.......',
  '.........',
  '.........',
  '....*....',
  '.........',
  '.........',
  '.........',
];

Future<PlayerStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return PlayerStore.open();
}

Future<void> _pumpGame(
  WidgetTester tester,
  MinesweeperEngine engine,
  PlayerStore store, {
  bool showStartCover = false,
}) async {
  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: GameScreen(
        engine: engine,
        settings: const GameSettings(),
        store: store,
        showStartCover: showStartCover,
      ),
    ),
  );
  // The game loop never goes idle, so settle() would spin forever.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('the HUD shows the counters and the mode toggle', (tester) async {
    final engine = engineFrom(_field, startX: 0, startY: 0);
    await _pumpGame(tester, engine, await _store());

    expect(find.text('4'), findsWidgets, reason: 'four mines left to mark');
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Flag'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('classic mode has no energy meter', (tester) async {
    await _pumpGame(
      tester,
      engineFrom(_field, startX: 0, startY: 0),
      await _store(),
    );
    expect(find.textContaining('charging'), findsNothing);
    expect(find.text('+15s'), findsNothing);
  });

  testWidgets('timed mode shows the energy meter and the boost button', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed),
      await _store(),
    );
    expect(find.textContaining('charging'), findsOneWidget);
    expect(find.text('+15s'), findsOneWidget);
    // Nothing salvaged yet, so there is nothing to spend.
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('+15s'), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the salvage panel appears only once flags are selected', (
    tester,
  ) async {
    final engine = engineFrom(_field, startX: 0, startY: 0);
    await _pumpGame(tester, engine, await _store());

    expect(find.text('SALVAGE'), findsNothing);

    engine.toggleFlag(1);
    engine.toggleSalvageSelection(1);
    engine.toggleFlag(1 * 9 + 2);
    engine.toggleSalvageSelection(1 * 9 + 2);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SALVAGE'), findsOneWidget);
    expect(find.text('2 marked'), findsOneWidget);
    expect(find.text('+220'), findsOneWidget);
    expect(find.textContaining('incl. +20 batch'), findsOneWidget);
    expect(find.textContaining('next +140'), findsOneWidget);
  });

  testWidgets('switching to flag mode makes a tap place a flag', (
    tester,
  ) async {
    final engine = engineFrom(_field, startX: 0, startY: 0);
    final store = await _store();
    await _pumpGame(tester, engine, store);

    await tester.tap(find.text('Flag'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pause dialog saves and offers to leave', (tester) async {
    final engine = engineFrom(_field, startX: 0, startY: 0);
    await _pumpGame(tester, engine, await _store());

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Save and leave'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('a board that may need a guess says so', (tester) async {
    final engine = MinesweeperEngine(
      board: boardFrom(_field, startX: 0, startY: 0),
      difficulty: Difficulty.beginner,
      mode: GameMode.classic,
      seed: 1,
      noGuess: false,
    );
    await _pumpGame(tester, engine, await _store());
    expect(find.text('this board may need a guess'), findsOneWidget);
  });

  testWidgets('coming back from the background asks before resuming', (
    tester,
  ) async {
    final engine = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
    await _pumpGame(tester, engine, await _store());

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    final remaining = engine.secondsRemaining;
    await tester.pump(const Duration(seconds: 2));
    expect(
      engine.secondsRemaining,
      remaining,
      reason: 'the clock must not run while the app is in the background',
    );

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Paused'), findsOneWidget);
  });

  group('start cover', () {
    testWidgets(
      'a fresh run is hidden behind a tap-to-start cover, and the clock '
      'waits for it',
      (tester) async {
        final engine = engineFrom(
          _field,
          startX: 0,
          startY: 0,
          mode: GameMode.timed,
        );
        final before = engine.secondsRemaining;
        await _pumpGame(tester, engine, await _store(), showStartCover: true);

        expect(find.text('TAP TO START'), findsOneWidget);
        // The board underneath is already opened (same as any other run —
        // the solver's proof is anchored to construction time), but the
        // cover hides it and the clock is held so nothing runs before the
        // player has looked at anything.
        await tester.pump(const Duration(seconds: 2));
        expect(engine.secondsRemaining, before);

        await tester.tap(find.text('TAP TO START'));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.text('TAP TO START'), findsNothing);
        await tester.pump(const Duration(milliseconds: 500));
        expect(engine.secondsRemaining, lessThan(before));
      },
    );

    testWidgets('a resumed run never shows the cover', (tester) async {
      await _pumpGame(
        tester,
        engineFrom(_field, startX: 0, startY: 0),
        await _store(),
      );
      expect(find.text('TAP TO START'), findsNothing);
    });
  });

  group('camera', () {
    testWidgets('a tap in the centre of the screen hits the start cell', (
      tester,
    ) async {
      final engine = engineFrom(_field, startX: 4, startY: 4);
      final session = GameSession(
        engine: engine,
        settings: const GameSettings(),
        store: await _store(),
      );
      final game = MinesweeperGame(session: session);

      tester.view.physicalSize = const Size(440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(body: GameWidget(game: game)),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(game.cellAtScreen(const Offset(220, 450)), engine.board.startIndex);
      session.dispose();
    });
  });
}
