import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/ui/screens/game_screen.dart';
import 'package:minesweeppp/ui/screens/home_screen.dart';
import 'package:minesweeppp/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/test_boards.dart';

/// Small enough that a saved run built from it stands in for a real one
/// without paying for a real Master-sized board generation.
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

Future<PlayerStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PlayerStore.open();
}

Future<void> _pumpHome(WidgetTester tester, PlayerStore store) async {
  // A tall phone-shaped surface so the whole menu is laid out at once.
  tester.view.physicalSize = const Size(440, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.build(), home: HomeScreen(store: store)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every difficulty and both modes', (tester) async {
    await _pumpHome(tester, await _store());

    for (final difficulty in Difficulty.values) {
      expect(find.text(difficulty.label), findsOneWidget);
    }
    for (final mode in GameMode.values) {
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(find.text('START RUN'), findsOneWidget);
  });

  testWidgets('shows the mine count and density for each preset', (
    tester,
  ) async {
    await _pumpHome(tester, await _store());
    expect(find.textContaining('9x9 · 10 mines'), findsOneWidget);
    expect(find.textContaining('32x24 · 175 mines'), findsOneWidget);
  });

  testWidgets('offers the level code and records entry points', (tester) async {
    await _pumpHome(tester, await _store());
    expect(find.text('Level code'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
  });

  testWidgets('a difficulty can be selected', (tester) async {
    await _pumpHome(tester, await _store());
    await tester.tap(find.text(Difficulty.expert.label));
    await tester.pumpAndSettle();
    // Selection is visual only; the important part is that it does not throw
    // and the tile is still there to start a run from.
    expect(find.text(Difficulty.expert.label), findsOneWidget);
  });

  testWidgets('rejects an invalid level code', (tester) async {
    await _pumpHome(tester, await _store());
    await tester.tap(find.text('Level code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-code');
    await tester.tap(find.text('Play it'));
    await tester.pumpAndSettle();

    expect(find.text('That code is not valid.'), findsOneWidget);
  });

  testWidgets('no resume card without a saved run', (tester) async {
    await _pumpHome(tester, await _store());
    expect(find.text('Run in progress'), findsNothing);
  });

  // GameScreen hosts a live Flame game loop, which schedules a frame every
  // tick and so never goes idle — pumpAndSettle() would spin forever once
  // we've navigated into it. A bounded pump stands in for it instead.
  Future<void> settleFrames(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  // Board generation goes through compute(), which on the VM spawns a real
  // isolate — genuine cross-isolate communication, not something the fake
  // clock behind tester.pump() advances. tester.runAsync() steps outside
  // that fake clock so the real await actually resolves, matching the
  // pattern Flutter's own docs use for testing other real-async APIs.
  Future<void> waitForRealAsyncWork(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
  }

  testWidgets('a tap on START RUN opens exactly one game screen', (
    tester,
  ) async {
    await _pumpHome(tester, await _store());
    await tester.tap(find.text('START RUN'));
    await tester.pump();
    await waitForRealAsyncWork(tester);
    await settleFrames(tester);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets(
    'tapping START RUN twice before it navigates never opens two game '
    'screens',
    (tester) async {
      // Regression test: the generating dialog used to fire-and-forget
      // (`unawaited(showDialog(...))`) while separately awaiting board
      // generation, which raced on web — generation could finish inside a
      // single microtask, popping and re-pushing routes out of order. A
      // second tap landing in that window used to be able to start a second
      // run stacked on top of the first. Fixed by (a) the dialog owning its
      // own generate-then-pop sequence as one Future, and (b) a `_busy` flag
      // that makes the button a no-op while a run is already starting.
      await _pumpHome(tester, await _store());

      final startRun = find.text('START RUN');
      await tester.tap(startRun);
      // No pump in between: both taps land before the first has navigated,
      // which is exactly the window the fix closes.
      await tester.tap(startRun, warnIfMissed: false);
      await tester.pump();
      await waitForRealAsyncWork(tester);
      await settleFrames(tester);

      expect(find.byType(GameScreen), findsOneWidget);
    },
  );

  group('a saved run', () {
    // Regression coverage: a leftover saved run used to sync straight into
    // _difficulty/_mode on load, so a Master save from days ago made an
    // unrelated tap on START RUN silently hand back a Master board — with no
    // warning that doing so also threw the saved run away. Fixed by leaving
    // the tiles alone and gating any new run behind a confirm dialog.
    Future<PlayerStore> storeWithSavedRun() async {
      final store = await _store();
      final saved = engineFrom(
        _field,
        startX: 0,
        startY: 0,
        difficulty: Difficulty.master,
        mode: GameMode.timed,
      );
      await store.saveRun(saved);
      return store;
    }

    testWidgets('shows the save on its own Resume card', (tester) async {
      await _pumpHome(tester, await storeWithSavedRun());
      expect(find.text('Run in progress'), findsOneWidget);
      expect(find.textContaining('Master · Timed'), findsOneWidget);
      // Beginner is still the default preset, untouched by the save — the
      // decisive check that START RUN itself builds Beginner, not Master, is
      // below ("confirming START RUN builds a Beginner run, not Master").
      expect(find.text(Difficulty.beginner.label), findsOneWidget);
    });

    testWidgets('START RUN asks before discarding it, and honours cancel', (
      tester,
    ) async {
      final store = await storeWithSavedRun();
      await _pumpHome(tester, store);

      await tester.tap(find.text('START RUN'));
      await tester.pump();

      expect(find.text('Start a new run?'), findsOneWidget);
      expect(find.textContaining('Master · Timed'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.byType(GameScreen), findsNothing);
      expect(find.text('Run in progress'), findsOneWidget);
      expect(store.loadSavedRun(), isNotNull);
    });

    testWidgets('confirming START RUN builds a Beginner run, not Master', (
      tester,
    ) async {
      await _pumpHome(tester, await storeWithSavedRun());

      await tester.tap(find.text('START RUN'));
      await tester.pump();
      await tester.tap(find.text('Start new'));
      await tester.pump();
      await waitForRealAsyncWork(tester);
      await settleFrames(tester);

      final gameScreen = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(gameScreen.engine.difficulty, Difficulty.beginner);
      expect(gameScreen.engine.mode, GameMode.classic);
    });

    testWidgets('a level code also asks before discarding a saved run', (
      tester,
    ) async {
      await _pumpHome(tester, await storeWithSavedRun());

      await tester.tap(find.text('Level code'));
      await tester.pumpAndSettle();
      final code = engineFrom(
        _field,
        startX: 0,
        startY: 0,
      ).levelCode.encode();
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text('Play it'));
      await tester.pumpAndSettle();

      expect(find.text('Start a new run?'), findsOneWidget);
    });
  });
}
