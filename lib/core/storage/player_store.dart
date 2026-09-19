import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game_rules.dart';
import '../engine/minesweeper_engine.dart';
import '../models/game_settings.dart';
import '../models/run_stats.dart';

/// Everything that survives closing the app: settings, records, and the run
/// in progress. Local only — Minesweeppp is playable offline.
class PlayerStore {
  PlayerStore(this._prefs);

  static const _settingsKey = 'settings';
  static const _statsKey = 'stats';
  static const _saveKey = 'saved_run';

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
}
