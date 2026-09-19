import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../../core/engine/minesweeper_engine.dart';
import '../../core/engine/move_result.dart';
import '../../ui/theme/palette.dart';
import '../game_session.dart';
import '../minesweeper_game.dart';
import 'cell_painter.dart';

/// Draws the whole board in one component.
///
/// One component per cell would mean ~800 components on a Legendary board for
/// no benefit: the grid is a single draw pass over the cells the camera can
/// actually see, and per-cell animation is just a timestamp per index.
class BoardComponent extends PositionComponent
    with HasGameReference<MinesweeperGame> {
  BoardComponent({required this.session, required this.cellSize})
    : _painter = CellPainter(cellSize: cellSize),
      _revealAt = Float64List(session.engine.board.cellCount),
      _salvageAt = Float64List(session.engine.board.cellCount),
      super(
        size: Vector2(
          session.engine.board.width * cellSize,
          session.engine.board.height * cellSize,
        ),
      ) {
    _revealAt.fillRange(0, _revealAt.length, _never);
    _salvageAt.fillRange(0, _salvageAt.length, _never);
  }

  static const double _revealDuration = 0.20;
  static const double _wavePerStep = 0.026;
  static const double _salvageFlashDuration = 0.55;
  static const double _never = -1000;

  final GameSession session;
  final double cellSize;
  final CellPainter _painter;

  /// When each cell started its open animation, in component time.
  final Float64List _revealAt;
  final Float64List _salvageAt;

  double _time = 0;

  MinesweeperEngine get engine => session.engine;

  @override
  void update(double dt) {
    _time += dt;
  }

  /// Schedules the animations for one move. The ripple is driven by the wave
  /// number the engine reports, so a big flood opens outwards from the tap.
  void noteMove(MoveResult result) {
    if (!session.settings.animations) return;
    for (final cell in result.revealed) {
      _revealAt[cell.index] = _time + cell.wave * _wavePerStep;
    }
    for (final index in result.salvaged) {
      _salvageAt[index] = _time;
    }
  }

  @override
  void render(Canvas canvas) {
    final visible = game.camera.visibleWorldRect;
    final board = engine.board;

    final minX = ((visible.left - position.x) / cellSize).floor().clamp(0, board.width - 1);
    final maxX = ((visible.right - position.x) / cellSize).ceil().clamp(0, board.width - 1);
    final minY = ((visible.top - position.y) / cellSize).floor().clamp(0, board.height - 1);
    final maxY = ((visible.bottom - position.y) / cellSize).ceil().clamp(0, board.height - 1);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Palette.gridLine,
    );

    final preview = session.chordPreview;
    final lost = engine.status == GameStatus.lost;
    final pulse = _triangleWave(_time * 0.9);

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final index = y * board.width + x;
        final cell = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );
        _drawCell(canvas, cell, index, preview, lost, pulse);
      }
    }
  }

  void _drawCell(
    Canvas canvas,
    Rect cell,
    int index,
    List<int> preview,
    bool lost,
    double pulse,
  ) {
    final state = engine.stateOf(index);
    final isMine = engine.board.isMine(index);

    if (lost) {
      // After a loss the board tells the whole story: where the mines were,
      // and which marks were wrong.
      if (state == CellState.flagged && !isMine) {
        _painter.drawWrongFlag(canvas, cell);
        return;
      }
      if (isMine && state != CellState.salvaged) {
        _painter.drawMine(
          canvas,
          cell,
          detonated: state == CellState.revealed,
        );
        return;
      }
    }

    switch (state) {
      case CellState.revealed:
        final startedAt = _revealAt[index];
        final progress = startedAt <= _never
            ? 1.0
            : ((_time - startedAt) / _revealDuration).clamp(0.0, 1.0);
        if (progress <= 0) {
          _painter.drawHidden(canvas, cell);
        } else {
          _painter.drawRevealed(
            canvas,
            cell,
            engine.board.adjacentMines(index),
            progress: progress,
          );
        }
      case CellState.flagged:
        _painter.drawFlag(
          canvas,
          cell,
          selected: engine.isSelected(index),
          pulse: pulse,
        );
      case CellState.salvaged:
        final startedAt = _salvageAt[index];
        final flash = startedAt <= _never
            ? 0.0
            : (1 - (_time - startedAt) / _salvageFlashDuration).clamp(0.0, 1.0);
        _painter.drawSalvaged(canvas, cell, flash: flash);
      default:
        if (preview.contains(index)) {
          _painter.drawChordPreview(canvas, cell);
        } else {
          _painter.drawHidden(canvas, cell);
        }
    }
  }

  /// Centre of a cell in world coordinates, for anchoring effects.
  Vector2 centreOf(int index) {
    final board = engine.board;
    return Vector2(
      position.x + (board.xOf(index) + 0.5) * cellSize,
      position.y + (board.yOf(index) + 0.5) * cellSize,
    );
  }

  /// 0 -> 1 -> 0, used for the slow breathing glow on selected flags.
  double _triangleWave(double t) {
    final phase = t % 1.0;
    return phase < 0.5 ? phase * 2 : 2 - phase * 2;
  }
}
