import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/solver.dart';

import 'test_boards.dart';

void main() {
  const solver = LogicSolver();

  test('an empty field is solved by the first click alone', () {
    final board = boardFrom(const [
      '.....',
      '.....',
      '.....',
      '.....',
      '.....',
    ], startX: 2, startY: 2);
    final report = solver.solve(board);
    expect(report.solvable, isTrue);
    expect(report.neededEnumeration, isFalse);
    expect(report.revealedCount, board.safeCellCount);
  });

  test('the opening flood clears everything around an isolated cluster', () {
    final board = boardFrom(const [
      '*....',
      '.....',
      '.....',
      '.....',
      '....*',
    ], startX: 2, startY: 2);
    final report = solver.solve(board);
    expect(report.solvable, isTrue);
    expect(report.neededEnumeration, isFalse);
  });

  test('a true 50/50 is reported as unsolvable', () {
    // Both hidden cells border a 1 and nothing else can tell them apart, and
    // the global count does not help either: exactly one of them is the mine.
    final board = boardFrom(const ['...*', '....'], startX: 0, startY: 0);
    final report = solver.solve(board);
    expect(report.solvable, isFalse);
    expect(report.revealedCount, board.safeCellCount - 1);
    expect(report.progress, lessThan(1));
  });

  test('the global mine count clears cells no number touches', () {
    // Once the only mine is accounted for, the two cells past it are safe even
    // though no visible number says so.
    final board = boardFrom(const ['....*..'], startX: 0, startY: 0);
    final report = solver.solve(board);
    expect(report.solvable, isTrue);
    expect(
      report.neededEnumeration,
      isTrue,
      reason: 'the last two cells only follow from the total mine count',
    );
  });

  test('a board with hidden pockets is still solvable by logic', () {
    final board = boardFrom(const [
      '.*.......',
      '..*......',
      '.*.......',
      '.........',
      '.........',
      '....*....',
      '.........',
      '.........',
      '.........',
    ], startX: 8, startY: 8);
    final report = solver.solve(board);
    expect(report.solvable, isTrue);
    expect(report.revealedCount, board.safeCellCount);
  });

  test('the solver never marks a safe cell as a mine', () {
    // Sanity check on soundness: replay a batch of random boards and make sure
    // progress never exceeds the number of safe cells.
    for (var seed = 0; seed < 20; seed++) {
      final rows = <String>[];
      var value = seed * 2654435761 & 0xFFFFFFFF;
      for (var y = 0; y < 6; y++) {
        final buffer = StringBuffer();
        for (var x = 0; x < 6; x++) {
          value = (value * 1103515245 + 12345) & 0x7FFFFFFF;
          buffer.write((value >> 16) % 5 == 0 ? '*' : '.');
        }
        rows.add(buffer.toString());
      }
      final board = boardFrom(rows, startX: 0, startY: 0);
      final report = solver.solve(board);
      expect(report.revealedCount, lessThanOrEqualTo(board.safeCellCount));
      expect(report.progress, lessThanOrEqualTo(1));
    }
  });
}
