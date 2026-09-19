# Minesweeppp

A Minesweeper where **the mines are the prize**. You still read the numbers and
mark the mines — but instead of just avoiding them, you queue the ones you are
sure about and cash them in as a batch. Bigger batch, bigger payout. One wrong
cell in the batch and the run is over.

Built with **Flutter + Flame**, one codebase for iOS and Android.

---

## The salvage rule

1. Flag cells as usual to note where you think the mines are.
2. Tap a flag to add it to the **salvage batch**.
3. Hit `SALVAGE` to cash the batch in.

| Batch | Base | Batch bonus | Total |
| ----- | ---- | ----------- | ----- |
| 1     | 100  | 0           | 100   |
| 3     | 300  | 60          | 360   |
| 5     | 500  | 200         | 700   |

The bonus is `10 × n × (n − 1)`, so waiting to build a bigger batch always beats
cashing in one at a time — and every extra cell you add is one more chance to be
wrong. Each mine can only be scored once.

**A salvaged mine still counts towards every neighbouring number.** The board
you reason from never changes under you; a recovered mine simply shows as a
canister instead of a flag.

## Modes

- **Classic** — no clock. Batch bonuses, plus a speed bonus for finishing under
  par.
- **Timed** — salvaging charges energy. Spend 30 energy for +15 seconds (four
  times per run at most), or bank it: unspent energy pays 4 points each on a
  win, capped at 1200. The choice is the mode.

## Difficulties

| Preset       | Board | Mines | Density | Timed clock |
| ------------ | ----- | ----- | ------- | ----------- |
| Beginner     | 9×9   | 10    | 12.3%   | 4:00        |
| Intermediate | 16×16 | 40    | 15.6%   | 7:00        |
| Expert       | 30×16 | 99    | 20.6%   | 10:00       |
| Master       | 30×20 | 130   | 21.7%   | 13:00       |
| Legendary    | 32×24 | 175   | 22.8%   | 16:00       |

## No guessing, and it is checked

Every board is replayed by a solver before you are dealt it: count rules, the
subset rule, then per-group enumeration cross-checked against the global mine
count. If logic cannot clear it, the generator rerolls. Measured on this
machine, over eight boards per preset:

```
Beginner      density=12.3%  avgTime=1ms    worst=10ms   fallbacks=0/8
Intermediate  density=15.6%  avgTime=13ms   worst=38ms   fallbacks=0/8
Expert        density=20.6%  avgTime=7ms    worst=14ms   fallbacks=0/8
Master        density=21.7%  avgTime=75ms   worst=292ms  fallbacks=0/8
Legendary     density=22.8%  avgTime=120ms  worst=388ms  fallbacks=0/8
```

Re-run it yourself with `dart run tool/bench_generator.dart 8`.

Generation happens in an isolate, so it never costs a frame. In the rare case
the generator runs out of budget it hands back the closest board it found and
the HUD says so, rather than pretending.

## Level codes

Every run has a code like `04GN-REMH-YBK0`. It pins the rules version, the
difficulty, the mode and the seed — and the seed fixes both the minefield *and*
the opening cell, so two people playing the same code get the identical board
and their scores are worth comparing. Codes carry a checksum, so a typo is
rejected instead of quietly becoming a different board.

## Playing on a phone

The things that decide whether a board game is pleasant on a touchscreen got the
same attention as the scoring:

- **Tap and drag are kept apart.** A tap only registers if the finger barely
  moved; panning starts once it clearly has; a second finger pinches and never
  plays a move.
- **A mode toggle**, so flagging does not require holding every time. Long press
  still does the other action, and that can be turned off.
- **Tap a satisfied number to chord**, with the cells about to open highlighted
  while your finger is down. A wrong flag still loses — chording trusts you.
- **Zoom is clamped** so a cell never shrinks below 19px: numbers stay readable
  and targets stay tappable even on Legendary.
- **Animations never block input.** The reveal ripple, salvage beam and shake
  are all under a second, and every one of them can be switched off.
- **Runs survive closing the app.** Board, marks, score and clock are saved.

## Sound

Every effect is synthesized, not sourced — `tool/synth_sfx.py` generates all
14 `.wav` files in `assets/audio/sfx/` from scratch with plain oscillators and
noise (no `numpy`, just `math` and `wave`). That sidesteps licensing entirely,
and a set of digital bleeps and chimes suits a salvage rig better than
realistic foley would anyway. Regenerate the bank with:

```sh
python3 tool/synth_sfx.py assets/audio/sfx
```

Reveal, flood reveal, flag, unflag, batch-select, batch-deselect, small
salvage, big-batch salvage, bad salvage, explosion, timeout, win, the energy
boost, and opening the pause menu each get a distinct cue — routed through
`GameSession`, the same place haptics are chosen, so the two always agree on
what just happened. `FlameAudio.audioCache` preloads the whole bank once at
startup without blocking it; playback never throws even with no audio backend
available (a headless test, an unsupported platform, no output device), which
is what lets `flutter test` run clean in this sandbox with no audio plugin
registered. Toggled independently of haptics and animations in Settings.

## Layout

```
lib/
  core/engine/      rules, board, solver, generator, level codes — no Flutter
  core/models/      settings and records
  core/storage/     local persistence
  game/             Flame: board rendering, camera, effects, session glue
  game/audio/       sound effect enum + the playback wrapper
  ui/               menus, HUD, theme, pointer handling
assets/audio/sfx/   synthesized sound effects (see tool/synth_sfx.py)
test/engine/        rules, solver, generation, serialization
test/ui/            gestures, HUD, results, sound routing
tool/               bench_generator.dart, synth_sfx.py
```

The engine has no dependency on Flutter or Flame. That is what lets the solver
replay boards, and the tests drive the rules directly.

## Running it

```sh
flutter pub get
flutter run                  # a connected device or emulator
flutter test                 # 116 tests
flutter analyze
```

Requires Flutter 3.47 or newer (developed against 3.47.5 / Dart 3.13.4).
Building for iOS needs macOS and Xcode; see the
[Flutter iOS deployment docs](https://docs.flutter.dev/deployment/ios).

> **Note on `path_provider_android`:** a recent release moved its Android
> implementation onto JNI bindings, so building for Android now runs a native
> build-hook step that needs the Android SDK present — even for
> `flutter build bundle`, not just `apk`/`appbundle`. Nothing to do about it
> from this repo; a normal Android SDK install (Android Studio, or
> `sdkmanager`) satisfies it.

## Not in this version

Deliberately left for later, so the first build stays small enough to balance:

- side missions (open a path, clear marked cells, batch-of-four targets)
- daily challenge and leaderboards
- online play
