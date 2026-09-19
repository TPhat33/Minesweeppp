import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/level_code.dart';
import '../../core/engine/minesweeper_engine.dart';
import '../../core/models/game_settings.dart';
import '../../core/models/run_stats.dart';
import '../../core/storage/player_store.dart';
import '../../game/game_factory.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/readouts.dart';
import 'game_screen.dart';
import 'result_sheet.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final PlayerStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.beginner;
  GameMode _mode = GameMode.classic;
  late GameSettings _settings;
  MinesweeperEngine? _savedRun;

  @override
  void initState() {
    super.initState();
    _settings = widget.store.loadSettings();
    _reloadSavedRun();
  }

  void _reloadSavedRun() {
    final saved = widget.store.loadSavedRun();
    setState(() {
      _savedRun = saved;
      if (saved != null) {
        _difficulty = saved.difficulty;
        _mode = saved.mode;
      }
    });
  }

  Future<void> _play({int? seed}) async {
    final engine = await _generate(difficulty: _difficulty, mode: _mode, seed: seed);
    if (engine == null) return;
    await _runGame(engine);
  }

  Future<void> _resume() async {
    final saved = _savedRun;
    if (saved == null) return;
    await _runGame(saved);
  }

  /// Plays a run and honours whatever the results sheet asked for next, so a
  /// player can keep going without walking back through the menu.
  Future<void> _runGame(MinesweeperEngine engine) async {
    var current = engine;
    while (true) {
      if (!mounted) return;
      final next = await Navigator.of(context).push<NextRunRequest>(
        MaterialPageRoute(
          builder: (context) => GameScreen(
            engine: current,
            settings: _settings,
            store: widget.store,
          ),
        ),
      );
      if (!mounted || next == null) break;
      final replacement = await _generate(
        difficulty: next.difficulty,
        mode: next.mode,
        seed: next.seed,
      );
      if (replacement == null) break;
      current = replacement;
    }
    if (mounted) _reloadSavedRun();
  }

  /// Boards are proved guess-free before they are handed over, which takes a
  /// moment on the big presets — hence the progress dialog.
  Future<MinesweeperEngine?> _generate({
    required Difficulty difficulty,
    required GameMode mode,
    int? seed,
  }) async {
    final navigator = Navigator.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _GeneratingDialog(),
      ),
    );
    try {
      return await GameFactory.create(
        difficulty: difficulty,
        mode: mode,
        seed: seed,
      );
    } finally {
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _enterLevelCode() async {
    final controller = TextEditingController();
    final code = await showDialog<LevelCode>(
      context: context,
      builder: (context) => _LevelCodeDialog(controller: controller),
    );
    controller.dispose();
    if (code == null || !mounted) return;

    if (!code.isCurrentRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That code was made with different rules, so scores would not be '
            'comparable.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _difficulty = code.difficulty;
      _mode = code.mode;
    });
    final engine = await _generate(
      difficulty: code.difficulty,
      mode: code.mode,
      seed: code.seed,
    );
    if (engine == null) return;
    await _runGame(engine);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          store: widget.store,
          settings: _settings,
          onChanged: (value) => setState(() => _settings = value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'MINESWEEPPP',
              style: AppTheme.readout.copyWith(
                fontSize: 30,
                color: Palette.accent,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The mines are the prize. Mark them, batch them, bring them home.',
              style: TextStyle(color: Palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 22),
            if (_savedRun != null) ...[
              _ResumeCard(engine: _savedRun!, onResume: _resume),
              const SizedBox(height: 20),
            ],
            const SectionLabel('Field size'),
            ...Difficulty.values.map(
              (difficulty) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DifficultyTile(
                  difficulty: difficulty,
                  selected: difficulty == _difficulty,
                  stats: widget.store.statsFor(difficulty, _mode),
                  onTap: () => setState(() => _difficulty = difficulty),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionLabel('Mode'),
            Row(
              children: [
                for (final mode in GameMode.values) ...[
                  Expanded(
                    child: _ModeCard(
                      mode: mode,
                      selected: mode == _mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                  ),
                  if (mode != GameMode.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => _play(),
              child: const Text('START RUN'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enterLevelCode,
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('Level code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => StatsScreen(store: widget.store),
                      ),
                    ),
                    icon: const Icon(Icons.leaderboard_rounded, size: 18),
                    label: const Text('Records'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _openSettings,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _NoGuessNote(),
          ],
        ),
      ),
    );
  }
}

class _GeneratingDialog extends StatelessWidget {
  const _GeneratingDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Palette.surface,
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Checking the field is solvable…')),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.engine, required this.onResume});

  final MinesweeperEngine engine;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final cleared =
        engine.revealedCount / engine.board.safeCellCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded,
                  color: Palette.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                'Run in progress',
                style: AppTheme.readout.copyWith(fontSize: 15),
              ),
              const Spacer(),
              Text(
                '${(cleared * 100).round()}% cleared',
                style: const TextStyle(
                  color: Palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${engine.difficulty.label} · ${engine.mode.label} · '
            '${formatScore(engine.score)} pts',
            style: const TextStyle(color: Palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onResume, child: const Text('RESUME')),
        ],
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({
    required this.difficulty,
    required this.selected,
    required this.stats,
    required this.onTap,
  });

  final Difficulty difficulty;
  final bool selected;
  final RunStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Palette.surfaceHigh : Palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Palette.accent : Palette.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    difficulty.label,
                    style: AppTheme.readout.copyWith(
                      fontSize: 15,
                      color: selected ? Palette.accent : Palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${difficulty.width}x${difficulty.height} · '
                    '${difficulty.mineCount} mines · '
                    '${(difficulty.mineDensity * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (stats.bestScore > 0)
              Text(
                'best ${formatScore(stats.bestScore)}',
                style: const TextStyle(
                  color: Palette.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = mode == GameMode.classic
        ? 'No clock. Batch bonuses and a speed bonus at the end.'
        : 'Salvage charges energy: spend it on time, or bank it for points.';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Palette.surfaceHigh : Palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Palette.accent : Palette.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  mode == GameMode.classic
                      ? Icons.grid_on_rounded
                      : Icons.timer_rounded,
                  size: 16,
                  color: selected ? Palette.accent : Palette.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  mode.label,
                  style: AppTheme.readout.copyWith(
                    fontSize: 14,
                    color: selected ? Palette.accent : Palette.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: Palette.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCodeDialog extends StatelessWidget {
  const _LevelCodeDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.surface,
      title: const Text('Play a shared board'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A level code pins the field, the opening cell and the rules '
            'version, so two runs are worth comparing.',
            style: TextStyle(color: Palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'XXXX-XXXX-XXXX',
              border: OutlineInputBorder(),
            ),
            style: AppTheme.readout.copyWith(fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = LevelCode.tryDecode(controller.text);
            if (code == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('That code is not valid.')),
              );
              return;
            }
            Navigator.of(context).pop(code);
          },
          child: const Text('Play it'),
        ),
      ],
    );
  }
}

class _NoGuessNote extends StatelessWidget {
  const _NoGuessNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, size: 18, color: Palette.success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Every field is replayed by a solver before you see it. If logic '
              'cannot clear it, you never get dealt it.',
              style: TextStyle(
                color: Palette.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
