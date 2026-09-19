import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;

import '../core/engine/board_generator.dart';
import '../core/engine/game_rules.dart';
import '../core/engine/level_code.dart';
import '../core/engine/minesweeper_engine.dart';

/// What one generation request needs to cross into [compute]'s worker.
///
/// `compute()` requires a top-level or static function — no closures — so
/// everything the work needs has to travel as plain data instead of being
/// captured, hence this little value type.
class _GenerationRequest {
  const _GenerationRequest({required this.difficulty, required this.seed});

  final Difficulty difficulty;
  final int seed;
}

GeneratedBoard _runGeneration(_GenerationRequest request) {
  return const BoardGenerator().generate(
    difficulty: request.difficulty,
    seed: request.seed,
  );
}

/// Builds runs.
///
/// Generation goes through [compute] rather than [BoardGenerator.generateAsync]
/// directly, because `compute` is the one abstraction that does the right
/// thing on every target: a real isolate on the VM, and — since `dart:isolate`
/// has no web implementation at all — a same-thread call yielding one frame
/// first on web, so a Legendary board's few hundred milliseconds don't freeze
/// the tab but also don't throw `UnsupportedError`.
abstract final class GameFactory {
  static final math.Random _seedSource = math.Random.secure();

  static int randomSeed() => _seedSource.nextInt(0xFFFFFFFF);

  static Future<MinesweeperEngine> create({
    required Difficulty difficulty,
    required GameMode mode,
    int? seed,
  }) async {
    final generated = await compute(
      _runGeneration,
      _GenerationRequest(difficulty: difficulty, seed: seed ?? randomSeed()),
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
