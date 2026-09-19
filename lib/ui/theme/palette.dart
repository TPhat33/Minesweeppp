import 'package:flutter/material.dart';

/// The look: a salvage rig at night. Dark steel, cyan instrumentation, amber
/// for the things that pay you, red only for the things that kill you.
///
/// Numbers are the most-read thing on screen, so their colours are picked for
/// contrast against the opened-cell fill rather than for decoration.
abstract final class Palette {
  static const Color background = Color(0xFF0B1016);
  static const Color surface = Color(0xFF141C25);
  static const Color surfaceHigh = Color(0xFF1D2836);
  static const Color outline = Color(0xFF2C3B4D);

  static const Color accent = Color(0xFF3BE0D0);
  static const Color accentDim = Color(0xFF1E7C74);
  static const Color energy = Color(0xFFFFC24B);
  static const Color danger = Color(0xFFFF5C5C);
  static const Color success = Color(0xFF6BE675);

  static const Color textPrimary = Color(0xFFE8F1F8);
  static const Color textSecondary = Color(0xFF8FA3B6);

  // Board
  static const Color cellHidden = Color(0xFF223040);
  static const Color cellHiddenHigh = Color(0xFF2B3D51);
  static const Color cellOpen = Color(0xFF101922);
  static const Color cellOpenEdge = Color(0xFF1A2836);
  static const Color cellPreview = Color(0xFF2F4F63);
  static const Color gridLine = Color(0xFF0A1219);

  /// One colour per adjacency count, 1 through 8.
  static const List<Color> numbers = [
    Color(0x00000000), // unused: zero cells show nothing
    Color(0xFF6FC7FF),
    Color(0xFF7BE58C),
    Color(0xFFFF8E8E),
    Color(0xFFB79BFF),
    Color(0xFFFFC24B),
    Color(0xFF52DDD0),
    Color(0xFFFF9CE5),
    Color(0xFFC3D3E3),
  ];

  static Color number(int count) =>
      numbers[count.clamp(0, numbers.length - 1)];
}
