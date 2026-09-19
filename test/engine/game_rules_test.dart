import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';

void main() {
  group('salvage scoring', () {
    test('matches the design table', () {
      expect(GameRules.salvageScore(1), 100);
      expect(GameRules.salvageScore(3), 360);
      expect(GameRules.salvageScore(5), 700);
    });

    test('batch bonus is zero for a single mine and grows quadratically', () {
      expect(GameRules.batchBonus(1), 0);
      expect(GameRules.batchBonus(2), 20);
      expect(GameRules.batchBonus(3), 60);
      expect(GameRules.batchBonus(4), 120);
      expect(GameRules.batchBonus(5), 200);
    });

    test('batching always beats salvaging one at a time', () {
      for (var n = 2; n <= 12; n++) {
        expect(
          GameRules.salvageScore(n),
          greaterThan(GameRules.salvageScore(1) * n),
          reason: 'a batch of $n should beat $n singles',
        );
      }
    });

    test('empty and negative batches are worth nothing', () {
      expect(GameRules.salvageScore(0), 0);
      expect(GameRules.salvageScore(-3), 0);
    });

    test('energy is one tenth of the score', () {
      expect(GameRules.salvageEnergy(1), 10);
      expect(GameRules.salvageEnergy(3), 36);
      expect(GameRules.salvageEnergy(5), 70);
    });
  });

  group('salvage chain bonus', () {
    test('level 1 (no chain yet) pays nothing', () {
      expect(GameRules.chainBonus(1, 5), 0);
      expect(GameRules.chainBonus(0, 5), 0);
    });

    test('grows with both chain level and batch size', () {
      // chainBonusPerStep * (level - 1) * count
      expect(GameRules.chainBonus(2, 3), 25 * 1 * 3);
      expect(GameRules.chainBonus(3, 3), 25 * 2 * 3);
      expect(GameRules.chainBonus(2, 5), 25 * 1 * 5);
    });

    test('caps out at maxChainLevel, matching the design table', () {
      expect(
        GameRules.chainBonus(GameRules.maxChainLevel, 5),
        25 * (GameRules.maxChainLevel - 1) * 5,
      );
      expect(GameRules.chainBonus(GameRules.maxChainLevel, 5), 500);
    });

    test('never negative for any inputs', () {
      for (var level = -2; level <= GameRules.maxChainLevel + 2; level++) {
        for (var count = 0; count <= 6; count++) {
          expect(GameRules.chainBonus(level, count), greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('classic speed bonus', () {
    test('pays for finishing under par', () {
      final par = GameRules.parSeconds(Difficulty.beginner);
      expect(
        GameRules.speedBonus(Difficulty.beginner, par - 10),
        10 * GameRules.pointsPerSecondUnderPar,
      );
    });

    test('never goes negative', () {
      final par = GameRules.parSeconds(Difficulty.expert);
      expect(GameRules.speedBonus(Difficulty.expert, par + 500), 0);
    });
  });

  group('difficulty presets', () {
    test('mine density rises with difficulty', () {
      final densities = [
        for (final d in Difficulty.values) d.mineDensity,
      ];
      for (var i = 1; i < densities.length; i++) {
        expect(densities[i], greaterThan(densities[i - 1]));
      }
    });

    test('every preset leaves room for a safe opening', () {
      for (final d in Difficulty.values) {
        expect(d.safeCellCount, greaterThan(9));
      }
    });
  });
}
