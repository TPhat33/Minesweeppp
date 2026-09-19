import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';
import 'package:minesweeppp/core/models/board_record.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/ui/screens/result_sheet.dart';
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

Future<PlayerStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PlayerStore.open();
}

Future<void> _pumpSheet(
  WidgetTester tester,
  MinesweeperEngine engine, {
  PlayerStore? store,
  BoardRecord? target,
}) async {
  tester.view.physicalSize = const Size(440, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: ResultSheet(
          engine: engine,
          store: store ?? await _store(),
          target: target,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MinesweeperEngine _wonRun() {
  final engine = engineFrom(_field, startX: 0, startY: 0);
  engine.toggleFlag(1);
  engine.toggleSalvageSelection(1);
  engine.commitSalvage();
  for (var i = 0; i < engine.board.cellCount; i++) {
    if (!engine.board.isMine(i)) engine.reveal(i);
  }
  return engine;
}

MinesweeperEngine _badSalvageRun() {
  final engine = engineFrom(_field, startX: 0, startY: 0);
  engine.toggleFlag(8); // (8, 0) is not a mine
  engine.toggleSalvageSelection(8);
  engine.commitSalvage();
  return engine;
}

MinesweeperEngine _timeoutRun() {
  final engine = engineFrom(
    _field,
    startX: 0,
    startY: 0,
    mode: GameMode.timed,
  );
  engine.tick(Difficulty.beginner.timedSeconds.toDouble() + 1);
  return engine;
}

void main() {
  testWidgets('a win shows the clear headline and the salvage tally', (
    tester,
  ) async {
    final engine = _wonRun();
    await _pumpSheet(tester, engine);

    expect(find.text('BOARD CLEAR'), findsOneWidget);
    expect(find.textContaining('1 of 4 mines recovered'), findsOneWidget);
    expect(find.text('Same board'), findsOneWidget);
    expect(find.text('New board'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
  });

  testWidgets('a bad salvage explains what went wrong', (tester) async {
    await _pumpSheet(tester, _badSalvageRun());
    expect(find.text('BAD CALL'), findsOneWidget);
    expect(
      find.text('One of the cells in that batch was not a mine.'),
      findsOneWidget,
    );
  });

  testWidgets('running out of time says so', (tester) async {
    await _pumpSheet(tester, _timeoutRun());
    expect(find.text('OUT OF TIME'), findsOneWidget);
  });

  testWidgets('stepping on a mine says so', (tester) async {
    final engine = engineFrom(_field, startX: 0, startY: 0);
    engine.reveal(1);
    await _pumpSheet(tester, engine);
    expect(find.text('DETONATED'), findsOneWidget);
    expect(find.text('That cell was a mine.'), findsOneWidget);
  });

  testWidgets('the level code is shown so the board can be shared', (
    tester,
  ) async {
    final engine = engineFrom(_field, startX: 0, startY: 0, seed: 12345);
    engine.reveal(1);
    await _pumpSheet(tester, engine);

    expect(find.text('LEVEL CODE'), findsOneWidget);
    expect(find.text(engine.levelCode.encode()), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('beating the board\'s previous best shows a badge', (
    tester,
  ) async {
    final engine = _wonRun();
    final target = BoardRecord(
      code: engine.levelCode.encode(),
      difficulty: engine.difficulty,
      mode: engine.mode,
      seed: engine.seed,
      bestScore: 1,
      bestChain: 0,
      cleared: true,
      playCount: 1,
      updatedAtMs: 0,
    );
    await _pumpSheet(tester, engine, target: target);
    expect(find.text('NEW BEST'), findsOneWidget);
  });

  testWidgets('falling short of the previous best shows no badge', (
    tester,
  ) async {
    final engine = _wonRun();
    final target = BoardRecord(
      code: engine.levelCode.encode(),
      difficulty: engine.difficulty,
      mode: engine.mode,
      seed: engine.seed,
      bestScore: engine.score + 1000,
      bestChain: 0,
      cleared: true,
      playCount: 1,
      updatedAtMs: 0,
    );
    await _pumpSheet(tester, engine, target: target);
    expect(find.text('NEW BEST'), findsNothing);
  });

  testWidgets('shows the comparison card against own best and a rival', (
    tester,
  ) async {
    final engine = _wonRun();
    final target = BoardRecord(
      code: engine.levelCode.encode(),
      difficulty: engine.difficulty,
      mode: engine.mode,
      seed: engine.seed,
      bestScore: engine.score + 50,
      bestChain: 0,
      cleared: true,
      playCount: 2,
      rivalScore: engine.score - 20,
      updatedAtMs: 0,
    );
    await _pumpSheet(tester, engine, target: target);

    expect(find.textContaining('Your best on this board'), findsOneWidget);
    expect(find.textContaining('Rival score'), findsOneWidget);
  });

  testWidgets('pinning a board persists it through the store', (
    tester,
  ) async {
    final engine = _wonRun();
    final store = await _store();
    await store.recordBoard(engine);
    await _pumpSheet(tester, engine, store: store);

    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(store.boardFor(engine.levelCode)?.pinned, isTrue);
  });

  testWidgets('sharing copies a formatted result to the clipboard', (
    tester,
  ) async {
    final engine = _wonRun();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pumpSheet(tester, engine);
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(copied, contains(engine.levelCode.encode()));
    expect(find.text('Result copied'), findsOneWidget);
  });
}
