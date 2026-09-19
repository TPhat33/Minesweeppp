import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Timed mode only: salvaged mines charge this, and the player decides whether
/// to burn it for clock or bank it for points.
class EnergyMeter extends StatelessWidget {
  const EnergyMeter({
    super.key,
    required this.energy,
    required this.boostsLeft,
    required this.canBoost,
    required this.onBoost,
  });

  final int energy;
  final int boostsLeft;
  final bool canBoost;
  final VoidCallback onBoost;

  @override
  Widget build(BuildContext context) {
    final progress =
        (energy % GameRules.timeBoostCost) / GameRules.timeBoostCost;
    final charges = energy ~/ GameRules.timeBoostCost;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 18, color: Palette.energy),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '$energy',
                      style: AppTheme.readout.copyWith(
                        color: Palette.energy,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      charges > 0
                          ? '$charges charge${charges == 1 ? '' : 's'} ready'
                          : 'charging',
                      style: const TextStyle(
                        color: Palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: charges > 0 ? 1 : progress,
                    minHeight: 5,
                    backgroundColor: Palette.cellHidden,
                    valueColor: const AlwaysStoppedAnimation(Palette.energy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Spend it, or keep it: banked energy pays out at the end of a win.
          FilledButton.tonal(
            onPressed: canBoost ? onBoost : null,
            style: FilledButton.styleFrom(
              backgroundColor: canBoost
                  ? Palette.energy.withValues(alpha: 0.18)
                  : Palette.surfaceHigh,
              foregroundColor: canBoost ? Palette.energy : Palette.textSecondary,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${GameRules.timeBoostSeconds}s',
                  style: AppTheme.readout.copyWith(fontSize: 14),
                ),
                Text(
                  '$boostsLeft left',
                  style: const TextStyle(fontSize: 9, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
