import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/minesweeper_engine.dart';
import 'package:minesweeppp/core/engine/move_result.dart';

import 'test_boards.dart';

/// A 9x9 field with a tight cluster of three mines in the top-left corner and
/// a lone mine at (4, 5).
///
/// Starting on (0, 0) — a cell that reads 1 — keeps almost everything hidden,
/// which is what makes the assertions below precise.
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
const _mineB = 1 * 9 + 2; // (2, 1)
const _mineC = 2 * 9 + 1; // (1, 2)
const _mineD = 5 * 9 + 4; // (4, 5)

int at(int x, int y) => y * 9 + x;

void main() {
  group('opening', () {
    test('the start cell is opened for the player', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.stateOf(at(0, 0)), CellState.revealed);
      expect(engine.revealedCount, 1, reason: '(0, 0) reads 1, so no flood');
      expect(engine.status, GameStatus.playing);
    });

    test('opening a zero cell floods outward in waves', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      final result = engine.reveal(at(8, 8));

      expect(result.kind, MoveKind.reveal);
      expect(result.revealed.length, greaterThan(20));
      expect(result.revealed.first.wave, 0);
      expect(
        result.revealed.map((c) => c.wave).reduce((a, b) => a > b ? a : b),
        greaterThan(1),
        reason: 'the ripple animation needs increasing wave numbers',
      );
      // The flood stops on the numbered ring around the lone mine.
      expect(engine.stateOf(at(4, 4)), CellState.revealed);
      expect(engine.stateOf(_mineD), CellState.hidden);
    });

    test('revealing pays per opened cell', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      final before = engine.score;
      final result = engine.reveal(at(8, 8));
      expect(
        engine.score - before,
        result.revealed.length * GameRules.pointsPerRevealedCell,
      );
    });
  });

  group('flagging', () {
    test('toggles on and off and tracks the counter', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.minesRemaining, 4);

      engine.toggleFlag(_mineA);
      expect(engine.stateOf(_mineA), CellState.flagged);
      expect(engine.minesRemaining, 3);

      engine.toggleFlag(_mineA);
      expect(engine.stateOf(_mineA), CellState.hidden);
      expect(engine.minesRemaining, 4);
    });

    test('flagging a revealed cell does nothing', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.toggleFlag(at(0, 0)).changed, isFalse);
    });

    test('revealing a flagged cell does nothing', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.toggleFlag(_mineA);
      expect(engine.reveal(_mineA).changed, isFalse);
      expect(engine.status, GameStatus.playing);
    });
  });

  group('salvage', () {
    void flagAndSelect(MinesweeperEngine engine, List<int> cells) {
      for (final cell in cells) {
        engine.toggleFlag(cell);
        engine.toggleSalvageSelection(cell);
      }
    }

    test('a correct batch pays base score plus the batch bonus', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      flagAndSelect(engine, [_mineA, _mineB, _mineC]);
      expect(engine.selectionSize, 3);
      expect(engine.pendingSalvageScore, 360);
      expect(engine.pendingBatchBonus, 60);

      final before = engine.score;
      final result = engine.commitSalvage();

      expect(result.kind, MoveKind.salvage);
      expect(result.batchSize, 3);
      expect(result.batchBonus, 60);
      expect(engine.score - before, 360);
      expect(engine.salvagedCount, 3);
      expect(engine.largestBatch, 3);
      expect(engine.salvageBatches, 1);
      expect(engine.selectionSize, 0);
      for (final mine in [_mineA, _mineB, _mineC]) {
        expect(engine.stateOf(mine), CellState.salvaged);
      }
      expect(engine.minesRemaining, 1);
    });

    test('three singles are worth less than one batch of three', () {
      final batched = engineFrom(_field, startX: 0, startY: 0);
      flagAndSelect(batched, [_mineA, _mineB, _mineC]);
      batched.commitSalvage();

      final singles = engineFrom(_field, startX: 0, startY: 0);
      for (final mine in [_mineA, _mineB, _mineC]) {
        flagAndSelect(singles, [mine]);
        singles.commitSalvage();
      }

      expect(batched.score, greaterThan(singles.score));
      expect(batched.score - singles.score, GameRules.batchBonus(3));
    });

    test('one wrong pick ends the run and nothing is scored', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      const notAMine = 8; // (8, 0)
      flagAndSelect(engine, [_mineA, notAMine]);

      final before = engine.score;
      final result = engine.commitSalvage();

      expect(engine.status, GameStatus.lost);
      expect(engine.lossReason, LossReason.badSalvage);
      expect(result.failedSalvage, [notAMine]);
      expect(result.isFatal, isTrue);
      expect(engine.score, before);
      expect(engine.salvagedCount, 0);
    });

    test('salvaged mines keep counting towards the numbers', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      final probe = at(0, 0); // reads 1, its mine is _mineA
      final before = engine.board.adjacentMines(probe);

      flagAndSelect(engine, [_mineA]);
      engine.commitSalvage();

      expect(engine.board.adjacentMines(probe), before);
      expect(engine.stateOf(_mineA), CellState.salvaged);
      // Still marked as far as chording is concerned.
      expect(engine.chordTargets(probe), [at(0, 1), at(1, 1)]);
    });

    test('a salvaged mine cannot be scored twice', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      flagAndSelect(engine, [_mineA]);
      engine.commitSalvage();

      final after = engine.score;
      expect(engine.toggleSalvageSelection(_mineA).changed, isFalse);
      expect(engine.commitSalvage().changed, isFalse);
      expect(engine.score, after);
    });

    test('only flagged cells can join a batch', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.toggleSalvageSelection(_mineA).changed, isFalse);
      expect(engine.selectionSize, 0);
    });

    test('unflagging drops the cell from the batch', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      flagAndSelect(engine, [_mineA]);
      expect(engine.selectionSize, 1);
      engine.toggleFlag(_mineA);
      expect(engine.selectionSize, 0);
    });

    test('selecting twice removes the cell again', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      flagAndSelect(engine, [_mineA]);
      engine.toggleSalvageSelection(_mineA);
      expect(engine.selectionSize, 0);
    });

    test('selectAllFlags picks up every flag on the board', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.toggleFlag(_mineA);
      engine.toggleFlag(_mineB);
      engine.selectAllFlags();
      expect(engine.selectionSize, 2);
      expect(engine.clearSelection().changed, isTrue);
      expect(engine.selectionSize, 0);
    });

    test('committing an empty batch is a no-op', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.commitSalvage().changed, isFalse);
      expect(engine.status, GameStatus.playing);
    });
  });

  group('chording', () {
    test('an unsatisfied number offers no targets', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.chordTargets(at(0, 0)), isEmpty);
    });

    test('a satisfied number opens its hidden neighbours', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.toggleFlag(_mineA);

      expect(engine.chordTargets(at(0, 0)), [at(0, 1), at(1, 1)]);
      final result = engine.chord(at(0, 0));

      expect(result.kind, MoveKind.chord);
      expect(engine.stateOf(at(0, 1)), CellState.revealed);
      expect(engine.stateOf(at(1, 1)), CellState.revealed);
      expect(engine.status, GameStatus.playing);
    });

    test('a wrong flag makes chording fatal', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.toggleFlag(at(0, 1)); // not a mine
      engine.chord(at(0, 0));
      expect(engine.status, GameStatus.lost);
      expect(engine.lossReason, LossReason.mineRevealed);
    });

    test('chording a zero or hidden cell does nothing', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.reveal(at(8, 8));
      expect(engine.chord(at(8, 8)).changed, isFalse);
      expect(engine.chord(_mineD).changed, isFalse);
    });
  });

  group('losing and winning', () {
    test('opening a mine ends the run', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      final result = engine.reveal(_mineA);
      expect(engine.status, GameStatus.lost);
      expect(engine.lossReason, LossReason.mineRevealed);
      expect(result.explodedIndex, _mineA);
      expect(engine.allMines().length, 4);
    });

    test('clearing every safe cell wins and marks the rest', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      for (var i = 0; i < engine.board.cellCount; i++) {
        if (!engine.board.isMine(i)) engine.reveal(i);
      }
      expect(engine.status, GameStatus.won);
      expect(engine.minesRemaining, 0);
      expect(engine.stateOf(_mineD), CellState.flagged);
      expect(
        engine.score,
        greaterThan(GameRules.completionBonus(Difficulty.beginner)),
      );
    });

    test('salvaged mines are not re-flagged on a win', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.toggleFlag(_mineA);
      engine.toggleSalvageSelection(_mineA);
      engine.commitSalvage();
      for (var i = 0; i < engine.board.cellCount; i++) {
        if (!engine.board.isMine(i)) engine.reveal(i);
      }
      expect(engine.status, GameStatus.won);
      expect(engine.stateOf(_mineA), CellState.salvaged);
      expect(engine.minesRemaining, 0);
    });

    test('moves after the run is over are ignored', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      engine.reveal(_mineA);
      expect(engine.reveal(at(8, 8)).changed, isFalse);
      expect(engine.toggleFlag(_mineB).changed, isFalse);
      expect(engine.chord(at(0, 0)).changed, isFalse);
      expect(engine.commitSalvage().changed, isFalse);
    });
  });

  group('timed mode', () {
    void salvageAll(MinesweeperEngine engine, List<int> mines) {
      for (final mine in mines) {
        engine.toggleFlag(mine);
        engine.toggleSalvageSelection(mine);
      }
      engine.commitSalvage();
    }

    test('salvaging generates energy only in timed mode', () {
      final classic = engineFrom(_field, startX: 0, startY: 0);
      final timed = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
      salvageAll(classic, [_mineA]);
      salvageAll(timed, [_mineA]);
      expect(classic.energy, 0);
      expect(timed.energy, GameRules.salvageEnergy(1));
    });

    test('energy buys time, and runs out', () {
      final engine = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
      salvageAll(engine, [_mineA, _mineB, _mineC, _mineD]);
      expect(engine.energy, GameRules.salvageEnergy(4)); // 52

      final before = engine.secondsRemaining;
      expect(engine.spendEnergyForTime(), isTrue);
      expect(engine.secondsRemaining, before + GameRules.timeBoostSeconds);
      expect(engine.energy, 52 - GameRules.timeBoostCost);
      expect(engine.timeBoostsUsed, 1);
      expect(engine.timeBoostsLeft, GameRules.maxTimeBoosts - 1);

      expect(engine.canSpendEnergyForTime, isFalse);
      expect(engine.spendEnergyForTime(), isFalse);
    });

    test('classic mode never allows a time boost', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      expect(engine.canSpendEnergyForTime, isFalse);
      expect(engine.spendEnergyForTime(), isFalse);
    });

    test('the clock running out ends the run', () {
      final engine = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
      expect(engine.tick(10), isNull);
      final result = engine.tick(Difficulty.beginner.timedSeconds.toDouble());
      expect(result, isNotNull);
      expect(engine.status, GameStatus.lost);
      expect(engine.lossReason, LossReason.timeout);
      expect(engine.secondsRemaining, 0);
    });

    test('the clock does not run once the run is over', () {
      final engine = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
      engine.reveal(_mineA);
      final remaining = engine.secondsRemaining;
      expect(engine.tick(5), isNull);
      expect(engine.secondsRemaining, remaining);
    });

    test('unspent energy pays a capped bonus on a win', () {
      final engine = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
      salvageAll(engine, [_mineA, _mineB, _mineC, _mineD]);
      final energy = engine.energy;

      final beforeWin = engine.score;
      for (var i = 0; i < engine.board.cellCount; i++) {
        if (!engine.board.isMine(i)) engine.reveal(i);
      }
      expect(engine.status, GameStatus.won);

      final revealed = engine.board.safeCellCount - 1; // start cell already open
      final expectedBonus =
          GameRules.completionBonus(Difficulty.beginner) +
          energy * GameRules.pointsPerLeftoverEnergy;
      expect(
        engine.score - beforeWin,
        revealed * GameRules.pointsPerRevealedCell + expectedBonus,
      );
    });
  });

  group('save and resume', () {
    test('a snapshot round-trips exactly', () {
      final engine = engineFrom(_field, startX: 0, startY: 0, mode: GameMode.timed);
      engine.reveal(at(8, 8));
      engine.toggleFlag(_mineA);
      engine.toggleFlag(_mineB);
      engine.toggleSalvageSelection(_mineB);
      engine.tick(12.5);

      final restored = MinesweeperEngine.fromJson(engine.toJson())!;

      expect(restored.score, engine.score);
      expect(restored.energy, engine.energy);
      expect(restored.flagCount, engine.flagCount);
      expect(restored.revealedCount, engine.revealedCount);
      expect(restored.selection, engine.selection);
      expect(restored.secondsRemaining, closeTo(engine.secondsRemaining, 1e-9));
      expect(restored.elapsedSeconds, closeTo(engine.elapsedSeconds, 1e-9));
      expect(restored.board.startIndex, engine.board.startIndex);
      expect(restored.mode, engine.mode);
      expect(restored.difficulty, engine.difficulty);
      for (var i = 0; i < engine.board.cellCount; i++) {
        expect(restored.stateOf(i), engine.stateOf(i));
        expect(restored.board.isMine(i), engine.board.isMine(i));
        expect(restored.board.adjacentMines(i), engine.board.adjacentMines(i));
      }
    });

    test('a save from another rules version is refused', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      final json = engine.toJson()..['rulesVersion'] = GameRules.rulesVersion + 1;
      expect(MinesweeperEngine.fromJson(json), isNull);
    });

    test('a restored run keeps playing correctly', () {
      final engine = engineFrom(_field, startX: 0, startY: 0);
      final restored = MinesweeperEngine.fromJson(engine.toJson())!;
      restored.toggleFlag(_mineA);
      restored.toggleSalvageSelection(_mineA);
      expect(restored.commitSalvage().batchSize, 1);
      expect(restored.salvagedCount, 1);
    });
  });
}
