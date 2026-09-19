import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/level_code.dart';
import '../../core/models/board_record.dart';
import '../../core/models/run_stats.dart';
import '../../core/storage/player_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/readouts.dart';

/// Personal records, one card per difficulty, split by mode, plus every
/// individual board the player has kept a log of. Tapping "Play it" on a
/// board pops this screen with that board's [LevelCode] — the caller (home
/// screen) is the one that actually starts the run, through the same path a
/// pasted level code takes.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.store});

  final PlayerStore store;

  @override
  Widget build(BuildContext context) {
    final anyPlayed = Difficulty.values.any(
      (difficulty) => GameMode.values.any(
        (mode) => store.statsFor(difficulty, mode).played > 0,
      ),
    );
    final boards = store.loadBoards().values.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAtMs.compareTo(a.updatedAtMs);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Records')),
      body: anyPlayed || boards.isNotEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                for (final difficulty in Difficulty.values) ...[
                  _DifficultyCard(difficulty: difficulty, store: store),
                  const SizedBox(height: 12),
                ],
                if (boards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionLabel('Boards'),
                  const SizedBox(height: 8),
                  for (final record in boards) ...[
                    _BoardRow(record: record),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            )
          : const _EmptyState(),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.record});

  final BoardRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline),
      ),
      child: Row(
        children: [
          if (record.pinned) ...[
            const Icon(
              Icons.push_pin_rounded,
              size: 15,
              color: Palette.energy,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.readout.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.difficulty.label} · ${record.mode.label} · '
                  'best ${formatScore(record.bestScore)}'
                  '${record.rivalScore != null ? ' · rival ${formatScore(record.rivalScore!)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pop<LevelCode>(record.toLevelCode()),
            child: const Text('Play it'),
          ),
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({required this.difficulty, required this.store});

  final Difficulty difficulty;
  final PlayerStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            difficulty.label,
            style: AppTheme.readout.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            '${difficulty.width}x${difficulty.height} · ${difficulty.mineCount} mines',
            style: const TextStyle(color: Palette.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final mode in GameMode.values)
            _ModeRow(mode: mode, stats: store.statsFor(difficulty, mode)),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode, required this.stats});

  final GameMode mode;
  final RunStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.played == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                mode.label,
                style: const TextStyle(
                  color: Palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const Text(
              'not played yet',
              style: TextStyle(color: Palette.outline, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  mode.label,
                  style: AppTheme.readout.copyWith(
                    fontSize: 12,
                    color: Palette.accent,
                  ),
                ),
              ),
              Text(
                '${stats.won}/${stats.played} cleared · '
                '${(stats.winRate * 100).round()}%',
                style: const TextStyle(
                  color: Palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatChip(
                icon: Icons.auto_awesome_rounded,
                value: formatScore(stats.bestScore),
                label: 'best',
                color: Palette.accent,
              ),
              if (stats.bestTimeSeconds != null)
                StatChip(
                  icon: Icons.schedule_rounded,
                  value: formatClock(stats.bestTimeSeconds!),
                  label: 'fastest',
                ),
              if (stats.largestBatch > 0)
                StatChip(
                  icon: Icons.workspaces_rounded,
                  value: '${stats.largestBatch}',
                  label: 'best batch',
                  color: Palette.energy,
                ),
              if (stats.bestChain > 1)
                StatChip(
                  icon: Icons.link_rounded,
                  value: 'x${stats.bestChain}',
                  label: 'best chain',
                  color: Palette.energy,
                ),
              if (stats.minesSalvaged > 0)
                StatChip(
                  icon: Icons.bolt_rounded,
                  value: '${stats.minesSalvaged}',
                  label: 'salvaged',
                  color: Palette.energy,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_rounded, size: 40, color: Palette.outline),
            SizedBox(height: 12),
            Text(
              'Nothing here yet. Finish a run and your best score, fastest '
              'clear and biggest batch land here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
