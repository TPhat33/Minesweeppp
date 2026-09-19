import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

/// Every effect in the game, named for what it means rather than what file it
/// happens to be. All fifteen are synthesized (see `tool/synth_sfx.py`) —
/// there are no third-party audio assets to license or attribute.
enum SoundEffect {
  /// One cell opens.
  reveal('sfx/reveal.wav'),

  /// A flood reveal opens a cluster of cells at once.
  revealWave('sfx/reveal_wave.wav'),

  flag('sfx/flag.wav'),
  unflag('sfx/unflag.wav'),

  /// A flagged mine joins the salvage batch.
  select('sfx/select.wav'),

  /// A flagged mine leaves the salvage batch.
  deselect('sfx/deselect.wav'),

  /// A batch of one or two mines is cashed in.
  salvageSmall('sfx/salvage_small.wav'),

  /// A batch of three or more mines is cashed in — the payoff moment.
  salvageBatch('sfx/salvage_batch.wav'),

  /// A batch included a cell that was not a mine.
  salvageFail('sfx/salvage_fail.wav'),

  /// A mine was opened directly.
  explode('sfx/explode.wav'),

  timeout('sfx/timeout.wav'),
  win('sfx/win.wav'),

  /// Energy spent for extra time in timed mode.
  boost('sfx/boost.wav'),

  /// The pause menu opens.
  pause('sfx/pause.wav');

  const SoundEffect(this.asset);

  /// Path relative to [FlameAudio.audioCache]'s `assets/audio/` prefix.
  final String asset;
}

/// A thin, deliberately forgiving wrapper around `flame_audio`.
///
/// Sound is a nicety, never a requirement: a headless test environment, a
/// platform with no audio backend, or a device with no output should never
/// turn a missed sound effect into a crashed frame. Every failure here is
/// swallowed rather than propagated.
class SoundManager {
  static bool _preloaded = false;

  /// Loads every effect into memory once, so the first play of each has no
  /// latency. Safe to call more than once, and safe to call where no asset
  /// bundle or audio backend is available — [play] will simply keep failing
  /// silently per call in that case.
  static Future<void> preload() async {
    if (_preloaded) return;
    try {
      await FlameAudio.audioCache.loadAll([
        for (final effect in SoundEffect.values) effect.asset,
      ]);
      _preloaded = true;
    } catch (_) {
      // No asset bundle, no audio backend, or an unsupported platform.
    }
  }

  /// Fires an effect and returns immediately; playback happens in the
  /// background and any failure is dropped.
  void play(SoundEffect effect, {double volume = 1.0}) {
    unawaited(_safePlay(effect, volume));
  }

  Future<void> _safePlay(SoundEffect effect, double volume) async {
    try {
      await FlameAudio.play(effect.asset, volume: volume);
    } catch (_) {
      // Missing plugin (tests, unsupported platform), a decode failure, or
      // no audio device: none of these should ever interrupt play.
    }
  }
}
