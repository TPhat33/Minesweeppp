import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'board.dart';
import 'board_generator.dart';
import 'game_rules.dart';
import 'level_code.dart';
import 'move_result.dart';

abstract final class CellState {
  static const int hidden = 0;
  static const int revealed = 1;
  static const int flagged = 2;

  /// A mine the player correctly identified and cashed in. It is still a mine
  /// for every neighbouring number — salvaging never rewrites the board.
  static const int salvaged = 3;
}

/// The rules of Minesweeppp, with no dependency on Flutter or Flame.
///
/// Everything the player can do goes through this class and comes back as a
/// [MoveResult], which is what the renderer turns into animations. Tests drive
/// it directly.
class MinesweeperEngine {
  MinesweeperEngine({
    required this.board,
    required this.difficulty,
    required this.mode,
    required this.seed,
    required this.noGuess,
  }) : _state = Uint8List(board.cellCount),
       _secondsRemaining = mode == GameMode.timed
           ? difficulty.timedSeconds.toDouble()
           : 0 {
    _openStartCell();
  }

  factory MinesweeperEngine.fromGenerated(
    GeneratedBoard generated, {
    required Difficulty difficulty,
    required GameMode mode,
  }) {
    return MinesweeperEngine(
      board: generated.board,
      difficulty: difficulty,
      mode: mode,
      seed: generated.seed,
      noGuess: generated.noGuess,
    );
  }

  final Board board;
  final Difficulty difficulty;
  final GameMode mode;
  final int seed;

  /// False when the generator ran out of budget and could not prove the board
  /// is guess-free. The HUD tells the player when that happens.
  final bool noGuess;

  final Uint8List _state;
  final Set<int> _selection = <int>{};

  GameStatus _status = GameStatus.playing;
  LossReason? _lossReason;
  int _score = 0;
  int _energy = 0;
  int _timeBoostsUsed = 0;
  int _revealedCount = 0;
  int _flagCount = 0;
  int _salvagedCount = 0;
  int _largestBatch = 0;
  int _salvageBatches = 0;
  double _elapsedSeconds = 0;
  double _secondsRemaining;

  // ------------------------------------------------------------------ state
  GameStatus get status => _status;
  LossReason? get lossReason => _lossReason;
  int get score => _score;
  int get energy => _energy;
  int get timeBoostsUsed => _timeBoostsUsed;
  int get timeBoostsLeft => GameRules.maxTimeBoosts - _timeBoostsUsed;
  int get revealedCount => _revealedCount;
  int get flagCount => _flagCount;
  int get salvagedCount => _salvagedCount;
  int get largestBatch => _largestBatch;
  int get salvageBatches => _salvageBatches;
  double get elapsedSeconds => _elapsedSeconds;
  double get secondsRemaining => _secondsRemaining;
  bool get isOver => _status != GameStatus.playing;

  /// Mines the player has neither flagged nor salvaged yet.
  int get minesRemaining => board.mineCount - _flagCount - _salvagedCount;

  Set<int> get selection => Set.unmodifiable(_selection);
  int get selectionSize => _selection.length;

  /// What the current selection would pay out if every pick is right.
  int get pendingSalvageScore => GameRules.salvageScore(_selection.length);
  int get pendingBatchBonus => GameRules.batchBonus(_selection.length);

  int stateOf(int index) => _state[index];
  bool isSelected(int index) => _selection.contains(index);

  LevelCode get levelCode =>
      LevelCode(difficulty: difficulty, mode: mode, seed: seed);

  bool get canSpendEnergyForTime =>
      mode == GameMode.timed &&
      _status == GameStatus.playing &&
      _energy >= GameRules.timeBoostCost &&
      _timeBoostsUsed < GameRules.maxTimeBoosts;

  // ---------------------------------------------------------------- actions
  /// Opens [index]. Flagged and already-open cells are left alone so a stray
  /// tap can never undo a flag.
  MoveResult reveal(int index) {
    if (_status != GameStatus.playing) return MoveResult.none(_status);
    if (_state[index] != CellState.hidden) return MoveResult.none(_status);

    if (board.isMine(index)) {
      _state[index] = CellState.revealed;
      return _lose(LossReason.mineRevealed, explodedIndex: index);
    }

    final revealed = _floodReveal(index);
    final gained = revealed.length * GameRules.pointsPerRevealedCell;
    _score += gained;
    final won = _checkWin();
    return MoveResult(
      kind: MoveKind.reveal,
      status: _status,
      revealed: revealed,
      scoreDelta: gained + won.scoreDelta,
    );
  }

  /// Flags or unflags a hidden cell. Unflagging also drops it from the salvage
  /// selection.
  MoveResult toggleFlag(int index) {
    if (_status != GameStatus.playing) return MoveResult.none(_status);
    switch (_state[index]) {
      case CellState.hidden:
        _state[index] = CellState.flagged;
        _flagCount++;
        return MoveResult(
          kind: MoveKind.flag,
          status: _status,
          flagged: [index],
        );
      case CellState.flagged:
        _state[index] = CellState.hidden;
        _flagCount--;
        _selection.remove(index);
        return MoveResult(
          kind: MoveKind.unflag,
          status: _status,
          unflagged: [index],
        );
      default:
        return MoveResult.none(_status);
    }
  }

  /// Adds or removes a flagged cell from the salvage batch.
  MoveResult toggleSalvageSelection(int index) {
    if (_status != GameStatus.playing) return MoveResult.none(_status);
    if (_state[index] != CellState.flagged) return MoveResult.none(_status);
    if (!_selection.remove(index)) _selection.add(index);
    return MoveResult(kind: MoveKind.select, status: _status);
  }

  /// Puts every flag into the batch — the "I am sure about all of these" move.
  MoveResult selectAllFlags() {
    if (_status != GameStatus.playing) return MoveResult.none(_status);
    for (var i = 0; i < _state.length; i++) {
      if (_state[i] == CellState.flagged) _selection.add(i);
    }
    return MoveResult(kind: MoveKind.select, status: _status);
  }

  MoveResult clearSelection() {
    if (_selection.isEmpty) return MoveResult.none(_status);
    _selection.clear();
    return MoveResult(kind: MoveKind.select, status: _status);
  }

  /// Cashes in the current batch.
  ///
  /// Every pick must be a mine. One wrong cell ends the run — that is the
  /// tension the whole mode is built on.
  MoveResult commitSalvage() {
    if (_status != GameStatus.playing) return MoveResult.none(_status);
    if (_selection.isEmpty) return MoveResult.none(_status);

    final picks = _selection.toList()..sort();
    final wrong = [for (final index in picks) if (!board.isMine(index)) index];
    if (wrong.isNotEmpty) {
      _selection.clear();
      return _lose(LossReason.badSalvage, failedSalvage: wrong);
    }

    final count = picks.length;
    final gained = GameRules.salvageScore(count);
    final energyGained = mode == GameMode.timed
        ? GameRules.salvageEnergy(count)
        : 0;

    for (final index in picks) {
      _state[index] = CellState.salvaged;
    }
    _flagCount -= count;
    _salvagedCount += count;
    _score += gained;
    _energy += energyGained;
    _largestBatch = math.max(_largestBatch, count);
    _salvageBatches++;
    _selection.clear();

    final won = _checkWin();
    return MoveResult(
      kind: MoveKind.salvage,
      status: _status,
      salvaged: picks,
      scoreDelta: gained + won.scoreDelta,
      energyDelta: energyGained,
      batchSize: count,
      batchBonus: GameRules.batchBonus(count),
    );
  }

  /// Opens every hidden neighbour of a satisfied number. Salvaged mines count
  /// as marked, so chording keeps working after a salvage.
  MoveResult chord(int index) {
    if (_status != GameStatus.playing) return MoveResult.none(_status);
    if (_state[index] != CellState.revealed) return MoveResult.none(_status);
    final number = board.adjacentMines(index);
    if (number == 0) return MoveResult.none(_status);

    final targets = chordTargets(index);
    if (targets.isEmpty) return MoveResult.none(_status);

    // A wrong flag is still a losing flag: chording trusts the player's marks.
    for (final target in targets) {
      if (board.isMine(target)) {
        _state[target] = CellState.revealed;
        return _lose(LossReason.mineRevealed, explodedIndex: target);
      }
    }

    final revealed = <RevealedCell>[];
    for (final target in targets) {
      revealed.addAll(_floodReveal(target));
    }
    final gained = revealed.length * GameRules.pointsPerRevealedCell;
    _score += gained;
    final won = _checkWin();
    return MoveResult(
      kind: MoveKind.chord,
      status: _status,
      revealed: revealed,
      scoreDelta: gained + won.scoreDelta,
    );
  }

  /// The cells a chord on [index] would open, or an empty list when the number
  /// is not satisfied. Used to preview the move before the finger lifts.
  List<int> chordTargets(int index) {
    if (_state[index] != CellState.revealed) return const [];
    final number = board.adjacentMines(index);
    if (number == 0) return const [];

    var marked = 0;
    final hidden = <int>[];
    for (final n in board.neighbours(index)) {
      switch (_state[n]) {
        case CellState.flagged:
        case CellState.salvaged:
          marked++;
        case CellState.hidden:
          hidden.add(n);
      }
    }
    if (marked != number || hidden.isEmpty) return const [];
    return hidden;
  }

  /// Timed mode: trade energy for clock.
  bool spendEnergyForTime() {
    if (!canSpendEnergyForTime) return false;
    _energy -= GameRules.timeBoostCost;
    _secondsRemaining += GameRules.timeBoostSeconds;
    _timeBoostsUsed++;
    return true;
  }

  /// Advances the clock. Returns a result only when the clock running out ends
  /// the run.
  MoveResult? tick(double deltaSeconds) {
    if (_status != GameStatus.playing) return null;
    _elapsedSeconds += deltaSeconds;
    if (mode != GameMode.timed) return null;
    _secondsRemaining -= deltaSeconds;
    if (_secondsRemaining > 0) return null;
    _secondsRemaining = 0;
    return _lose(LossReason.timeout);
  }

  // ---------------------------------------------------------------- helpers
  void _openStartCell() {
    final revealed = _floodReveal(board.startIndex);
    _score += revealed.length * GameRules.pointsPerRevealedCell;
  }

  List<RevealedCell> _floodReveal(int index) {
    if (_state[index] != CellState.hidden || board.isMine(index)) {
      return const [];
    }
    final opened = <RevealedCell>[];
    var frontier = <int>[index];
    var wave = 0;
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final current in frontier) {
        if (_state[current] != CellState.hidden) continue;
        _state[current] = CellState.revealed;
        _revealedCount++;
        opened.add(RevealedCell(current, wave));
        if (board.adjacentMines(current) != 0) continue;
        for (final n in board.neighbours(current)) {
          if (_state[n] == CellState.hidden) next.add(n);
        }
      }
      frontier = next;
      wave++;
    }
    return opened;
  }

  _WinPayout _checkWin() {
    if (_revealedCount < board.safeCellCount) return const _WinPayout(0);
    _status = GameStatus.won;

    var bonus = GameRules.completionBonus(difficulty);
    if (mode == GameMode.classic) {
      bonus += GameRules.speedBonus(difficulty, _elapsedSeconds.round());
    } else {
      bonus += math.min(
        _energy * GameRules.pointsPerLeftoverEnergy,
        GameRules.maxEnergyBonus,
      );
    }
    _score += bonus;

    // Anything still hidden at this point is a mine; show it as marked.
    for (var i = 0; i < _state.length; i++) {
      if (_state[i] == CellState.hidden && board.isMine(i)) {
        _state[i] = CellState.flagged;
        _flagCount++;
      }
    }
    _selection.clear();
    return _WinPayout(bonus);
  }

  MoveResult _lose(
    LossReason reason, {
    int? explodedIndex,
    List<int> failedSalvage = const [],
  }) {
    _status = GameStatus.lost;
    _lossReason = reason;
    _selection.clear();
    return MoveResult(
      kind: explodedIndex != null ? MoveKind.explode : MoveKind.salvage,
      status: _status,
      explodedIndex: explodedIndex,
      failedSalvage: failedSalvage,
    );
  }

  /// Indices of every mine, for the reveal-everything screen after a loss.
  List<int> allMines() => [
    for (var i = 0; i < board.cellCount; i++)
      if (board.isMine(i)) i,
  ];

  // ---------------------------------------------------------- serialization
  Map<String, dynamic> toJson() => {
    'rulesVersion': GameRules.rulesVersion,
    'difficulty': difficulty.name,
    'mode': mode.name,
    'seed': seed,
    'noGuess': noGuess,
    'width': board.width,
    'height': board.height,
    'startIndex': board.startIndex,
    'mines': base64Encode(_packBits(board.mines)),
    'cells': base64Encode(_state),
    'selection': _selection.toList(),
    'status': _status.name,
    'lossReason': _lossReason?.name,
    'score': _score,
    'energy': _energy,
    'timeBoostsUsed': _timeBoostsUsed,
    'revealedCount': _revealedCount,
    'flagCount': _flagCount,
    'salvagedCount': _salvagedCount,
    'largestBatch': _largestBatch,
    'salvageBatches': _salvageBatches,
    'elapsedSeconds': _elapsedSeconds,
    'secondsRemaining': _secondsRemaining,
  };

  /// Returns null for saves written by a different rules version — an old save
  /// scored under old rules is not something we want to resume.
  static MinesweeperEngine? fromJson(Map<String, dynamic> json) {
    if (json['rulesVersion'] != GameRules.rulesVersion) return null;
    final difficulty = Difficulty.values.asNameMap()[json['difficulty']];
    final mode = GameMode.values.asNameMap()[json['mode']];
    if (difficulty == null || mode == null) return null;

    final width = json['width'] as int;
    final height = json['height'] as int;
    final mines = _unpackBits(base64Decode(json['mines'] as String), width * height);
    final board = Board.fromMines(
      width: width,
      height: height,
      mines: mines,
      startIndex: json['startIndex'] as int,
    );

    final engine = MinesweeperEngine._restore(
      board: board,
      difficulty: difficulty,
      mode: mode,
      seed: json['seed'] as int,
      noGuess: json['noGuess'] as bool? ?? false,
    );
    final cells = base64Decode(json['cells'] as String);
    if (cells.length != board.cellCount) return null;
    engine._state.setAll(0, cells);
    engine._selection
      ..clear()
      ..addAll((json['selection'] as List<dynamic>).cast<int>());
    engine._status =
        GameStatus.values.asNameMap()[json['status']] ?? GameStatus.playing;
    engine._lossReason = json['lossReason'] == null
        ? null
        : LossReason.values.asNameMap()[json['lossReason']];
    engine._score = json['score'] as int;
    engine._energy = json['energy'] as int;
    engine._timeBoostsUsed = json['timeBoostsUsed'] as int;
    engine._revealedCount = json['revealedCount'] as int;
    engine._flagCount = json['flagCount'] as int;
    engine._salvagedCount = json['salvagedCount'] as int;
    engine._largestBatch = json['largestBatch'] as int;
    engine._salvageBatches = json['salvageBatches'] as int;
    engine._elapsedSeconds = (json['elapsedSeconds'] as num).toDouble();
    engine._secondsRemaining = (json['secondsRemaining'] as num).toDouble();
    return engine;
  }

  /// Builds an engine without opening the start cell, for restoring a save.
  MinesweeperEngine._restore({
    required this.board,
    required this.difficulty,
    required this.mode,
    required this.seed,
    required this.noGuess,
  }) : _state = Uint8List(board.cellCount),
       _secondsRemaining = 0;

  static Uint8List _packBits(List<bool> bits) {
    final bytes = Uint8List((bits.length + 7) ~/ 8);
    for (var i = 0; i < bits.length; i++) {
      if (bits[i]) bytes[i >> 3] |= 1 << (i & 7);
    }
    return bytes;
  }

  static List<bool> _unpackBits(List<int> bytes, int length) {
    return [
      for (var i = 0; i < length; i++) (bytes[i >> 3] >> (i & 7)) & 1 == 1,
    ];
  }
}

class _WinPayout {
  const _WinPayout(this.scoreDelta);

  final int scoreDelta;
}
