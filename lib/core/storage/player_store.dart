import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game_rules.dart';
import '../engine/level_code.dart';
import '../engine/minesweeper_engine.dart';
import '../models/board_record.dart';
import '../models/game_settings.dart';
import '../models/run_stats.dart';

/// Everything that survives closing the app: settings, records, and the run
/// in progress. Local only — Minesweeppp is playable offline.
class PlayerStore {
  PlayerStore(this._prefs);

  static const _settingsKey = 'settings';
  static const _statsKey = 'stats';
  static const _saveKey = 'saved_run';
  static const _boardsKey = 'boards';

  /// Board records are stored as one JSON blob, rewritten in full on every
  /// change — the same trade-off [_statsKey] already makes. Capped so that
  /// write never grows unbounded over the life of the app.
  static const maxBoardRecords = 60;

  /// A pinned board is the player's own "keep this one" and is exempt from
  /// eviction, but it still needs its own ceiling or a determined pinner
  /// could make eviction unable to ever free space.
  static const maxPinnedBoards = 12;

  final SharedPreferences _prefs;

  static Future<PlayerStore> open() async =>
      PlayerStore(await SharedPreferences.getInstance());

  // --------------------------------------------------------------- settings
  GameSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const GameSettings();
    try {
      return GameSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const GameSettings();
    }
  }

  Future<void> saveSettings(GameSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  // ------------------------------------------------------------------ stats
  Map<String, RunStats> loadStats() {
    final raw = _prefs.getString(_statsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: RunStats.fromJson(entry.value as Map<String, dynamic>),
      };
    } on FormatException {
      return {};
    }
  }

  RunStats statsFor(Difficulty difficulty, GameMode mode) =>
      loadStats()[RunStats.keyFor(difficulty, mode)] ?? const RunStats();

  Future<void> recordRun(MinesweeperEngine engine) async {
    final stats = loadStats();
    final key = RunStats.keyFor(engine.difficulty, engine.mode);
    stats[key] = (stats[key] ?? const RunStats()).recordRun(
      victory: engine.status == GameStatus.won,
      score: engine.score,
      elapsedSeconds: engine.elapsedSeconds.round(),
      largestBatch: engine.largestBatch,
      minesSalvaged: engine.salvagedCount,
      bestChain: engine.bestChainLevel,
    );
    await _prefs.setString(
      _statsKey,
      jsonEncode({for (final e in stats.entries) e.key: e.value.toJson()}),
    );
  }

  Future<void> clearStats() => _prefs.remove(_statsKey);

  // ------------------------------------------------------------- saved runs
  /// Keeps one run in progress. Finished runs are cleared so the menu never
  /// offers to resume a board that is already over.
  Future<void> saveRun(MinesweeperEngine engine) {
    if (engine.isOver) return clearSavedRun();
    return _prefs.setString(_saveKey, jsonEncode(engine.toJson()));
  }

  MinesweeperEngine? loadSavedRun() {
    final raw = _prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      final engine = MinesweeperEngine.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (engine == null || engine.isOver) return null;
      return engine;
    } on FormatException {
      return null;
    }
  }

  Future<void> clearSavedRun() => _prefs.remove(_saveKey);

  // ----------------------------------------------------------------- boards
  Map<String, BoardRecord> loadBoards() {
    final raw = _prefs.getString(_boardsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final boards = <String, BoardRecord>{};
      for (final entry in decoded.entries) {
        final record = BoardRecord.fromJson(entry.value as Map<String, dynamic>);
        if (record != null) boards[entry.key] = record;
      }
      return boards;
    } on FormatException {
      return {};
    }
  }

  BoardRecord? boardFor(LevelCode code) => loadBoards()[code.encode()];

  Future<void> _saveBoards(Map<String, BoardRecord> boards) => _prefs.setString(
    _boardsKey,
    jsonEncode({for (final e in boards.entries) e.key: e.value.toJson()}),
  );

  /// Folds the just-finished run into its board's record: best score and
  /// chain both only ever go up, `cleared` latches true the first time the
  /// board is won, and a rival score set earlier survives untouched — this
  /// only ever adds to what the player already knows about a board, never
  /// overwrites the one thing (the rival's number) it did not measure itself.
  Future<void> recordBoard(MinesweeperEngine engine) async {
    final boards = loadBoards();
    final code = engine.levelCode.encode();
    final existing = boards[code];
    final now = DateTime.now().millisecondsSinceEpoch;

    boards[code] = existing == null
        ? BoardRecord(
            code: code,
            difficulty: engine.difficulty,
            mode: engine.mode,
            seed: engine.seed,
            bestScore: engine.score,
            bestChain: engine.bestChainLevel,
            cleared: engine.status == GameStatus.won,
            playCount: 1,
            updatedAtMs: now,
          )
        : existing.copyWith(
            bestScore: math.max(existing.bestScore, engine.score),
            bestChain: math.max(existing.bestChain, engine.bestChainLevel),
            cleared: existing.cleared || engine.status == GameStatus.won,
            playCount: existing.playCount + 1,
            updatedAtMs: now,
          );

    await _saveBoards(_evictBoards(boards));
  }

  /// Sets or clears the score a friend reported for [code]'s board, creating
  /// the record if the player has not actually played it yet — the "their
  /// score" field can be filled in before a run starts.
  Future<void> setRivalScore(LevelCode code, int? score) async {
    final boards = loadBoards();
    final key = code.encode();
    final existing = boards[key];
    final now = DateTime.now().millisecondsSinceEpoch;

    boards[key] = existing == null
        ? BoardRecord(
            code: key,
            difficulty: code.difficulty,
            mode: code.mode,
            seed: code.seed,
            bestScore: 0,
            bestChain: 0,
            cleared: false,
            playCount: 0,
            rivalScore: score,
            updatedAtMs: now,
          )
        : existing.copyWith(
            rivalScore: score,
            clearRivalScore: score == null,
            updatedAtMs: now,
          );

    await _saveBoards(_evictBoards(boards));
  }

  /// Returns false (and changes nothing) when trying to pin would exceed
  /// [maxPinnedBoards], or when [code]'s board has no record to pin yet.
  Future<bool> setPinned(LevelCode code, bool pinned) async {
    final boards = loadBoards();
    final key = code.encode();
    final existing = boards[key];
    if (existing == null) return false;
    if (pinned && !existing.pinned) {
      final pinnedCount = boards.values.where((b) => b.pinned).length;
      if (pinnedCount >= maxPinnedBoards) return false;
    }
    boards[key] = existing.copyWith(pinned: pinned);
    await _saveBoards(boards); // pinning never evicts anything itself
    return true;
  }

  Future<void> clearBoards() => _prefs.remove(_boardsKey);

  /// Drops the oldest-by-[BoardRecord.updatedAtMs] unpinned records once the
  /// log grows past [maxBoardRecords]. Pinned records are never touched —
  /// that is the whole point of pinning one.
  Map<String, BoardRecord> _evictBoards(Map<String, BoardRecord> boards) {
    final over = boards.length - maxBoardRecords;
    if (over <= 0) return boards;

    final evictable = boards.entries.where((e) => !e.value.pinned).toList()
      ..sort((a, b) => a.value.updatedAtMs.compareTo(b.value.updatedAtMs));

    final result = Map<String, BoardRecord>.from(boards);
    for (final entry in evictable.take(over)) {
      result.remove(entry.key);
    }
    return result;
  }
}
