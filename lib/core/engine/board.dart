import 'dart:typed_data';

/// An immutable minefield: where the mines are, how many sit next to each
/// cell, and which cell the run opens on.
///
/// The board knows nothing about flags, reveals or scoring — that lives in
/// [MinesweeperEngine]. Keeping it separate is what lets the solver replay a
/// board without touching game state.
class Board {
  Board._(this.width, this.height, this._mines, this._adjacent, this.startIndex)
    : mineCount = _mines.where((m) => m).length;

  factory Board.fromMines({
    required int width,
    required int height,
    required List<bool> mines,
    required int startIndex,
  }) {
    assert(mines.length == width * height, 'mine grid must match board size');
    final adjacent = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        if (mines[i]) continue;
        var count = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            if (mines[ny * width + nx]) count++;
          }
        }
        adjacent[i] = count;
      }
    }
    return Board._(width, height, List<bool>.unmodifiable(mines), adjacent, startIndex);
  }

  final int width;
  final int height;
  final int mineCount;

  /// The cell the run opens on. It is always mine-free and is baked into the
  /// level code so two players get the identical opening.
  final int startIndex;

  final List<bool> _mines;
  final Uint8List _adjacent;

  int get cellCount => width * height;
  int get safeCellCount => cellCount - mineCount;

  int xOf(int index) => index % width;
  int yOf(int index) => index ~/ width;
  int indexOf(int x, int y) => y * width + x;
  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  bool isMine(int index) => _mines[index];

  /// Number shown on a revealed cell. Salvaged mines keep counting here — that
  /// is the whole point of the salvage rule: the numbers never change.
  int adjacentMines(int index) => _adjacent[index];

  List<bool> get mines => _mines;

  /// Indices of the (up to eight) neighbours of [index].
  List<int> neighbours(int index) {
    final x = xOf(index);
    final y = yOf(index);
    final result = <int>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (contains(nx, ny)) result.add(ny * width + nx);
      }
    }
    return result;
  }
}
