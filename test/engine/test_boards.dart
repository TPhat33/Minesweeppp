import 'package:minesweeppp/core/engine/board.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';

/// Builds a board from an ASCII picture: `*` is a mine, anything else is safe.
Board boardFrom(List<String> rows, {required int startX, required int startY}) {
  final height = rows.length;
  final width = rows.first.length;
  final mines = <bool>[];
  for (final row in rows) {
    assert(row.length == width, 'all rows must be the same width');
    for (final char in row.split('')) {
      mines.add(char == '*');
    }
  }
  return Board.fromMines(
    width: width,
    height: height,
    mines: mines,
    startIndex: startY * width + startX,
  );
}

MinesweeperEngine engineFrom(
  List<String> rows, {
  required int startX,
  required int startY,
  Difficulty difficulty = Difficulty.beginner,
  GameMode mode = GameMode.classic,
  int seed = 1,
}) {
  return MinesweeperEngine(
    board: boardFrom(rows, startX: startX, startY: startY),
    difficulty: difficulty,
    mode: mode,
    seed: seed,
    noGuess: true,
  );
}
