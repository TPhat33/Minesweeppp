import 'game_rules.dart';

enum MoveKind { none, reveal, flag, unflag, select, chord, salvage, explode }

/// A cell that opened, plus how far it is from the tap in flood-fill steps.
/// The renderer uses [wave] to stagger the open animation outwards.
class RevealedCell {
  const RevealedCell(this.index, this.wave);

  final int index;
  final int wave;
}

/// Everything the presentation layer needs to react to one move: what changed,
/// what it was worth, and which effects to play.
class MoveResult {
  const MoveResult({
    required this.kind,
    required this.status,
    this.revealed = const [],
    this.salvaged = const [],
    this.failedSalvage = const [],
    this.flagged = const [],
    this.unflagged = const [],
    this.explodedIndex,
    this.scoreDelta = 0,
    this.energyDelta = 0,
    this.batchSize = 0,
    this.batchBonus = 0,
  });

  const MoveResult.none(this.status)
    : kind = MoveKind.none,
      revealed = const [],
      salvaged = const [],
      failedSalvage = const [],
      flagged = const [],
      unflagged = const [],
      explodedIndex = null,
      scoreDelta = 0,
      energyDelta = 0,
      batchSize = 0,
      batchBonus = 0;

  final MoveKind kind;
  final GameStatus status;
  final List<RevealedCell> revealed;

  /// Mines that were successfully salvaged by this move.
  final List<int> salvaged;

  /// Cells the player marked that turned out not to be mines — the run ends.
  final List<int> failedSalvage;

  final List<int> flagged;
  final List<int> unflagged;
  final int? explodedIndex;
  final int scoreDelta;
  final int energyDelta;
  final int batchSize;
  final int batchBonus;

  bool get changed => kind != MoveKind.none;
  bool get isFatal =>
      kind == MoveKind.explode || failedSalvage.isNotEmpty || status == GameStatus.lost;
}
