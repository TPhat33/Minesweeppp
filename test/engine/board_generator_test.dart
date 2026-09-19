import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/board_generator.dart';
import 'package:minesweeppp/core/engine/deterministic_random.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/solver.dart';

void main() {
  const generator = BoardGenerator();

  test('the same seed always builds the same board', () {
    final a = generator.generate(difficulty: Difficulty.intermediate, seed: 4242);
    final b = generator.generate(difficulty: Difficulty.intermediate, seed: 4242);

    expect(a.board.startIndex, b.board.startIndex);
    expect(a.noGuess, b.noGuess);
    for (var i = 0; i < a.board.cellCount; i++) {
      expect(a.board.isMine(i), b.board.isMine(i));
    }
  });

  test('different seeds build different boards', () {
    final a = generator.generate(difficulty: Difficulty.beginner, seed: 1);
    final b = generator.generate(difficulty: Difficulty.beginner, seed: 2);
    final same = [
      for (var i = 0; i < a.board.cellCount; i++)
        if (a.board.isMine(i) == b.board.isMine(i)) i,
    ];
    expect(same.length, lessThan(a.board.cellCount));
  });

  test('the board always has the requested number of mines', () {
    for (final difficulty in Difficulty.values) {
      final generated = generator.generate(difficulty: difficulty, seed: 7);
      expect(generated.board.mineCount, difficulty.mineCount);
      expect(generated.board.width, difficulty.width);
      expect(generated.board.height, difficulty.height);
    }
  });

  test('the start cell is safe and opens an area', () {
    for (final difficulty in Difficulty.values) {
      final generated = generator.generate(difficulty: difficulty, seed: 99);
      final start = generated.board.startIndex;
      expect(generated.board.isMine(start), isFalse);
      expect(
        generated.board.adjacentMines(start),
        0,
        reason: 'the opening move should never be a lone number',
      );
    }
  });

  test('generated boards are solvable without guessing', () {
    const solver = LogicSolver();
    for (final difficulty in Difficulty.values) {
      for (final seed in [11, 202, 30303]) {
        final generated = generator.generate(difficulty: difficulty, seed: seed);
        expect(
          generated.noGuess,
          isTrue,
          reason:
              '${difficulty.label} seed $seed fell back to a guessing board '
              'after ${generated.attempts} attempts',
        );
        expect(solver.solve(generated.board).solvable, isTrue);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('generateAsync returns the same board as the inline path', () async {
    // Boards cross an isolate boundary on the way back to the UI, so this
    // guards against a Board that cannot be sent.
    final inline = generator.generate(
      difficulty: Difficulty.beginner,
      seed: 777,
    );
    final offThread = await BoardGenerator.generateAsync(
      difficulty: Difficulty.beginner,
      seed: 777,
    );

    expect(offThread.seed, inline.seed);
    expect(offThread.noGuess, isTrue);
    expect(offThread.board.startIndex, inline.board.startIndex);
    expect(offThread.board.mineCount, Difficulty.beginner.mineCount);
    for (var i = 0; i < inline.board.cellCount; i++) {
      expect(offThread.board.isMine(i), inline.board.isMine(i));
      expect(offThread.board.adjacentMines(i), inline.board.adjacentMines(i));
    }
  });

  group('deterministic random', () {
    test('produces the same stream for the same seed', () {
      final a = DeterministicRandom(12345);
      final b = DeterministicRandom(12345);
      for (var i = 0; i < 50; i++) {
        expect(a.nextUint32(), b.nextUint32());
      }
    });

    test('nextInt stays in range', () {
      final rng = DeterministicRandom(7);
      for (var i = 0; i < 2000; i++) {
        final value = rng.nextInt(17);
        expect(value, inInclusiveRange(0, 16));
      }
    });

    test('shuffle is a permutation', () {
      final rng = DeterministicRandom(3);
      final values = List<int>.generate(100, (i) => i);
      rng.shuffle(values);
      expect(values.toSet().length, 100);
      expect(values, isNot(List<int>.generate(100, (i) => i)));
    });

    test('a zero seed still works', () {
      final rng = DeterministicRandom(0);
      expect(rng.nextUint32(), isNot(0));
    });
  });
}
