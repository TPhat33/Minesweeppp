import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

String formatClock(num seconds) {
  final total = seconds.round().clamp(0, 99 * 60 + 59);
  final minutes = total ~/ 60;
  final rest = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String formatScore(int score) {
  final digits = score.abs().toString();
  final buffer = StringBuffer(score < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// A small labelled readout used across the HUD and the results sheet.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
    this.emphasis = false,
  });

  final IconData icon;
  final String value;
  final String? label;
  final Color? color;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Palette.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasis ? tint.withValues(alpha: 0.7) : Palette.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTheme.readout.copyWith(color: tint, fontSize: 15),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section heading used on the menu screens.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Palette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
