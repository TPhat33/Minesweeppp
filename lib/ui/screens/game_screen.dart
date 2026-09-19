import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/minesweeper_engine.dart';
import '../../core/models/game_settings.dart';
import '../../core/storage/player_store.dart';
import '../../game/game_session.dart';
import '../../game/minesweeper_game.dart';
import '../theme/palette.dart';
import '../widgets/board_view.dart';
import '../widgets/energy_meter.dart';
import '../widgets/hud_bar.dart';
import '../widgets/readouts.dart';
import '../widgets/salvage_bar.dart';
import 'result_sheet.dart';

/// One run, from first tap to the results sheet.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.engine,
    required this.settings,
    required this.store,
  });

  final MinesweeperEngine engine;
  final GameSettings settings;
  final PlayerStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameSession _session;
  late final MinesweeperGame _game;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = GameSession(
      engine: widget.engine,
      settings: widget.settings,
      store: widget.store,
    )..addListener(_onSessionChanged);
    _game = MinesweeperGame(session: _session);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app pauses the clock and writes the run to disk, so coming
    // back lands exactly where the player left off.
    if (state != AppLifecycleState.resumed) {
      _session.setPaused(true);
    }
  }

  void _onSessionChanged() {
    if (!_session.isOver || _resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    // Let the explosion or the salvage beam finish before the sheet covers it.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final action = await showModalBottomSheet<ResultAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => ResultSheet(engine: _session.engine),
    );
    if (!mounted) return;

    final engine = _session.engine;
    Navigator.of(context).pop(switch (action) {
      ResultAction.playAgain => NextRunRequest(
        difficulty: engine.difficulty,
        mode: engine.mode,
      ),
      ResultAction.retryBoard => NextRunRequest(
        difficulty: engine.difficulty,
        mode: engine.mode,
        seed: engine.seed,
      ),
      ResultAction.menu || null => null,
    });
  }

  Future<void> _confirmSalvage() async {
    final engine = _session.engine;
    if (engine.selectionSize == 0) return;
    if (!_session.settings.confirmSalvage || engine.selectionSize == 1) {
      _session.commitSalvage();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surface,
        title: const Text('Salvage the batch?'),
        content: Text(
          '${engine.selectionSize} marked for +${engine.pendingSalvageScore}.\n'
          'If even one of them is not a mine, the run ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvage'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) _session.commitSalvage();
  }

  Future<void> _openPauseMenu() async {
    _session.setPaused(true);
    final action = await showDialog<_PauseAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PauseDialog(engine: _session.engine),
    );
    if (!mounted) return;
    switch (action) {
      case _PauseAction.quit:
        await _session.save();
        if (mounted) Navigator.of(context).pop(null);
      case _PauseAction.resume:
      case null:
        _session.setPaused(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = _session.engine;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _openPauseMenu();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: BoardView(game: _game, session: _session),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    ListenableBuilder(
                      listenable: _session,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HudBar(engine: engine, onPause: _openPauseMenu),
                          if (engine.mode == GameMode.timed) ...[
                            const SizedBox(height: 8),
                            EnergyMeter(
                              energy: engine.energy,
                              boostsLeft: engine.timeBoostsLeft,
                              canBoost: engine.canSpendEnergyForTime,
                              onBoost: _session.spendEnergyForTime,
                            ),
                          ],
                          if (!engine.noGuess) ...[
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: GuessWarning(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    ListenableBuilder(
                      listenable: _session,
                      builder: (context, _) => SalvageBar(
                        inputMode: _session.inputMode,
                        onInputModeChanged: _session.setInputMode,
                        selectionSize: engine.selectionSize,
                        pendingScore: engine.pendingSalvageScore,
                        pendingBonus: engine.pendingBatchBonus,
                        flagCount: engine.flagCount,
                        onSalvage: _confirmSalvage,
                        onClear: _session.clearSelection,
                        onSelectAll: _session.selectAllFlags,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PauseAction { resume, quit }

class _PauseDialog extends StatelessWidget {
  const _PauseDialog({required this.engine});

  final MinesweeperEngine engine;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.surface,
      title: const Text('Paused'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${engine.difficulty.label} · ${engine.mode.label}',
            style: const TextStyle(color: Palette.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                icon: Icons.auto_awesome_rounded,
                value: formatScore(engine.score),
                color: Palette.accent,
              ),
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.bolt_rounded,
                value: '${engine.salvagedCount}',
                label: 'salvaged',
                color: Palette.energy,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Your run is saved. You can close the app and pick it up later.',
            style: TextStyle(color: Palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_PauseAction.quit),
          child: const Text('Save and leave'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_PauseAction.resume),
          child: const Text('Resume'),
        ),
      ],
    );
  }
}
