import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/level_code.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';
import 'package:minesweeppp/game/game_factory.dart';

void main() {
  test('creates a playable run with the opening cell already open', () async {
    final engine = await GameFactory.create(
      difficulty: Difficulty.beginner,
      mode: GameMode.timed,
      seed: 4242,
    );

    expect(engine.difficulty, Difficulty.beginner);
    expect(engine.mode, GameMode.timed);
    expect(engine.seed, 4242);
    expect(engine.noGuess, isTrue);
    expect(engine.status, GameStatus.playing);
    expect(engine.stateOf(engine.board.startIndex), CellState.revealed);
    expect(engine.revealedCount, greaterThan(1));
    expect(engine.secondsRemaining, Difficulty.beginner.timedSeconds);
  });

  test('a level code reproduces the same run', () async {
    final first = await GameFactory.create(
      difficulty: Difficulty.intermediate,
      mode: GameMode.classic,
      seed: 99001,
    );
    final second = await GameFactory.fromCode(
      LevelCode.tryDecode(first.levelCode.encode())!,
    );

    expect(second.board.startIndex, first.board.startIndex);
    expect(second.mode, first.mode);
    expect(second.difficulty, first.difficulty);
    for (var i = 0; i < first.board.cellCount; i++) {
      expect(second.board.isMine(i), first.board.isMine(i));
    }
  });

  test('random seeds stay inside the level code range', () {
    for (var i = 0; i < 200; i++) {
      final seed = GameFactory.randomSeed();
      expect(seed, inInclusiveRange(0, 0xFFFFFFFF));
    }
  });
}
