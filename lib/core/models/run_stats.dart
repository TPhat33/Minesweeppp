import 'dart:math' as math;

import '../engine/game_rules.dart';

/// Best-of records for one difficulty and mode.
class RunStats {
  const RunStats({
    this.played = 0,
    this.won = 0,
    this.bestScore = 0,
    this.bestTimeSeconds,
    this.largestBatch = 0,
    this.minesSalvaged = 0,
  });

  final int played;
  final int won;
  final int bestScore;

  /// Fastest win, in seconds. Null until the first win.
  final int? bestTimeSeconds;

  final int largestBatch;
  final int minesSalvaged;

  double get winRate => played == 0 ? 0 : won / played;

  RunStats recordRun({
    required bool victory,
    required int score,
    required int elapsedSeconds,
    required int largestBatch,
    required int minesSalvaged,
  }) {
    return RunStats(
      played: played + 1,
      won: won + (victory ? 1 : 0),
      bestScore: math.max(bestScore, score),
      bestTimeSeconds: victory
          ? (bestTimeSeconds == null
                ? elapsedSeconds
                : math.min(bestTimeSeconds!, elapsedSeconds))
          : bestTimeSeconds,
      largestBatch: math.max(this.largestBatch, largestBatch),
      minesSalvaged: this.minesSalvaged + minesSalvaged,
    );
  }

  Map<String, dynamic> toJson() => {
    'played': played,
    'won': won,
    'bestScore': bestScore,
    'bestTimeSeconds': bestTimeSeconds,
    'largestBatch': largestBatch,
    'minesSalvaged': minesSalvaged,
  };

  static RunStats fromJson(Map<String, dynamic> json) => RunStats(
    played: json['played'] as int? ?? 0,
    won: json['won'] as int? ?? 0,
    bestScore: json['bestScore'] as int? ?? 0,
    bestTimeSeconds: json['bestTimeSeconds'] as int?,
    largestBatch: json['largestBatch'] as int? ?? 0,
    minesSalvaged: json['minesSalvaged'] as int? ?? 0,
  );

  static String keyFor(Difficulty difficulty, GameMode mode) =>
      '${difficulty.name}:${mode.name}';
}
