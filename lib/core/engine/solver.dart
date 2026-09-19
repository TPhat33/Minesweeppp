import 'dart:typed_data';

import 'board.dart';

/// What the solver knows about a cell while it replays a board.
abstract final class Knowledge {
  static const int unknown = 0;
  static const int safe = 1;
  static const int mine = 2;
}

/// Result of replaying a board with pure logic.
class SolveReport {
  const SolveReport({
    required this.solvable,
    required this.revealedCount,
    required this.safeCellCount,
    required this.neededEnumeration,
    required this.hitSearchLimit,
    required this.stuckCells,
  });

  /// True when every safe cell can be opened without ever guessing.
  final bool solvable;

  final int revealedCount;
  final int safeCellCount;

  /// True when the simple and subset rules alone were not enough — the board
  /// needs "count the possibilities" reasoning somewhere.
  final bool neededEnumeration;

  /// True when a constraint group was too large to enumerate. The board may
  /// still be solvable; the solver simply gave up on proving it.
  final bool hitSearchLimit;

  /// Cells the solver could not decide. The generator perturbs exactly this
  /// region instead of rerolling the whole board.
  final List<int> stuckCells;

  double get progress => safeCellCount == 0 ? 1 : revealedCount / safeCellCount;
}

/// A deterministic Minesweeper solver.
///
/// It only ever makes deductions that are forced, so "solvable" here means
/// "beatable without guessing" — which is exactly the property we promise the
/// player. Three layers of reasoning, cheapest first:
///
/// 1. single-constraint rules (a 2 with two unknowns left is two mines),
/// 2. the subset rule between overlapping constraints (the 1-2-1 family),
/// 3. exhaustive enumeration per constraint group, cross-checked against the
///    global mine count (this is what cracks the endgame corners).
class LogicSolver {
  const LogicSolver({
    this.maxGroupCells = 24,
    this.maxAssignmentsPerGroup = 400000,
  });

  /// Constraint groups larger than this are left alone: enumeration cost grows
  /// exponentially and real boards rarely need it.
  final int maxGroupCells;

  /// Safety valve for pathological groups.
  final int maxAssignmentsPerGroup;

  SolveReport solve(Board board) {
    final knowledge = Uint8List(board.cellCount);
    final revealed = Uint8List(board.cellCount);
    var revealedCount = 0;
    var neededEnumeration = false;
    var hitSearchLimit = false;

    revealedCount += _floodReveal(board, board.startIndex, knowledge, revealed);

    while (revealedCount < board.safeCellCount) {
      final safeFound = <int>{};
      final minesFound = <int>{};

      final constraints = _buildConstraints(board, knowledge, revealed);
      _applySimpleRules(constraints, safeFound, minesFound);

      if (safeFound.isEmpty && minesFound.isEmpty) {
        _applySubsetRule(constraints, safeFound, minesFound);
      }

      if (safeFound.isEmpty && minesFound.isEmpty) {
        neededEnumeration = true;
        final limited = _applyEnumeration(
          board,
          knowledge,
          constraints,
          safeFound,
          minesFound,
        );
        hitSearchLimit = hitSearchLimit || limited;
      }

      if (safeFound.isEmpty && minesFound.isEmpty) break;

      for (final index in minesFound) {
        knowledge[index] = Knowledge.mine;
      }
      for (final index in safeFound) {
        if (revealed[index] == 1) continue;
        revealedCount += _floodReveal(board, index, knowledge, revealed);
      }
    }

    final solved = revealedCount >= board.safeCellCount;
    return SolveReport(
      solvable: solved,
      revealedCount: revealedCount,
      safeCellCount: board.safeCellCount,
      neededEnumeration: neededEnumeration,
      hitSearchLimit: hitSearchLimit,
      stuckCells: solved
          ? const []
          : [
              for (var i = 0; i < board.cellCount; i++)
                if (knowledge[i] == Knowledge.unknown) i,
            ],
    );
  }

  int _floodReveal(
    Board board,
    int index,
    Uint8List knowledge,
    Uint8List revealed,
  ) {
    if (board.isMine(index) || revealed[index] == 1) return 0;
    var count = 0;
    final stack = <int>[index];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (revealed[current] == 1) continue;
      revealed[current] = 1;
      knowledge[current] = Knowledge.safe;
      count++;
      if (board.adjacentMines(current) != 0) continue;
      for (final n in board.neighbours(current)) {
        if (revealed[n] == 0 && !board.isMine(n)) stack.add(n);
      }
    }
    return count;
  }

  List<_Constraint> _buildConstraints(
    Board board,
    Uint8List knowledge,
    Uint8List revealed,
  ) {
    final constraints = <_Constraint>[];
    for (var i = 0; i < board.cellCount; i++) {
      if (revealed[i] == 0) continue;
      final number = board.adjacentMines(i);
      if (number == 0) continue;
      var knownMines = 0;
      final unknown = <int>[];
      for (final n in board.neighbours(i)) {
        switch (knowledge[n]) {
          case Knowledge.mine:
            knownMines++;
          case Knowledge.unknown:
            unknown.add(n);
        }
      }
      if (unknown.isEmpty) continue;
      constraints.add(_Constraint(unknown, number - knownMines));
    }
    return constraints;
  }

  void _applySimpleRules(
    List<_Constraint> constraints,
    Set<int> safeFound,
    Set<int> minesFound,
  ) {
    for (final c in constraints) {
      if (c.mines == 0) {
        safeFound.addAll(c.cells);
      } else if (c.mines == c.cells.length) {
        minesFound.addAll(c.cells);
      }
    }
  }

  void _applySubsetRule(
    List<_Constraint> constraints,
    Set<int> safeFound,
    Set<int> minesFound,
  ) {
    for (var a = 0; a < constraints.length; a++) {
      for (var b = 0; b < constraints.length; b++) {
        if (a == b) continue;
        final small = constraints[a];
        final large = constraints[b];
        if (small.cells.length >= large.cells.length) continue;
        if (!large.containsAll(small)) continue;
        final diff = large.cells.where((c) => !small.cellSet.contains(c)).toList();
        final diffMines = large.mines - small.mines;
        if (diffMines == 0) {
          safeFound.addAll(diff);
        } else if (diffMines == diff.length) {
          minesFound.addAll(diff);
        }
      }
    }
  }

  /// Enumerates every mine layout consistent with the visible numbers, group by
  /// group, then keeps only the layouts that can still add up to the global
  /// mine count. Cells that are a mine in every survivor are mines; cells that
  /// are clear in every survivor are safe.
  ///
  /// Returns true when some group was too big to enumerate.
  bool _applyEnumeration(
    Board board,
    Uint8List knowledge,
    List<_Constraint> constraints,
    Set<int> safeFound,
    Set<int> minesFound,
  ) {
    var knownMines = 0;
    final unknownCells = <int>[];
    for (var i = 0; i < board.cellCount; i++) {
      switch (knowledge[i]) {
        case Knowledge.mine:
          knownMines++;
        case Knowledge.unknown:
          unknownCells.add(i);
      }
    }
    final remainingMines = board.mineCount - knownMines;

    final frontier = <int>{for (final c in constraints) ...c.cells};
    final outerCells = unknownCells.where((c) => !frontier.contains(c)).toList();

    if (constraints.isEmpty) {
      if (remainingMines == 0) {
        safeFound.addAll(outerCells);
      } else if (remainingMines == outerCells.length) {
        minesFound.addAll(outerCells);
      }
      return false;
    }

    final groups = _splitIntoGroups(constraints);
    var hitLimit = false;
    final solutions = <List<_GroupSolution>?>[];

    for (final group in groups) {
      if (group.cells.length > maxGroupCells) {
        hitLimit = true;
        solutions.add(null);
        continue;
      }
      final enumerated = _enumerateGroup(group);
      if (enumerated == null) {
        hitLimit = true;
        solutions.add(null);
      } else {
        solutions.add(enumerated);
      }
    }

    // Totals each group can contribute. A group we could not enumerate might
    // hold anything between 0 and its cell count, which keeps the global check
    // sound (it can only make us deduce less, never deduce something wrong).
    final totalsPerGroup = <Set<int>>[];
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      final sols = solutions[g];
      if (sols == null) {
        totalsPerGroup.add({
          for (var t = 0; t <= group.cells.length; t++) t,
        });
      } else {
        totalsPerGroup.add({for (final s in sols) s.mineCount});
      }
    }

    final othersAchievable = _achievableSumsExcludingEach(totalsPerGroup, remainingMines);

    var deduced = false;
    for (var g = 0; g < groups.length; g++) {
      final sols = solutions[g];
      if (sols == null) continue;
      final group = groups[g];
      final others = othersAchievable[g];

      final viable = sols
          .where((s) => _globallyFeasible(s.mineCount, others, remainingMines, outerCells.length))
          .toList();
      if (viable.isEmpty) continue;

      for (var c = 0; c < group.cells.length; c++) {
        var mineAlways = true;
        var safeAlways = true;
        for (final s in viable) {
          if (s.isMine[c]) {
            safeAlways = false;
          } else {
            mineAlways = false;
          }
          if (!mineAlways && !safeAlways) break;
        }
        if (mineAlways) {
          minesFound.add(group.cells[c]);
          deduced = true;
        } else if (safeAlways) {
          safeFound.add(group.cells[c]);
          deduced = true;
        }
      }
    }

    // The cells nobody can see also follow from the global count.
    if (outerCells.isNotEmpty) {
      final allGroupTotals = _achievableSums(totalsPerGroup, remainingMines);
      var outerCanBeZero = false;
      var outerCanBeAll = false;
      var outerMin = outerCells.length + 1;
      var outerMax = -1;
      for (final total in allGroupTotals) {
        final outer = remainingMines - total;
        if (outer < 0 || outer > outerCells.length) continue;
        outerMin = outer < outerMin ? outer : outerMin;
        outerMax = outer > outerMax ? outer : outerMax;
        if (outer == 0) outerCanBeZero = true;
        if (outer == outerCells.length) outerCanBeAll = true;
      }
      if (outerMax == 0 && outerCanBeZero) {
        safeFound.addAll(outerCells);
        deduced = true;
      } else if (outerMin == outerCells.length && outerCanBeAll) {
        minesFound.addAll(outerCells);
        deduced = true;
      }
    }

    return hitLimit && !deduced;
  }

  bool _globallyFeasible(
    int groupTotal,
    Set<int> otherTotals,
    int remainingMines,
    int outerCount,
  ) {
    for (final other in otherTotals) {
      final outer = remainingMines - groupTotal - other;
      if (outer >= 0 && outer <= outerCount) return true;
    }
    return false;
  }

  Set<int> _achievableSums(List<Set<int>> totals, int cap) {
    var sums = <int>{0};
    for (final options in totals) {
      final next = <int>{};
      for (final s in sums) {
        for (final o in options) {
          final sum = s + o;
          if (sum <= cap) next.add(sum);
        }
      }
      sums = next;
      if (sums.isEmpty) break;
    }
    return sums;
  }

  /// For each group, the sums the *other* groups can reach.
  List<Set<int>> _achievableSumsExcludingEach(List<Set<int>> totals, int cap) {
    final n = totals.length;
    final prefix = List<Set<int>>.filled(n + 1, const {0});
    prefix[0] = {0};
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = _combine(prefix[i], totals[i], cap);
    }
    final suffix = List<Set<int>>.filled(n + 1, const {0});
    suffix[n] = {0};
    for (var i = n - 1; i >= 0; i--) {
      suffix[i] = _combine(suffix[i + 1], totals[i], cap);
    }
    return [
      for (var i = 0; i < n; i++) _combine(prefix[i], suffix[i + 1], cap),
    ];
  }

  Set<int> _combine(Set<int> a, Set<int> b, int cap) {
    final result = <int>{};
    for (final x in a) {
      for (final y in b) {
        final sum = x + y;
        if (sum <= cap) result.add(sum);
      }
    }
    return result;
  }

  /// Splits constraints into independent groups: two constraints belong to the
  /// same group when they share at least one unknown cell.
  List<_Group> _splitIntoGroups(List<_Constraint> constraints) {
    final parent = List<int>.generate(constraints.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    final owner = <int, int>{};
    for (var i = 0; i < constraints.length; i++) {
      for (final cell in constraints[i].cells) {
        final previous = owner[cell];
        if (previous == null) {
          owner[cell] = i;
        } else {
          union(previous, i);
        }
      }
    }

    final byRoot = <int, List<_Constraint>>{};
    for (var i = 0; i < constraints.length; i++) {
      byRoot.putIfAbsent(find(i), () => []).add(constraints[i]);
    }
    return [for (final group in byRoot.values) _Group.from(group)];
  }

  /// Backtracking search over one group. Returns null if it blew the budget.
  List<_GroupSolution>? _enumerateGroup(_Group group) {
    final cellCount = group.cells.length;
    final assignment = List<bool>.filled(cellCount, false);
    final solutions = <_GroupSolution>[];

    final constraints = group.localConstraints;
    final assigned = List<int>.filled(constraints.length, 0);
    final undecided = [for (final c in constraints) c.length];
    // Which constraints touch each cell, so we only update what changed.
    final touching = List<List<int>>.generate(cellCount, (_) => <int>[]);
    for (var c = 0; c < constraints.length; c++) {
      for (final cell in constraints[c]) {
        touching[cell].add(c);
      }
    }

    var budget = maxAssignmentsPerGroup;
    var overBudget = false;

    void search(int depth, int mineCount) {
      if (overBudget) return;
      if (budget-- <= 0) {
        overBudget = true;
        return;
      }
      if (depth == cellCount) {
        solutions.add(
          _GroupSolution(List<bool>.from(assignment), mineCount),
        );
        return;
      }
      for (final isMine in const [false, true]) {
        assignment[depth] = isMine;
        var ok = true;
        final touched = touching[depth];
        for (final c in touched) {
          if (isMine) assigned[c]++;
          undecided[c]--;
        }
        for (final c in touched) {
          final target = group.targets[c];
          if (assigned[c] > target || assigned[c] + undecided[c] < target) {
            ok = false;
            break;
          }
        }
        if (ok) search(depth + 1, mineCount + (isMine ? 1 : 0));
        for (final c in touched) {
          if (isMine) assigned[c]--;
          undecided[c]++;
        }
        if (overBudget) return;
      }
      assignment[depth] = false;
    }

    search(0, 0);
    if (overBudget) return null;
    return solutions;
  }
}

class _Constraint {
  _Constraint(this.cells, this.mines) : cellSet = cells.toSet();

  final List<int> cells;
  final Set<int> cellSet;
  final int mines;

  bool containsAll(_Constraint other) => cellSet.containsAll(other.cellSet);
}

class _Group {
  _Group(this.cells, this.localConstraints, this.targets);

  factory _Group.from(List<_Constraint> constraints) {
    final cells = <int>[];
    final position = <int, int>{};
    for (final c in constraints) {
      for (final cell in c.cells) {
        if (position.containsKey(cell)) continue;
        position[cell] = cells.length;
        cells.add(cell);
      }
    }
    final local = <List<int>>[];
    final targets = <int>[];
    for (final c in constraints) {
      local.add([for (final cell in c.cells) position[cell]!]);
      targets.add(c.mines);
    }
    return _Group(cells, local, targets);
  }

  /// Board indices, in the order the search assigns them.
  final List<int> cells;

  /// Each constraint expressed as positions into [cells].
  final List<List<int>> localConstraints;

  /// Mines required by each constraint.
  final List<int> targets;
}

class _GroupSolution {
  _GroupSolution(this.isMine, this.mineCount);

  final List<bool> isMine;
  final int mineCount;
}
