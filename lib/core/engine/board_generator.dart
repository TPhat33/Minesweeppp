import 'dart:isolate';

import 'board.dart';
import 'deterministic_random.dart';
import 'game_rules.dart';
import 'solver.dart';

/// A board plus how sure we are that it never asks the player to guess.
class GeneratedBoard {
  const GeneratedBoard({
    required this.board,
    required this.seed,
    required this.noGuess,
    required this.attempts,
    required this.elapsed,
  });

  final Board board;
  final int seed;

  /// True when [LogicSolver] proved the board can be cleared by logic alone.
  final bool noGuess;

  /// How many layouts were tried. Useful when tuning mine density.
  final int attempts;

  final Duration elapsed;
}

/// Builds boards from a seed and keeps trying until the solver can clear them
/// without a single guess.
///
/// Two strategies, because neither is good enough alone:
///
/// * reroll the whole minefield — cheap, and at Beginner density the first try
///   almost always works;
/// * when a layout came close (only a small pocket left undecided), move one
///   mine inside that pocket and try again, instead of throwing away a board
///   that was one ambiguity away from perfect. This is what keeps Legendary
///   generation in the hundreds of milliseconds rather than the tens of
///   seconds.
///
/// The start cell is drawn first and never changes between attempts, because
/// it is part of the level code: two players sharing a code must get the same
/// opening as well as the same mines.
class BoardGenerator {
  const BoardGenerator({
    this.maxSolves = 4000,
    this.budget = const Duration(seconds: 8),
    this.polishThreshold = 32,
    this.polishAttempts = 40,
    this.solver = const LogicSolver(),
  });

  /// Upper bound on solver runs, across rerolls and repairs.
  final int maxSolves;

  final Duration budget;

  /// Only bother repairing a layout whose undecided pocket is at most this
  /// many cells; anything bigger is faster to replace than to fix.
  final int polishThreshold;

  /// How many single-mine moves to try on one promising layout.
  final int polishAttempts;

  final LogicSolver solver;

  GeneratedBoard generate({required Difficulty difficulty, required int seed}) {
    final stopwatch = Stopwatch()..start();
    final rng = DeterministicRandom(seed);
    final width = difficulty.width;
    final height = difficulty.height;
    final cellCount = width * height;

    final startIndex = _pickStart(rng, width, height);
    final placeable = _placeableCells(width, height, startIndex);

    List<bool>? best;
    var bestUndecided = cellCount + 1;
    var solves = 0;

    GeneratedBoard finish(List<bool> mines, bool noGuess) {
      stopwatch.stop();
      return GeneratedBoard(
        board: _toBoard(mines, width, height, startIndex),
        seed: seed,
        noGuess: noGuess,
        attempts: solves,
        elapsed: stopwatch.elapsed,
      );
    }

    while (solves < maxSolves && stopwatch.elapsed < budget) {
      var mines = _randomLayout(
        rng: rng,
        cellCount: cellCount,
        placeable: placeable,
        mineCount: difficulty.mineCount,
      );
      var report = solver.solve(_toBoard(mines, width, height, startIndex));
      solves++;
      if (report.solvable) return finish(mines, true);

      // Nearly there? Nudge one mine around inside the undecided pocket.
      var repairs = 0;
      while (report.stuckCells.length <= polishThreshold &&
          repairs < polishAttempts &&
          solves < maxSolves &&
          stopwatch.elapsed < budget) {
        repairs++;
        final moved = _moveOneMine(mines, report.stuckCells, rng);
        if (moved == null) break;
        final next = solver.solve(_toBoard(moved, width, height, startIndex));
        solves++;
        if (next.solvable) return finish(moved, true);
        // Keep the move when it did not make the pocket worse, so the search
        // drifts towards layouts with less ambiguity.
        if (next.stuckCells.length <= report.stuckCells.length) {
          mines = moved;
          report = next;
        }
      }

      if (report.stuckCells.length < bestUndecided) {
        bestUndecided = report.stuckCells.length;
        best = mines;
      }
    }

    // Out of budget. Hand back the layout that came closest: it still has a
    // safe opening, and the HUD warns that this one may need a guess.
    return finish(
      best ??
          _randomLayout(
            rng: rng,
            cellCount: cellCount,
            placeable: placeable,
            mineCount: difficulty.mineCount,
          ),
      false,
    );
  }

  /// Same as [generate], off the UI thread, so a slow Legendary roll never
  /// costs a frame.
  ///
  /// Dart VM only — `dart:isolate` has no web implementation, so this throws
  /// `UnsupportedError` when compiled for the browser. The Flutter app uses
  /// [package:flutter/foundation.dart]'s `compute()` instead (see
  /// `lib/game/game_factory.dart`), which knows how to fall back to running
  /// inline on web. This method stays for plain-Dart callers — a CLI tool, a
  /// script, a non-Flutter test — where a real isolate is available.
  static Future<GeneratedBoard> generateAsync({
    required Difficulty difficulty,
    required int seed,
    Duration budget = const Duration(seconds: 8),
  }) {
    return Isolate.run(
      () => BoardGenerator(
        budget: budget,
      ).generate(difficulty: difficulty, seed: seed),
    );
  }

  /// Moves a single mine to another cell inside the undecided pocket. Keeping
  /// the move inside the pocket leaves the rest of the board — and everything
  /// the solver already worked out about it — alone.
  List<bool>? _moveOneMine(
    List<bool> mines,
    List<int> pocket,
    DeterministicRandom rng,
  ) {
    final occupied = [for (final c in pocket) if (mines[c]) c];
    final free = [for (final c in pocket) if (!mines[c]) c];
    if (occupied.isEmpty || free.isEmpty) return null;
    final next = List<bool>.from(mines);
    next[occupied[rng.nextInt(occupied.length)]] = false;
    next[free[rng.nextInt(free.length)]] = true;
    return next;
  }

  int _pickStart(DeterministicRandom rng, int width, int height) {
    // Bias away from the very edge: openings there are cramped and make the
    // first deductions harder than they need to be.
    final x = 1 + rng.nextInt(width - 2);
    final y = 1 + rng.nextInt(height - 2);
    return y * width + x;
  }

  /// Every cell a mine may occupy: the 3x3 block around the start stays clear
  /// so the opening move always reads zero and floods.
  List<int> _placeableCells(int width, int height, int startIndex) {
    final sx = startIndex % width;
    final sy = startIndex ~/ width;
    return [
      for (var i = 0; i < width * height; i++)
        if (((i % width) - sx).abs() > 1 || ((i ~/ width) - sy).abs() > 1) i,
    ];
  }

  List<bool> _randomLayout({
    required DeterministicRandom rng,
    required int cellCount,
    required List<int> placeable,
    required int mineCount,
  }) {
    final pool = List<int>.from(placeable);
    rng.shuffle(pool);
    final mines = List<bool>.filled(cellCount, false);
    for (var i = 0; i < mineCount; i++) {
      mines[pool[i]] = true;
    }
    return mines;
  }

  Board _toBoard(List<bool> mines, int width, int height, int startIndex) {
    return Board.fromMines(
      width: width,
      height: height,
      mines: mines,
      startIndex: startIndex,
    );
  }
}
