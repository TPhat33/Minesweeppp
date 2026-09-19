import '../engine/game_rules.dart';
import '../engine/level_code.dart';

/// What the player has done on one specific board, keyed by its level code.
///
/// A level code already encodes the rules version, the difficulty, the mode
/// and the seed — so using [code] as the storage key means a rules bump (like
/// the one that added salvage chains) automatically starts a fresh set of
/// records instead of mixing old and new scores under one key, the same way
/// [LevelCode.isCurrentRules] already keeps old and new codes from being
/// treated as comparable.
class BoardRecord {
  const BoardRecord({
    required this.code,
    required this.difficulty,
    required this.mode,
    required this.seed,
    required this.bestScore,
    required this.bestChain,
    required this.cleared,
    required this.playCount,
    required this.updatedAtMs,
    this.rivalScore,
    this.pinned = false,
  });

  /// [LevelCode.encode]'s output — the storage key as well as the value.
  final String code;

  final Difficulty difficulty;
  final GameMode mode;
  final int seed;

  final int bestScore;

  /// The best salvage chain level ever reached on this board.
  final int bestChain;

  /// Whether this board has ever been cleared, win or lose being otherwise
  /// unrecorded here — [PlayerStore]'s difficulty x mode stats already track
  /// wins in aggregate; this is specifically "have I beaten *this* board".
  final bool cleared;

  final int playCount;

  /// A score the player typed in by hand — someone else's result on the same
  /// board, shared outside the app. Not verified, not a server leaderboard:
  /// just a number to chase.
  final int? rivalScore;

  /// Pinned records are exempt from the eviction [PlayerStore] applies once
  /// the board log grows past its cap — the player's explicit "keep this
  /// one", not something the app should ever silently drop.
  final bool pinned;

  final int updatedAtMs;

  LevelCode toLevelCode() =>
      LevelCode(difficulty: difficulty, mode: mode, seed: seed);

  /// The higher of [bestScore] and [rivalScore], if either exists — what the
  /// HUD chases during a run on this board.
  int? get target {
    final rival = rivalScore;
    if (rival == null) return bestScore > 0 ? bestScore : null;
    if (bestScore == 0) return rival;
    return bestScore > rival ? bestScore : rival;
  }

  /// True when [target] is [rivalScore] rather than the player's own best —
  /// lets the UI say *who* is being chased.
  bool get targetIsRival {
    final rival = rivalScore;
    if (rival == null) return false;
    return rival > bestScore;
  }

  BoardRecord copyWith({
    int? bestScore,
    int? bestChain,
    bool? cleared,
    int? playCount,
    int? rivalScore,
    bool clearRivalScore = false,
    bool? pinned,
    int? updatedAtMs,
  }) {
    return BoardRecord(
      code: code,
      difficulty: difficulty,
      mode: mode,
      seed: seed,
      bestScore: bestScore ?? this.bestScore,
      bestChain: bestChain ?? this.bestChain,
      cleared: cleared ?? this.cleared,
      playCount: playCount ?? this.playCount,
      rivalScore: clearRivalScore ? null : (rivalScore ?? this.rivalScore),
      pinned: pinned ?? this.pinned,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'difficulty': difficulty.name,
    'mode': mode.name,
    'seed': seed,
    'bestScore': bestScore,
    'bestChain': bestChain,
    'cleared': cleared,
    'playCount': playCount,
    'rivalScore': rivalScore,
    'pinned': pinned,
    'updatedAtMs': updatedAtMs,
  };

  /// Returns null for anything unreadable — a corrupt or foreign-shaped
  /// record is dropped rather than crashing the board log.
  static BoardRecord? fromJson(Map<String, dynamic> json) {
    final difficulty = Difficulty.values.asNameMap()[json['difficulty']];
    final mode = GameMode.values.asNameMap()[json['mode']];
    final code = json['code'] as String?;
    final seed = json['seed'] as int?;
    if (difficulty == null || mode == null || code == null || seed == null) {
      return null;
    }
    return BoardRecord(
      code: code,
      difficulty: difficulty,
      mode: mode,
      seed: seed,
      bestScore: json['bestScore'] as int? ?? 0,
      bestChain: json['bestChain'] as int? ?? 0,
      cleared: json['cleared'] as bool? ?? false,
      playCount: json['playCount'] as int? ?? 0,
      rivalScore: json['rivalScore'] as int?,
      pinned: json['pinned'] as bool? ?? false,
      updatedAtMs: json['updatedAtMs'] as int? ?? 0,
    );
  }
}
