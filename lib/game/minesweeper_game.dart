import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/engine/move_result.dart';
import '../ui/theme/palette.dart';
import 'components/board_component.dart';
import 'components/salvage_effects.dart';
import 'game_session.dart';

/// The Flame side of the app: it renders the board, owns the camera, and turns
/// engine results into effects.
///
/// Gestures are handled by Flutter above the game rather than by Flame, which
/// is what makes "drag to pan" and "tap to open" reliably distinguishable —
/// the single most important thing about playing Minesweeper on a phone.
class MinesweeperGame extends FlameGame {
  MinesweeperGame({required this.session});

  /// One board cell in world units. Screen size is this times the zoom.
  static const double cellSize = 34;

  /// Never let a cell get smaller than this on screen: numbers have to stay
  /// readable and targets have to stay tappable, even on Legendary.
  static const double minCellOnScreen = 19;
  static const double maxCellOnScreen = 78;

  /// What a comfortable cell looks like when a run starts.
  static const double preferredCellOnScreen = 38;

  final GameSession session;

  late final BoardComponent board;

  final Vector2 _focus = Vector2.zero();
  Vector2 _shake = Vector2.zero();
  double _shakeTime = 0;
  double _shakeStrength = 0;

  double _minZoom = 0.5;
  double _maxZoom = 2.5;

  double get zoom => camera.viewfinder.zoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  Vector2 get boardSize => Vector2(
    session.engine.board.width * cellSize,
    session.engine.board.height * cellSize,
  );

  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    board = BoardComponent(session: session, cellSize: cellSize);
    world.add(board);

    camera.viewfinder.anchor = Anchor.center;
    session.onMove = _playEffects;

    _updateZoomLimits();
    camera.viewfinder.zoom = _clampZoom(preferredCellOnScreen / cellSize);
    centreOnStart();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _updateZoomLimits();
      camera.viewfinder.zoom = _clampZoom(camera.viewfinder.zoom);
      _applyCamera();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    session.tick(dt);
    _updateShake(dt);
    _applyCamera();
  }

  @override
  void onRemove() {
    if (session.onMove == _playEffects) session.onMove = null;
    super.onRemove();
  }

  // ----------------------------------------------------------------- camera
  void centreOnStart() {
    final board = session.engine.board;
    _focus.setValues(
      (board.xOf(board.startIndex) + 0.5) * cellSize,
      (board.yOf(board.startIndex) + 0.5) * cellSize,
    );
    _applyCamera();
  }

  /// Screen-space drag, in logical pixels.
  void panBy(Offset delta) {
    _focus.x -= delta.dx / camera.viewfinder.zoom;
    _focus.y -= delta.dy / camera.viewfinder.zoom;
    _applyCamera();
  }

  /// Pinch zoom that keeps the point under the fingers where it is.
  void zoomAround(double factor, Offset focalPoint) {
    final target = _clampZoom(camera.viewfinder.zoom * factor);
    if (target == camera.viewfinder.zoom) return;

    final focal = Vector2(focalPoint.dx, focalPoint.dy);
    _applyCamera();
    final before = camera.globalToLocal(focal);
    camera.viewfinder.zoom = target;
    _applyCamera();
    final after = camera.globalToLocal(focal);
    _focus.add(before - after);
    _applyCamera();
  }

  void zoomBy(double factor) =>
      zoomAround(factor, Offset(size.x / 2, size.y / 2));

  /// Which cell is under a screen point, or null if the point is off-board.
  int? cellAtScreen(Offset point) {
    final world = camera.globalToLocal(Vector2(point.dx, point.dy));
    final board = session.engine.board;
    final x = (world.x / cellSize).floor();
    final y = (world.y / cellSize).floor();
    if (!board.contains(x, y)) return null;
    return board.indexOf(x, y);
  }

  void _updateZoomLimits() {
    if (size.x <= 0 || size.y <= 0) return;
    final fit = math.min(size.x / boardSize.x, size.y / boardSize.y);
    // Small boards should never zoom out past fitting on screen; big ones stop
    // when the cells get too small to read.
    _minZoom = math.max(fit, minCellOnScreen / cellSize);
    _maxZoom = math.max(_minZoom * 1.4, maxCellOnScreen / cellSize);
  }

  double _clampZoom(double value) => value.clamp(_minZoom, _maxZoom);

  /// Keeps the board on screen: centred when it fits, edge-locked when it does
  /// not, so the player can never lose the grid by flicking.
  void _applyCamera() {
    final zoom = camera.viewfinder.zoom;
    final halfWidth = size.x / (2 * zoom);
    final halfHeight = size.y / (2 * zoom);
    final board = boardSize;

    if (board.x <= halfWidth * 2) {
      _focus.x = board.x / 2;
    } else {
      _focus.x = _focus.x.clamp(halfWidth, board.x - halfWidth);
    }
    if (board.y <= halfHeight * 2) {
      _focus.y = board.y / 2;
    } else {
      _focus.y = _focus.y.clamp(halfHeight, board.y - halfHeight);
    }

    camera.viewfinder.position = _focus + _shake;
  }

  void _updateShake(double dt) {
    if (_shakeTime <= 0) {
      if (_shake.x != 0 || _shake.y != 0) _shake = Vector2.zero();
      return;
    }
    _shakeTime -= dt;
    final falloff = math.max(0.0, _shakeTime / 0.35);
    final amount = _shakeStrength * falloff;
    _shake = Vector2(
      (_rng.nextDouble() * 2 - 1) * amount,
      (_rng.nextDouble() * 2 - 1) * amount,
    );
  }

  void _shakeCamera(double strength) {
    if (!session.settings.animations) return;
    _shakeStrength = strength;
    _shakeTime = 0.35;
  }

  final math.Random _rng = math.Random();

  // ---------------------------------------------------------------- effects
  void _playEffects(MoveResult result) {
    board.noteMove(result);
    if (!session.settings.animations) return;

    switch (result.kind) {
      case MoveKind.salvage:
        if (result.failedSalvage.isNotEmpty) {
          world.add(
            BadSalvageComponent(
              points: [
                for (final index in result.failedSalvage) board.centreOf(index),
              ],
            ),
          );
          _shakeCamera(9);
        } else if (result.salvaged.isNotEmpty) {
          world.add(
            SalvageBeamComponent(
              points: [for (final index in result.salvaged) board.centreOf(index)],
              batchSize: result.batchSize,
            ),
          );
          if (result.batchSize >= 3) _shakeCamera(3.0);
        }
      case MoveKind.explode:
        final index = result.explodedIndex;
        if (index != null) {
          world.add(ExplosionComponent(centre: board.centreOf(index)));
        }
        _shakeCamera(11);
      default:
        break;
    }
  }
}
