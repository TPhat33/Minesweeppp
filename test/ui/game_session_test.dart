import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';
import 'package:minesweeppp/core/models/game_settings.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/game/game_session.dart';
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

const _mineA = 1; // (1, 0)
int at(int x, int y) => y * 9 + x;

Future<GameSession> _session({
  GameSettings settings = const GameSettings(),
  GameMode mode = GameMode.classic,
}) async {
  SharedPreferences.setMockInitialValues({});
  return GameSession(
    engine: engineFrom(_field, startX: 0, startY: 0, mode: mode),
    settings: settings,
    store: await PlayerStore.open(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tap routing', () {
    test('a hidden cell opens in open mode', () async {
      final session = await _session();
      session.tapCell(at(8, 8));
      expect(session.engine.revealedCount, greaterThan(1));
      session.dispose();
    });

    test('a hidden cell is flagged in flag mode', () async {
      final session = await _session();
      session.setInputMode(InputMode.flag);
      session.tapCell(_mineA);
      expect(session.engine.stateOf(_mineA), CellState.flagged);
      session.dispose();
    });

    test('a flag joins the batch in open mode', () async {
      final session = await _session();
      session.longPressCell(_mineA);
      expect(session.engine.stateOf(_mineA), CellState.flagged);
      session.tapCell(_mineA);
      expect(session.engine.selectionSize, 1);
      session.dispose();
    });

    test('a flag is removed in flag mode', () async {
      final session = await _session();
      session.setInputMode(InputMode.flag);
      session.tapCell(_mineA);
      session.tapCell(_mineA);
      expect(session.engine.stateOf(_mineA), CellState.hidden);
      session.dispose();
    });

    test('an open number chords', () async {
      final session = await _session();
      session.longPressCell(_mineA);
      session.tapCell(at(0, 0));
      expect(session.engine.stateOf(at(0, 1)), CellState.revealed);
      session.dispose();
    });

    test('long press can be disabled', () async {
      final session = await _session(
        settings: const GameSettings(longPressToFlag: false),
      );
      session.longPressCell(_mineA);
      expect(session.engine.stateOf(_mineA), CellState.hidden);
      session.dispose();
    });

    test('nothing happens while paused', () async {
      final session = await _session();
      session.setPaused(true);
      session.tapCell(at(8, 8));
      expect(session.engine.revealedCount, 1);
      session.dispose();
    });
  });

  group('chord preview', () {
    test('lists the cells a chord would open', () async {
      final session = await _session();
      session.longPressCell(_mineA);
      session.previewChord(at(0, 0));
      expect(session.chordPreview, [at(0, 1), at(1, 1)]);
      session.previewChord(null);
      expect(session.chordPreview, isEmpty);
      session.dispose();
    });

    test('is empty for an unsatisfied number', () async {
      final session = await _session();
      session.previewChord(at(0, 0));
      expect(session.chordPreview, isEmpty);
      session.dispose();
    });
  });

  group('effects sink', () {
    test('every change is reported once', () async {
      final session = await _session();
      final kinds = <String>[];
      session.onMove = (result) => kinds.add(result.kind.name);

      session.tapCell(at(8, 8));
      session.longPressCell(_mineA);
      session.tapCell(_mineA);
      session.commitSalvage();

      expect(kinds, ['reveal', 'flag', 'select', 'salvage']);
      session.dispose();
    });

    test('a move that changes nothing is not reported', () async {
      final session = await _session();
      var calls = 0;
      session.onMove = (_) => calls++;
      session.tapCell(at(0, 0)); // already open, nothing to chord
      expect(calls, 0);
      session.dispose();
    });
  });

  group('clock', () {
    test('ticking runs the timed clock down', () async {
      final session = await _session(mode: GameMode.timed);
      final before = session.engine.secondsRemaining;
      session.tick(5);
      expect(session.engine.secondsRemaining, lessThan(before));
      session.dispose();
    });

    test('a paused run does not tick', () async {
      final session = await _session(mode: GameMode.timed);
      session.setPaused(true);
      final before = session.engine.secondsRemaining;
      session.tick(5);
      expect(session.engine.secondsRemaining, before);
      session.dispose();
    });

    test('an energy boost needs energy', () async {
      final session = await _session(mode: GameMode.timed);
      final before = session.engine.secondsRemaining;
      session.spendEnergyForTime();
      expect(session.engine.secondsRemaining, before);
      session.dispose();
    });

    test('a held run does not tick, and releasing it lets the clock run', () async {
      final session = await _session(mode: GameMode.timed);
      expect(session.held, isFalse);

      session.hold();
      expect(session.held, isTrue);
      final before = session.engine.secondsRemaining;
      session.tick(5);
      expect(session.engine.secondsRemaining, before);

      session.release();
      expect(session.held, isFalse);
      session.tick(5);
      expect(session.engine.secondsRemaining, lessThan(before));
      session.dispose();
    });
  });

  test('a finished run is recorded and the save is cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PlayerStore.open();
    final engine = engineFrom(_field, startX: 0, startY: 0);
    final session = GameSession(
      engine: engine,
      settings: const GameSettings(),
      store: store,
    );

    await session.save();
    expect(store.loadSavedRun(), isNotNull);

    session.tapCell(_mineA); // steps on a mine
    expect(engine.status, GameStatus.lost);
    await Future<void>.delayed(Duration.zero);

    expect(store.loadSavedRun(), isNull);
    expect(store.statsFor(Difficulty.beginner, GameMode.classic).played, 1);
    session.dispose();
  });
}
