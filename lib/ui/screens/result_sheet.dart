import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/minesweeper_engine.dart';
import '../../core/models/board_record.dart';
import '../../core/storage/player_store.dart';
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
class ResultSheet extends StatefulWidget {
  const ResultSheet({
    super.key,
    required this.engine,
    required this.store,
    this.target,
  });

  final MinesweeperEngine engine;
  final PlayerStore store;

  /// This board's record from *before* this run — captured by the caller at
  /// the start of the run, since by the time this sheet appears the run has
  /// already been folded into the store's own copy of the record. This is
  /// what "beat your own best by X" is measured against.
  final BoardRecord? target;

  @override
  State<ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> {
  late bool _pinned = widget.target?.pinned ?? false;

  MinesweeperEngine get engine => widget.engine;
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

  bool get _isNewBest {
    final previous = widget.target?.bestScore ?? 0;
    return previous > 0 && engine.score > previous;
  }

  String get _shareText {
    final chain = engine.bestChainLevel > 1
        ? ', chain x${engine.bestChainLevel}'
        : '';
    return 'Minesweeppp ${engine.levelCode.encode()} — '
        '${formatScore(engine.score)} pts '
        '(${engine.difficulty.label} · ${engine.mode.label}$chain)';
  }

  Future<void> _togglePin() async {
    final next = !_pinned;
    setState(() => _pinned = next);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.store.setPinned(engine.levelCode, next);
    if (!mounted) return;
    if (!ok) {
      // Only pinning can fail (the cap), so roll back only that direction.
      setState(() => _pinned = !next);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Up to ${PlayerStore.maxPinnedBoards} pinned boards — unpin one '
            'first.',
          ),
        ),
      );
    }
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Result copied')));
  }

  @override
  Widget build(BuildContext context) {
    final accent = _won ? Palette.success : Palette.danger;
    final code = engine.levelCode.encode();
    final target = widget.target;
    final hasComparison =
        target != null && (target.bestScore > 0 || target.rivalScore != null);

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _headline,
                    style: AppTheme.readout.copyWith(
                      color: accent,
                      fontSize: 24,
                    ),
                  ),
                ),
                if (_isNewBest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.success.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Palette.success),
                    ),
                    child: Text(
                      'NEW BEST',
                      style: AppTheme.readout.copyWith(
                        color: Palette.success,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
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
            if (hasComparison) ...[
              const SizedBox(height: 12),
              _ComparisonCard(engine: engine, target: target),
            ],
            const SizedBox(height: 16),
            _LevelCodeRow(
              code: code,
              pinned: _pinned,
              onTogglePin: _togglePin,
              onShare: _share,
            ),
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

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.engine, required this.target});

  final MinesweeperEngine engine;
  final BoardRecord target;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target.bestScore > 0)
            _ComparisonLine(
              label: 'Your best on this board',
              compareTo: target.bestScore,
              thisRun: engine.score,
            ),
          if (target.rivalScore != null) ...[
            if (target.bestScore > 0) const SizedBox(height: 6),
            _ComparisonLine(
              label: 'Rival score',
              compareTo: target.rivalScore!,
              thisRun: engine.score,
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonLine extends StatelessWidget {
  const _ComparisonLine({
    required this.label,
    required this.compareTo,
    required this.thisRun,
  });

  final String label;
  final int compareTo;
  final int thisRun;

  @override
  Widget build(BuildContext context) {
    final diff = thisRun - compareTo;
    final ahead = diff >= 0;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${formatScore(compareTo)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Palette.textSecondary, fontSize: 12),
          ),
        ),
        Text(
          ahead ? '+${formatScore(diff)}' : '-${formatScore(-diff)}',
          style: AppTheme.readout.copyWith(
            color: ahead ? Palette.success : Palette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LevelCodeRow extends StatelessWidget {
  const _LevelCodeRow({
    required this.code,
    required this.pinned,
    required this.onTogglePin,
    required this.onShare,
  });

  final String code;
  final bool pinned;
  final VoidCallback onTogglePin;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.readout.copyWith(
                    color: Palette.textPrimary,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: pinned ? 'Unpin' : 'Pin this board',
            onPressed: onTogglePin,
            icon: Icon(
              pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: pinned ? Palette.energy : Palette.textSecondary,
            ),
          ),
          IconButton(
            tooltip: 'Share result',
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, color: Palette.accent),
          ),
          IconButton(
            tooltip: 'Copy code',
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
