import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../ui/theme/palette.dart';

/// Draws one board cell.
///
/// Everything is vector: no image assets to ship, and the numbers stay sharp
/// at any zoom, which matters most on Expert and Legendary boards.
class CellPainter {
  CellPainter({required this.cellSize}) {
    _buildNumberPainters();
  }

  final double cellSize;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _glow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  late final List<TextPainter> _numbers;

  void _buildNumberPainters() {
    _numbers = [
      for (var n = 0; n <= 8; n++)
        TextPainter(
          text: TextSpan(
            text: '$n',
            style: TextStyle(
              color: Palette.number(n),
              fontSize: cellSize * 0.56,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
  }

  double get _radius => cellSize * 0.16;

  RRect _body(Rect cell, {double inset = 1}) => RRect.fromRectAndRadius(
    cell.deflate(inset),
    Radius.circular(_radius),
  );

  /// A cell nobody has touched yet.
  void drawHidden(Canvas canvas, Rect cell, {double scale = 1}) {
    final rect = _scaled(cell, scale);
    final body = _body(rect);
    _fill
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [Palette.cellHiddenHigh, Palette.cellHidden],
      )
      ..color = Palette.cellHidden;
    canvas.drawRRect(body, _fill);
    _fill.shader = null;

    // A thin lit edge along the top so the grid reads as raised panels.
    _stroke
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = cellSize * 0.04;
    canvas.drawLine(
      Offset(rect.left + _radius, rect.top + cellSize * 0.06),
      Offset(rect.right - _radius, rect.top + cellSize * 0.06),
      _stroke,
    );
  }

  /// An opened cell, with its number if it has one.
  void drawRevealed(
    Canvas canvas,
    Rect cell,
    int number, {
    double progress = 1,
  }) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final rect = _scaled(cell, 0.82 + 0.18 * eased);
    _fill.color = Color.lerp(Palette.cellHidden, Palette.cellOpen, eased)!;
    canvas.drawRRect(_body(rect), _fill);

    _stroke
      ..color = Palette.cellOpenEdge
      ..strokeWidth = cellSize * 0.03;
    canvas.drawRRect(_body(rect, inset: 1.5), _stroke);

    if (number == 0 || eased < 0.35) return;
    final painter = _numbers[number];
    final alpha = ((eased - 0.35) / 0.65).clamp(0.0, 1.0);
    canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    painter.paint(
      canvas,
      Offset(
        cell.center.dx - painter.width / 2,
        cell.center.dy - painter.height / 2,
      ),
    );
    canvas.restore();
  }

  /// The player's own marker. [selected] means it is queued in the current
  /// salvage batch.
  void drawFlag(
    Canvas canvas,
    Rect cell, {
    required bool selected,
    required double pulse,
  }) {
    drawHidden(canvas, cell);

    if (selected) {
      _glow.color = Palette.accent.withValues(alpha: 0.25 + 0.2 * pulse);
      canvas.drawRRect(_body(cell), _glow);
      _fill
        ..shader = null
        ..color = Palette.accentDim.withValues(alpha: 0.45);
      canvas.drawRRect(_body(cell), _fill);
      _stroke
        ..color = Palette.accent
        ..strokeWidth = cellSize * 0.07;
      canvas.drawRRect(_body(cell, inset: 2.5), _stroke);
    }

    final c = cell.center;
    final poleX = c.dx - cellSize * 0.06;
    _stroke
      ..color = selected ? Palette.accent : Palette.textSecondary
      ..strokeWidth = cellSize * 0.07;
    canvas.drawLine(
      Offset(poleX, c.dy - cellSize * 0.24),
      Offset(poleX, c.dy + cellSize * 0.26),
      _stroke,
    );

    final pennant = Path()
      ..moveTo(poleX, c.dy - cellSize * 0.26)
      ..lineTo(poleX + cellSize * 0.26, c.dy - cellSize * 0.12)
      ..lineTo(poleX, c.dy + cellSize * 0.02)
      ..close();
    _fill
      ..shader = null
      ..color = selected ? Palette.accent : Palette.danger;
    canvas.drawPath(pennant, _fill);
  }

  /// A mine the player cashed in. It still counts towards every neighbouring
  /// number, so it stays visible as a filled cell rather than an empty one.
  void drawSalvaged(Canvas canvas, Rect cell, {double flash = 0}) {
    final body = _body(cell);
    _fill
      ..shader = null
      ..color = Color.lerp(
        Palette.cellHidden,
        Palette.energy.withValues(alpha: 0.35),
        0.35 + 0.65 * flash,
      )!;
    canvas.drawRRect(body, _fill);

    if (flash > 0) {
      _glow.color = Palette.energy.withValues(alpha: 0.5 * flash);
      canvas.drawRRect(body, _glow);
    }

    _stroke
      ..color = Palette.energy.withValues(alpha: 0.85)
      ..strokeWidth = cellSize * 0.06;
    canvas.drawRRect(_body(cell, inset: 2.5), _stroke);

    // A recovered canister: capsule plus a charge bar.
    final c = cell.center;
    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c,
        width: cellSize * 0.30,
        height: cellSize * 0.44,
      ),
      Radius.circular(cellSize * 0.15),
    );
    _fill.color = Palette.energy;
    canvas.drawRRect(capsule, _fill);
    _fill.color = Palette.background;
    canvas.drawRect(
      Rect.fromCenter(
        center: c,
        width: cellSize * 0.16,
        height: cellSize * 0.06,
      ),
      _fill,
    );
  }

  /// Shown only once the run is over.
  void drawMine(Canvas canvas, Rect cell, {bool detonated = false}) {
    _fill
      ..shader = null
      ..color = detonated ? Palette.danger : Palette.surfaceHigh;
    canvas.drawRRect(_body(cell), _fill);

    final c = cell.center;
    final r = cellSize * 0.20;
    _fill.color = detonated ? Palette.background : Palette.danger;
    canvas.drawCircle(c, r, _fill);

    _stroke
      ..color = _fill.color
      ..strokeWidth = cellSize * 0.07;
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 * i;
      final dx = math.cos(angle) * r * 1.7;
      final dy = math.sin(angle) * r * 1.7;
      canvas.drawLine(
        Offset(c.dx - dx, c.dy - dy),
        Offset(c.dx + dx, c.dy + dy),
        _stroke,
      );
    }
  }

  /// A flag that turned out to be wrong, shown when the run ends.
  void drawWrongFlag(Canvas canvas, Rect cell) {
    drawFlag(canvas, cell, selected: false, pulse: 0);
    _stroke
      ..color = Palette.danger
      ..strokeWidth = cellSize * 0.09;
    final r = cell.deflate(cellSize * 0.22);
    canvas.drawLine(r.topLeft, r.bottomRight, _stroke);
    canvas.drawLine(r.topRight, r.bottomLeft, _stroke);
  }

  /// Highlight for the cells a chord is about to open.
  void drawChordPreview(Canvas canvas, Rect cell) {
    _fill
      ..shader = null
      ..color = Palette.cellPreview.withValues(alpha: 0.75);
    canvas.drawRRect(_body(cell), _fill);
    _stroke
      ..color = Palette.accent.withValues(alpha: 0.9)
      ..strokeWidth = cellSize * 0.06;
    canvas.drawRRect(_body(cell, inset: 2), _stroke);
  }

  Rect _scaled(Rect cell, double scale) {
    if (scale >= 1) return cell;
    return Rect.fromCenter(
      center: cell.center,
      width: cell.width * scale,
      height: cell.height * scale,
    );
  }
}
