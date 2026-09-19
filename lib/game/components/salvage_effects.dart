import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/palette.dart';

/// The payoff animation for a successful batch.
///
/// A beam links the cells in the order they were picked, each one pops a ring,
/// and motes of energy peel off towards the top of the screen where the meter
/// lives. It runs for well under a second and never blocks input — the player
/// can keep tapping straight through it.
class SalvageBeamComponent extends Component {
  SalvageBeamComponent({required this.points, required this.batchSize})
    : _motes = [
        for (var i = 0; i < points.length * 3; i++)
          _Mote(
            origin: points[i % points.length],
            drift: Vector2(
              (_random.nextDouble() - 0.5) * 60,
              -70 - _random.nextDouble() * 80,
            ),
            delay: _random.nextDouble() * 0.12,
          ),
      ];

  static const double duration = 0.75;
  static final math.Random _random = math.Random();

  final List<Vector2> points;
  final int batchSize;
  final List<_Mote> _motes;

  double _time = 0;

  final Paint _beam = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _mote = Paint()..isAntiAlias = true;

  @override
  void update(double dt) {
    _time += dt;
    if (_time >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_time / duration).clamp(0.0, 1.0);

    // The link: brightest right after the commit, then it burns out.
    if (points.length > 1) {
      final fade = (1 - t * 1.6).clamp(0.0, 1.0);
      _beam
        ..color = Palette.accent.withValues(alpha: 0.9 * fade)
        ..strokeWidth = 3 + 3 * fade;
      final path = Path()..moveTo(points.first.x, points.first.y);
      for (final point in points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(path, _beam);
    }

    // A ring per salvaged cell.
    final ringT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    _ring
      ..color = Palette.energy.withValues(alpha: (1 - ringT).clamp(0.0, 1.0))
      ..strokeWidth = 3 * (1 - ringT) + 1;
    for (final point in points) {
      canvas.drawCircle(Offset(point.x, point.y), 8 + 34 * ringT, _ring);
    }

    // Energy on its way to the meter.
    for (final mote in _motes) {
      final local = ((_time - mote.delay) / (duration - 0.12)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeInCubic.transform(local);
      final alpha = (1 - local).clamp(0.0, 1.0);
      _mote.color = Palette.energy.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(
          mote.origin.x + mote.drift.x * eased,
          mote.origin.y + mote.drift.y * eased,
        ),
        2.5 + 1.5 * (1 - local),
        _mote,
      );
    }
  }
}

class _Mote {
  _Mote({required this.origin, required this.drift, required this.delay});

  final Vector2 origin;
  final Vector2 drift;
  final double delay;
}

/// What a mistake looks like: a hard flash, an expanding shock ring and a
/// scatter of debris.
class ExplosionComponent extends Component {
  ExplosionComponent({required this.centre});

  static const double duration = 0.9;

  final Vector2 centre;
  double _time = 0;

  final Paint _shock = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _core = Paint()..isAntiAlias = true;

  @override
  void update(double dt) {
    _time += dt;
    if (_time >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_time / duration).clamp(0.0, 1.0);
    final offset = Offset(centre.x, centre.y);

    final coreFade = (1 - t * 3).clamp(0.0, 1.0);
    if (coreFade > 0) {
      _core.color = Palette.danger.withValues(alpha: coreFade);
      canvas.drawCircle(offset, 14 + 26 * (1 - coreFade), _core);
    }

    for (var ring = 0; ring < 3; ring++) {
      final local = (t - ring * 0.12).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      _shock
        ..color = Palette.danger.withValues(alpha: (1 - eased) * 0.8)
        ..strokeWidth = 4 * (1 - eased) + 1;
      canvas.drawCircle(offset, 10 + 90 * eased, _shock);
    }
  }
}

/// Marks the cells a wrong salvage guess was made on.
class BadSalvageComponent extends Component {
  BadSalvageComponent({required this.points});

  static const double duration = 0.8;

  final List<Vector2> points;
  double _time = 0;

  final Paint _cross = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void update(double dt) {
    _time += dt;
    if (_time >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_time / duration).clamp(0.0, 1.0);
    final flash = (math.sin(t * math.pi * 6) * 0.5 + 0.5) * (1 - t);
    _cross
      ..color = Palette.danger.withValues(alpha: 0.4 + 0.6 * flash)
      ..strokeWidth = 4;
    for (final point in points) {
      final r = 16.0;
      canvas.drawLine(
        Offset(point.x - r, point.y - r),
        Offset(point.x + r, point.y + r),
        _cross,
      );
      canvas.drawLine(
        Offset(point.x + r, point.y - r),
        Offset(point.x - r, point.y + r),
        _cross,
      );
    }
  }
}
