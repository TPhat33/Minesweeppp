import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';
import 'package:minesweeppp/core/models/game_settings.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/ui/screens/game_screen.dart';
import 'package:minesweeppp/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/test_boards.dart';

/// Start on (4, 4): it reads 1, so nothing floods and every assertion below is
/// about exactly one cell.
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

const Offset _boardCentre = Offset(220, 450);

Future<MinesweeperEngine> _pumpGame(
  WidgetTester tester, {
  GameSettings settings = const GameSettings(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await PlayerStore.open();
  final engine = engineFrom(_field, startX: 4, startY: 4);

  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: GameScreen(engine: engine, settings: settings, store: store),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return engine;
}

Future<void> _settleFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a tap on the board opens exactly one cell', (tester) async {
    final engine = await _pumpGame(tester);
    final before = engine.revealedCount;

    // One cell to the right of the opening cell.
    await tester.tapAt(_boardCentre + const Offset(49, 0));
    await _settleFrames(tester);

    expect(engine.revealedCount, before + 1);
  });

  testWidgets('dragging pans the board without opening anything', (
    tester,
  ) async {
    final engine = await _pumpGame(tester);
    final before = engine.revealedCount;

    await tester.dragFrom(_boardCentre, const Offset(0, -140));
    await _settleFrames(tester);

    expect(
      engine.revealedCount,
      before,
      reason: 'scrolling the board must never open a cell',
    );
    expect(engine.flagCount, 0);
  });

  testWidgets('a long press flags while the board is in open mode', (
    tester,
  ) async {
    final engine = await _pumpGame(tester);
    expect(engine.flagCount, 0);

    await tester.longPressAt(_boardCentre + const Offset(49, 0));
    await _settleFrames(tester);

    expect(engine.flagCount, 1);
    expect(engine.revealedCount, 1, reason: 'only the opening cell is open');
  });

  testWidgets('long press can be turned off', (tester) async {
    final engine = await _pumpGame(
      tester,
      settings: const GameSettings(longPressToFlag: false),
    );

    await tester.longPressAt(_boardCentre + const Offset(49, 0));
    await _settleFrames(tester);

    expect(engine.flagCount, 0);
  });

  testWidgets('tapping a flag puts it in the salvage batch', (tester) async {
    final engine = await _pumpGame(tester);
    final target = _boardCentre + const Offset(0, 49); // the mine at (4, 5)

    await tester.longPressAt(target);
    await _settleFrames(tester);
    expect(engine.flagCount, 1);

    await tester.tapAt(target);
    await _settleFrames(tester);
    expect(engine.selectionSize, 1);

    // Tapping again takes it back out.
    await tester.tapAt(target);
    await _settleFrames(tester);
    expect(engine.selectionSize, 0);
  });

  testWidgets('in flag mode a tap flags instead of opening', (tester) async {
    final engine = await _pumpGame(tester);

    await tester.tap(find.text('Flag'));
    await _settleFrames(tester);

    await tester.tapAt(_boardCentre + const Offset(49, 0));
    await _settleFrames(tester);

    expect(engine.flagCount, 1);
    expect(engine.revealedCount, 1);
  });

  testWidgets('salvaging a correctly flagged mine scores and continues', (
    tester,
  ) async {
    final engine = await _pumpGame(
      tester,
      settings: const GameSettings(confirmSalvage: false),
    );
    final mine = _boardCentre + const Offset(0, 49);

    await tester.longPressAt(mine);
    await _settleFrames(tester);
    await tester.tapAt(mine);
    await _settleFrames(tester);
    expect(engine.selectionSize, 1);

    await tester.tap(find.text('SALVAGE'));
    await _settleFrames(tester, frames: 20);

    expect(engine.salvagedCount, 1);
    expect(engine.status, GameStatus.playing);
    expect(engine.score, greaterThanOrEqualTo(GameRules.salvageScore(1)));
  });
}
