import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The bottom controls: what a tap does, and the salvage batch.
///
/// The batch panel only appears once something is selected, so it never eats
/// board space during ordinary play.
class SalvageBar extends StatelessWidget {
  const SalvageBar({
    super.key,
    required this.inputMode,
    required this.onInputModeChanged,
    required this.selectionSize,
    required this.pendingScore,
    required this.pendingBonus,
    required this.flagCount,
    required this.onSalvage,
    required this.onClear,
    required this.onSelectAll,
  });

  final InputMode inputMode;
  final ValueChanged<InputMode> onInputModeChanged;
  final int selectionSize;
  final int pendingScore;
  final int pendingBonus;
  final int flagCount;
  final VoidCallback onSalvage;
  final VoidCallback onClear;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: selectionSize == 0
              ? const SizedBox(width: double.infinity)
              : _BatchPanel(
                  selectionSize: selectionSize,
                  pendingScore: pendingScore,
                  pendingBonus: pendingBonus,
                  onSalvage: onSalvage,
                  onClear: onClear,
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModeToggle(
                inputMode: inputMode,
                onChanged: onInputModeChanged,
              ),
            ),
            if (flagCount > 0 && selectionSize < flagCount) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all_rounded, size: 18),
                label: const Text('All flags'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BatchPanel extends StatelessWidget {
  const _BatchPanel({
    required this.selectionSize,
    required this.pendingScore,
    required this.pendingBonus,
    required this.onSalvage,
    required this.onClear,
  });

  final int selectionSize;
  final int pendingScore;
  final int pendingBonus;
  final VoidCallback onSalvage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final nextBonus =
        GameRules.batchBonus(selectionSize + 1) - pendingBonus;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Palette.accent.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$selectionSize marked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.readout.copyWith(
                          color: Palette.accent,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '+$pendingScore',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.readout.copyWith(
                          color: Palette.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // The nudge that makes waiting tempting.
                Text(
                  pendingBonus > 0
                      ? 'incl. +$pendingBonus batch · next +${GameRules.salvageBaseScore + nextBonus}'
                      : 'next one is worth +${GameRules.salvageBaseScore + nextBonus}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.energy,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            color: Palette.textSecondary,
            tooltip: 'Clear selection',
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onSalvage,
            style: FilledButton.styleFrom(
              backgroundColor: Palette.accent,
              foregroundColor: Palette.background,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: const Text('SALVAGE'),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.inputMode, required this.onChanged});

  final InputMode inputMode;
  final ValueChanged<InputMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outline),
      ),
      child: Row(
        children: [
          _ModeButton(
            icon: Icons.touch_app_rounded,
            label: 'Open',
            selected: inputMode == InputMode.reveal,
            onTap: () => onChanged(InputMode.reveal),
          ),
          _ModeButton(
            icon: Icons.flag_rounded,
            label: 'Flag',
            selected: inputMode == InputMode.flag,
            onTap: () => onChanged(InputMode.flag),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? Palette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Palette.background : Palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Palette.background : Palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
