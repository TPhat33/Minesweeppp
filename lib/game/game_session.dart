import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/engine/game_rules.dart';
import '../core/engine/minesweeper_engine.dart';
import '../core/engine/move_result.dart';
import '../core/models/game_settings.dart';
import '../core/storage/player_store.dart';
import 'audio/sound_manager.dart';

/// Owns one run: it turns taps into engine calls, keeps the clock going,
/// autosaves, and hands every [MoveResult] to the renderer so it can play the
/// matching effect.
///
/// The engine stays free of Flutter; this is where the two meet.
class GameSession extends ChangeNotifier {
  GameSession({
    required this.engine,
    required GameSettings settings,
    required this.store,
  }) : _settings = settings,
       _inputMode = settings.defaultInputMode;


  final MinesweeperEngine engine;
  final PlayerStore store;

  GameSettings _settings;
  InputMode _inputMode;
  List<int> _chordPreview = const [];
  bool _paused = false;
  bool _recorded = false;
  bool _disposed = false;
  bool _notifyPending = false;
  double _sinceSave = 0;
  final SoundManager _sound = SoundManager();

  /// Effects sink. The Flame layer sets this; nothing else listens.
  void Function(MoveResult result)? onMove;

  GameSettings get settings => _settings;
  InputMode get inputMode => _inputMode;

  /// Cells a chord would open, highlighted while the finger is down.
  List<int> get chordPreview => _chordPreview;

  bool get paused => _paused;
  bool get isOver => engine.isOver;

  set settings(GameSettings value) {
    _settings = value;
    _notify();
  }

  void setInputMode(InputMode mode) {
    if (_inputMode == mode) return;
    _inputMode = mode;
    _buzz(HapticFeedback.selectionClick);
    _notify();
  }

  void toggleInputMode() => setInputMode(
    _inputMode == InputMode.reveal ? InputMode.flag : InputMode.reveal,
  );

  void setPaused(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (value) {
      unawaited(save());
      _chime(SoundEffect.pause);
    }
    _notify();
  }

  // ------------------------------------------------------------------ input
  /// A plain tap.
  ///
  /// * an open number chords, which is the fast way to clear a board;
  /// * a flag joins or leaves the salvage batch — this is how the player says
  ///   "I am sure about this one";
  /// * anything else follows the reveal/flag toggle.
  void tapCell(int index) {
    if (_paused || engine.isOver) return;
    final state = engine.stateOf(index);

    final MoveResult result;
    if (state == CellState.revealed) {
      result = engine.chord(index);
    } else if (state == CellState.flagged && _inputMode == InputMode.reveal) {
      result = engine.toggleSalvageSelection(index);
    } else if (_inputMode == InputMode.flag) {
      result = engine.toggleFlag(index);
    } else {
      result = engine.reveal(index);
    }
    _afterMove(result);
  }

  /// A long press always does the *other* thing, so both actions stay reachable
  /// without visiting the toggle.
  void longPressCell(int index) {
    if (_paused || engine.isOver) return;
    if (!_settings.longPressToFlag) return;
    final state = engine.stateOf(index);

    final MoveResult result;
    if (_inputMode == InputMode.reveal) {
      result = engine.toggleFlag(index);
    } else if (state == CellState.hidden) {
      result = engine.reveal(index);
    } else {
      result = engine.toggleFlag(index);
    }
    _afterMove(result);
  }

  /// Shows which cells a chord would open while the finger is still down.
  void previewChord(int? index) {
    final next = index == null ? const <int>[] : engine.chordTargets(index);
    if (listEquals(next, _chordPreview)) return;
    _chordPreview = next;
    _notify();
  }

  void selectAllFlags() {
    if (engine.isOver) return;
    _afterMove(engine.selectAllFlags());
  }

  void clearSelection() {
    if (engine.isOver) return;
    _afterMove(engine.clearSelection());
  }

  void commitSalvage() {
    if (engine.isOver || engine.selectionSize == 0) return;
    _afterMove(engine.commitSalvage());
  }

  void spendEnergyForTime() {
    if (!engine.canSpendEnergyForTime) return;
    engine.spendEnergyForTime();
    _buzz(HapticFeedback.mediumImpact);
    _chime(SoundEffect.boost);
    _notify();
  }

  // ------------------------------------------------------------------ clock
  /// Driven by the Flame game loop.
  void tick(double dt) {
    if (_paused || engine.isOver) return;
    final result = engine.tick(dt);
    if (result != null) {
      _afterMove(result);
      return;
    }
    _sinceSave += dt;
    if (_sinceSave >= 4) {
      _sinceSave = 0;
      unawaited(save());
    }
    // The HUD clock wants a repaint every frame.
    _notify();
  }

  Future<void> save() => store.saveRun(engine);

  /// Flame runs [tick] from inside the frame's build phase, and notifying
  /// listeners there would mark widgets dirty mid-build. Deferring to a
  /// microtask lands the rebuild right after the frame instead, which is both
  /// legal and soon enough for a clock.
  void _notify() {
    if (_disposed || _notifyPending) return;
    _notifyPending = true;
    scheduleMicrotask(() {
      _notifyPending = false;
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    onMove = null;
    super.dispose();
  }

  // ---------------------------------------------------------------- effects
  void _afterMove(MoveResult result) {
    if (!result.changed) return;
    _chordPreview = const [];
    onMove?.call(result);
    _feedbackFor(result);
    _soundFor(result);
    if (engine.isOver) unawaited(_finishRun());
    _notify();
  }

  Future<void> _finishRun() async {
    if (_recorded) return;
    _recorded = true;
    await store.recordRun(engine);
    await store.recordBoard(engine);
    await store.clearSavedRun();
  }

  /// Distinct feel per outcome: a salvage should not feel like a reveal, and
  /// losing should be unmistakable even with the sound off.
  void _feedbackFor(MoveResult result) {
    switch (result.kind) {
      case MoveKind.flag:
      case MoveKind.unflag:
      case MoveKind.select:
        _buzz(HapticFeedback.selectionClick);
      case MoveKind.salvage:
        if (result.isFatal) {
          _buzz(HapticFeedback.heavyImpact);
        } else if (result.batchSize >= 3 || result.chainLevel >= 3) {
          _buzz(HapticFeedback.heavyImpact);
        } else {
          _buzz(HapticFeedback.mediumImpact);
        }
      case MoveKind.explode:
        _buzz(HapticFeedback.heavyImpact);
      case MoveKind.reveal:
      case MoveKind.chord:
        if (result.revealed.length > 12) _buzz(HapticFeedback.lightImpact);
      case MoveKind.none:
        break;
    }
  }

  void _buzz(Future<void> Function() feedback) {
    if (!_settings.haptics) return;
    unawaited(feedback());
  }

  /// Which cue plays for a move. The end-of-run cases are checked first and
  /// take over the whole move, since "you won" or "you lost" matters more
  /// than whatever action triggered it.
  void _soundFor(MoveResult result) {
    if (result.status == GameStatus.won) {
      _chime(SoundEffect.win);
      return;
    }
    if (result.status == GameStatus.lost) {
      switch (engine.lossReason) {
        case LossReason.mineRevealed:
          _chime(SoundEffect.explode);
        case LossReason.badSalvage:
          _chime(SoundEffect.salvageFail);
        case LossReason.timeout:
          _chime(SoundEffect.timeout);
        case null:
          break;
      }
      return;
    }

    switch (result.kind) {
      case MoveKind.reveal:
      case MoveKind.chord:
        if (result.revealed.length > 8) {
          _chime(SoundEffect.revealWave);
        } else if (result.revealed.isNotEmpty) {
          _chime(SoundEffect.reveal);
        }
      case MoveKind.flag:
        _chime(SoundEffect.flag);
      case MoveKind.unflag:
        _chime(SoundEffect.unflag);
      case MoveKind.select:
        if (result.selected.isNotEmpty) {
          _chime(SoundEffect.select);
        } else if (result.deselected.isNotEmpty) {
          _chime(SoundEffect.deselect);
        }
      case MoveKind.salvage:
        _chime(
          result.batchSize >= 3
              ? SoundEffect.salvageBatch
              : SoundEffect.salvageSmall,
        );
        // A chain worth noticing gets its own layer rather than a dedicated
        // sound file: a light boost chime under the salvage cue reads as
        // "and then some" without adding to the synthesized bank in
        // tool/synth_sfx.py for what is, musically, the same shape of event.
        if (result.chainLevel >= 3) {
          _chime(SoundEffect.boost, volume: 0.6);
        }
      case MoveKind.explode:
        _chime(SoundEffect.explode);
      case MoveKind.none:
        break;
    }
  }

  void _chime(SoundEffect effect, {double volume = 1.0}) {
    if (!_settings.sfx) return;
    _sound.play(effect, volume: volume);
  }
}
