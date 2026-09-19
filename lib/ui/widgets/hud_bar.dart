import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/minesweeper_engine.dart';
import '../theme/palette.dart';
import 'readouts.dart';

/// Top-of-screen readouts: what is left, how long it has taken, what it is
/// worth.
class HudBar extends StatelessWidget {
  const HudBar({super.key, required this.engine, required this.onPause});

  final MinesweeperEngine engine;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final timed = engine.mode == GameMode.timed;
    final seconds = timed ? engine.secondsRemaining : engine.elapsedSeconds;
    final urgent = timed && engine.secondsRemaining <= 20;

    return Row(
      children: [
        _RoundButton(icon: Icons.pause_rounded, onTap: onPause),
        const SizedBox(width: 8),
        StatChip(
          icon: Icons.flag_rounded,
          value: '${engine.minesRemaining}',
          color: Palette.textPrimary,
        ),
        const SizedBox(width: 8),
        StatChip(
          icon: timed ? Icons.timer_rounded : Icons.schedule_rounded,
          value: formatClock(seconds),
          color: urgent ? Palette.danger : Palette.textPrimary,
          emphasis: urgent,
        ),
        // Only appears once a chain is actually running (level 1 is just an
        // ordinary batch) — grouped with mines/timer, not the score, so the
        // score chip on the far right never shifts as the chain grows.
        if (engine.chainLevel >= 2) ...[
          const SizedBox(width: 8),
          StatChip(
            icon: Icons.link_rounded,
            value: 'x${engine.chainLevel}',
            color: Palette.energy,
            emphasis: true,
          ),
        ],
        const Spacer(),
        StatChip(
          icon: Icons.auto_awesome_rounded,
          value: formatScore(engine.score),
          color: Palette.accent,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.surface.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Palette.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 34,
          child: Icon(icon, size: 18, color: Palette.textPrimary),
        ),
      ),
    );
  }
}

/// Shown when the generator could not prove a board needs no guessing. It is
/// rare, and saying so is better than letting a player lose to a coin flip
/// without warning.
class GuessWarning extends StatelessWidget {
  const GuessWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.energy.withValues(alpha: 0.6)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: Palette.energy),
          SizedBox(width: 6),
          Text(
            'this board may need a guess',
            style: TextStyle(color: Palette.energy, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
