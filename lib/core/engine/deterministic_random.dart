/// A tiny xorshift32 generator.
///
/// `dart:math`'s `Random` makes no promise about producing the same sequence
/// on every platform or SDK version, and a shared level code is worthless if
/// two phones build different boards from it. This one is fixed forever.
class DeterministicRandom {
  DeterministicRandom(int seed)
    : _state = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int _state;

  int get state => _state;

  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  /// Uniform in `[0, max)`, rejection-sampled so no value is favoured.
  int nextInt(int max) {
    assert(max > 0, 'max must be positive');
    if (max == 1) return 0;
    final limit = 0x100000000 - (0x100000000 % max);
    while (true) {
      final value = nextUint32();
      if (value < limit) return value % max;
    }
  }

  double nextDouble() => nextUint32() / 0x100000000;

  /// In-place Fisher-Yates.
  void shuffle(List<int> values) {
    for (var i = values.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = values[i];
      values[i] = values[j];
      values[j] = tmp;
    }
  }
}
