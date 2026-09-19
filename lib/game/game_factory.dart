import 'dart:math' as math;

import '../core/engine/board_generator.dart';
import '../core/engine/game_rules.dart';
import '../core/engine/level_code.dart';
import '../core/engine/minesweeper_engine.dart';

/// Builds runs. Generation happens in an isolate because proving a Legendary
/// board needs no guessing can take a few hundred milliseconds.
abstract final class GameFactory {
  static final math.Random _seedSource = math.Random.secure();

  static int randomSeed() => _seedSource.nextInt(0xFFFFFFFF);

  static Future<MinesweeperEngine> create({
    required Difficulty difficulty,
    required GameMode mode,
    int? seed,
  }) async {
    final generated = await BoardGenerator.generateAsync(
      difficulty: difficulty,
      seed: seed ?? randomSeed(),
    );
    return MinesweeperEngine.fromGenerated(
      generated,
      difficulty: difficulty,
      mode: mode,
    );
  }

  static Future<MinesweeperEngine> fromCode(LevelCode code) => create(
    difficulty: code.difficulty,
    mode: code.mode,
    seed: code.seed,
  );
}
