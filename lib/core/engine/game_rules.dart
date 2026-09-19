/// Central place for every tunable number in the game.
///
/// The rules version is part of a level code: two players can only compare
/// scores when the board, the start cell and the rules version all match.
library;

/// Board presets. Mine density climbs from ~12% to ~26%.
enum Difficulty {
  beginner('Beginner', 9, 9, 10, 240),
  intermediate('Intermediate', 16, 16, 40, 420),
  expert('Expert', 30, 16, 99, 600),
  master('Master', 30, 20, 130, 780),
  legendary('Legendary', 32, 24, 175, 960);

  const Difficulty(
    this.label,
    this.width,
    this.height,
    this.mineCount,
    this.timedSeconds,
  );

  final String label;
  final int width;
  final int height;
  final int mineCount;

  /// Starting clock for [GameMode.timed], in seconds.
  final int timedSeconds;

  int get cellCount => width * height;
  int get safeCellCount => cellCount - mineCount;
  double get mineDensity => mineCount / cellCount;
}

enum GameMode {
  classic('Classic'),
  timed('Timed');

  const GameMode(this.label);

  final String label;
}

enum GameStatus { playing, won, lost }

enum LossReason { mineRevealed, badSalvage, timeout }

/// Which action a tap performs when no modifier gesture is used.
enum InputMode { reveal, flag }

abstract final class GameRules {
  /// Bump whenever a scoring or gameplay rule changes; level codes carry it so
  /// that old codes never masquerade as comparable runs.
  ///
  /// 2: added the salvage chain bonus (see below). A code or a save written
  /// under version 1 is refused rather than silently scored under different
  /// rules — [LevelCode.isCurrentRules] and [MinesweeperEngine.fromJson]
  /// handle that; nothing here needs a migration path.
  static const int rulesVersion = 2;

  // ---------------------------------------------------------------- salvage
  static const int salvageBaseScore = 100;

  /// Score for salvaging [count] mines in one batch.
  ///
  ///     1 -> 100 + 0   = 100
  ///     3 -> 300 + 60  = 360
  ///     5 -> 500 + 200 = 700
  static int salvageScore(int count) {
    if (count <= 0) return 0;
    return salvageBaseScore * count + batchBonus(count);
  }

  /// The "thinking ahead" premium: 10 * n * (n - 1).
  static int batchBonus(int count) {
    if (count <= 1) return 0;
    return 10 * count * (count - 1);
  }

  /// Energy is one tenth of the salvage score, so batching pays off twice.
  static int salvageEnergy(int count) => salvageScore(count) ~/ 10;

  /// A batch of at least this size can start or extend a chain. A single
  /// mine is the "playing it safe" move by definition, so it never chains —
  /// chains reward committing to a batch, not just salvaging at all.
  static const int minChainBatch = 2;

  /// Consecutive non-shrinking batches build a chain; a batch smaller than
  /// the one before it (or a lone mine) breaks it. Capped the same way
  /// [maxTimeBoosts] and [maxEnergyBonus] are: a ceiling that keeps a single
  /// hot streak from deciding the whole run outright.
  static const int maxChainLevel = 5;

  /// Points added per mine in the batch, per chain level above 1.
  ///
  /// At chain level 2 a batch of 3 gets +75 on top of its 360 base — felt,
  /// not a base-score-doubling swing. Provisional: nothing has measured a
  /// full run's totals against this yet. If a played-well run on Expert
  /// scores far past double a typical one, lower this before lowering
  /// [maxChainLevel] — the level is what keeps the target legible; the slope
  /// is what tuning should touch.
  static const int chainBonusPerStep = 25;

  /// Bonus for cashing in [count] mines while the chain is at [chainLevel].
  /// Zero below level 2 — a chain of one is just an ordinary batch.
  static int chainBonus(int chainLevel, int count) {
    if (chainLevel <= 1) return 0;
    return chainBonusPerStep * (chainLevel - 1) * count;
  }

  // ----------------------------------------------------------------- energy
  /// Energy spent for one time extension.
  static const int timeBoostCost = 30;

  /// Seconds granted per extension.
  static const int timeBoostSeconds = 15;

  /// Cap on extensions per run, so the timed mode keeps its pressure.
  static const int maxTimeBoosts = 4;

  /// Points per unspent energy at the end of a won timed run.
  static const int pointsPerLeftoverEnergy = 4;

  /// Cap on the "keep it" payout, for the same reason.
  static const int maxEnergyBonus = 1200;

  // ------------------------------------------------------------------ score
  static const int pointsPerRevealedCell = 2;

  static int completionBonus(Difficulty difficulty) => switch (difficulty) {
    Difficulty.beginner => 250,
    Difficulty.intermediate => 600,
    Difficulty.expert => 1400,
    Difficulty.master => 2200,
    Difficulty.legendary => 3200,
  };

  /// Reference time used for the classic-mode speed bonus, in seconds.
  static int parSeconds(Difficulty difficulty) => switch (difficulty) {
    Difficulty.beginner => 60,
    Difficulty.intermediate => 200,
    Difficulty.expert => 420,
    Difficulty.master => 600,
    Difficulty.legendary => 840,
  };

  static const int pointsPerSecondUnderPar = 5;

  /// Classic mode only: finishing under par pays, finishing over par does not
  /// subtract anything.
  static int speedBonus(Difficulty difficulty, int elapsedSeconds) {
    final under = parSeconds(difficulty) - elapsedSeconds;
    if (under <= 0) return 0;
    return under * pointsPerSecondUnderPar;
  }
}
