import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/game_session.dart';
import '../../game/minesweeper_game.dart';

/// Raw pointer handling for the board.
///
/// Flutter's gesture recognisers would work, but a board game needs the tap
/// and drag rules spelled out: a tap only counts if the finger barely moved,
/// panning only starts once it clearly has, and a second finger switches to
/// pinch without ever opening a cell. Getting this wrong means opening a mine
/// while scrolling, which is the worst bug this game could have.
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.game, required this.session});

  final MinesweeperGame game;
  final GameSession session;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  /// How far a finger may travel and still count as a tap, in logical pixels.
  static const double _tapSlop = 14;

  static const Duration _longPressDelay = Duration(milliseconds: 420);

  final Map<int, Offset> _pointers = {};

  double _travel = 0;
  bool _longPressFired = false;
  bool _panning = false;
  Timer? _longPressTimer;
  int? _pressedCell;

  double? _pinchDistance;
  Offset? _pinchFocal;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _clearPreview() {
    widget.session.previewChord(null);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length == 1) {
      _travel = 0;
      _panning = false;
      _longPressFired = false;
      _pressedCell = widget.game.cellAtScreen(event.localPosition);
      // Pressing a satisfied number shows exactly what is about to open.
      if (_pressedCell != null) widget.session.previewChord(_pressedCell);
      _longPressTimer = Timer(_longPressDelay, () {
        final cell = _pressedCell;
        if (cell == null || _panning) return;
        _longPressFired = true;
        _clearPreview();
        widget.session.longPressCell(cell);
      });
      return;
    }

    // A second finger means the player wants to move the board, never to play
    // a move.
    _cancelLongPress();
    _clearPreview();
    _pressedCell = null;
    _updatePinchReference();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    if (previous == null) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length == 1) {
      final delta = event.localPosition - previous;
      _travel += delta.distance;
      if (_travel > _tapSlop) {
        if (!_panning) {
          _panning = true;
          _cancelLongPress();
          _clearPreview();
        }
        widget.game.panBy(delta);
      }
      return;
    }

    if (_pointers.length >= 2) {
      final distance = _pinchDistance;
      final focal = _pinchFocal;
      _updatePinchReference();
      if (distance == null || focal == null || distance <= 0) return;
      final newDistance = _pinchDistance!;
      final newFocal = _pinchFocal!;
      widget.game.zoomAround(newDistance / distance, newFocal);
      widget.game.panBy(newFocal - focal);
    }
  }

  void _onPointerUp(PointerEvent event) {
    final wasSinglePointer = _pointers.length == 1;
    _pointers.remove(event.pointer);

    if (wasSinglePointer) {
      _cancelLongPress();
      final cell = _pressedCell;
      final isTap = !_longPressFired &&
          !_panning &&
          _travel <= _tapSlop &&
          cell != null &&
          event is! PointerCancelEvent;
      _clearPreview();
      if (isTap) widget.session.tapCell(cell);
      _pressedCell = null;
    }

    if (_pointers.length < 2) {
      _pinchDistance = null;
      _pinchFocal = null;
    } else {
      _updatePinchReference();
    }
  }

  void _updatePinchReference() {
    if (_pointers.length < 2) return;
    final points = _pointers.values.toList();
    final a = points[0];
    final b = points[1];
    _pinchDistance = math.max(1, (a - b).distance);
    _pinchFocal = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: GameWidget(game: widget.game),
    );
  }
}
