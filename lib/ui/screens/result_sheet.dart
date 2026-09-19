import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/minesweeper_engine.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/readouts.dart';

/// What the player chose to do after a run.
enum ResultAction { playAgain, retryBoard, menu }

/// Tells the menu which run to start next. A null [seed] means a fresh board.
class NextRunRequest {
  const NextRunRequest({
    required this.difficulty,
    required this.mode,
    this.seed,
  });

  final Difficulty difficulty;
  final GameMode mode;
  final int? seed;
}

/// End-of-run summary: what happened, what it scored, and the code to send a
/// friend so they can try the same board.
class ResultSheet extends StatelessWidget {
  const ResultSheet({super.key, required this.engine});

  final MinesweeperEngine engine;

  bool get _won => engine.status == GameStatus.won;

  String get _headline {
    if (_won) return 'BOARD CLEAR';
    return switch (engine.lossReason) {
      LossReason.badSalvage => 'BAD CALL',
      LossReason.timeout => 'OUT OF TIME',
      _ => 'DETONATED',
    };
  }

  String get _subtitle {
    if (_won) {
      return engine.salvagedCount == engine.board.mineCount
          ? 'Every mine recovered.'
          : '${engine.salvagedCount} of ${engine.board.mineCount} mines recovered.';
    }
    return switch (engine.lossReason) {
      LossReason.badSalvage =>
        'One of the cells in that batch was not a mine.',
      LossReason.timeout => 'The clock beat you to it.',
      _ => 'That cell was a mine.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _won ? Palette.success : Palette.danger;
    final code = engine.levelCode.encode();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _headline,
              style: AppTheme.readout.copyWith(color: accent, fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle,
              style: const TextStyle(
                color: Palette.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatChip(
                  icon: Icons.auto_awesome_rounded,
                  value: formatScore(engine.score),
                  label: 'score',
                  color: Palette.accent,
                  emphasis: true,
                ),
                StatChip(
                  icon: Icons.schedule_rounded,
                  value: formatClock(engine.elapsedSeconds),
                  label: 'time',
                ),
                StatChip(
                  icon: Icons.bolt_rounded,
                  value: '${engine.salvagedCount}',
                  label: 'salvaged',
                  color: Palette.energy,
                ),
                if (engine.largestBatch > 1)
                  StatChip(
                    icon: Icons.workspaces_rounded,
                    value: '${engine.largestBatch}',
                    label: 'best batch',
                    color: Palette.energy,
                  ),
                if (engine.bestChainLevel > 1)
                  StatChip(
                    icon: Icons.link_rounded,
                    value: 'x${engine.bestChainLevel}',
                    label: 'best chain',
                    color: Palette.energy,
                  ),
                if (engine.mode == GameMode.timed && engine.energy > 0)
                  StatChip(
                    icon: Icons.battery_charging_full_rounded,
                    value: '${engine.energy}',
                    label: 'energy banked',
                    color: Palette.energy,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _LevelCodeRow(code: code),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(ResultAction.retryBoard),
                    child: const Text('Same board'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(ResultAction.playAgain),
                    child: const Text('New board'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ResultAction.menu),
              child: const Text('Back to menu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCodeRow extends StatelessWidget {
  const _LevelCodeRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LEVEL CODE',
                  style: TextStyle(
                    color: Palette.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: AppTheme.readout.copyWith(
                    color: Palette.textPrimary,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () => copyLevelCode(context, code),
            icon: const Icon(Icons.copy_rounded, color: Palette.accent),
          ),
        ],
      ),
    );
  }
}

/// Copies a level code and confirms it, so a player can paste it to a friend.
Future<void> copyLevelCode(BuildContext context, String code) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: code));
  messenger.showSnackBar(
    SnackBar(content: Text('Level code $code copied')),
  );
}
