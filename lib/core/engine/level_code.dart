import 'game_rules.dart';

/// A short, shareable description of one exact run.
///
/// A code pins the rules version, the difficulty, the mode and the seed. The
/// seed fixes both the minefield and the start cell, so two players entering
/// the same code play the identical board and their scores are comparable.
class LevelCode {
  const LevelCode({
    required this.difficulty,
    required this.mode,
    required this.seed,
    this.rulesVersion = GameRules.rulesVersion,
  });

  final Difficulty difficulty;
  final GameMode mode;
  final int seed;
  final int rulesVersion;

  /// True when this code was made by the rules this build implements.
  bool get isCurrentRules => rulesVersion == GameRules.rulesVersion;

  // Crockford base32: no I, L, O or U, so codes survive being read aloud.
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Formatted as `XXXX-XXXX-XXX` for easier reading and typing.
  String encode() {
    final bytes = <int>[
      rulesVersion & 0xFF,
      ((difficulty.index & 0x0F) << 4) | (mode.index & 0x0F),
      (seed >> 24) & 0xFF,
      (seed >> 16) & 0xFF,
      (seed >> 8) & 0xFF,
      seed & 0xFF,
    ];
    bytes.add(_checksum(bytes));

    final buffer = StringBuffer();
    var acc = 0;
    var bits = 0;
    for (final byte in bytes) {
      acc = (acc << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(_alphabet[(acc >> bits) & 0x1F]);
      }
    }
    if (bits > 0) {
      buffer.write(_alphabet[(acc << (5 - bits)) & 0x1F]);
    }

    final raw = buffer.toString();
    final groups = <String>[];
    for (var i = 0; i < raw.length; i += 4) {
      groups.add(raw.substring(i, i + 4 > raw.length ? raw.length : i + 4));
    }
    return groups.join('-');
  }

  /// Returns null when the text is not a well-formed code. Typos are caught by
  /// the checksum rather than silently producing a different board.
  static LevelCode? tryDecode(String input) {
    final normalised = input
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll(' ', '')
        // Crockford's forgiving aliases.
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0')
        .replaceAll('U', 'V');
    if (normalised.length < 11) return null;

    var acc = 0;
    var bits = 0;
    final bytes = <int>[];
    for (final char in normalised.split('')) {
      final value = _alphabet.indexOf(char);
      if (value < 0) return null;
      acc = (acc << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((acc >> bits) & 0xFF);
      }
    }
    if (bytes.length < 7) return null;

    final payload = bytes.sublist(0, 6);
    if (_checksum(payload) != bytes[6]) return null;

    final difficultyIndex = (payload[1] >> 4) & 0x0F;
    final modeIndex = payload[1] & 0x0F;
    if (difficultyIndex >= Difficulty.values.length) return null;
    if (modeIndex >= GameMode.values.length) return null;

    final seed =
        (payload[2] << 24) | (payload[3] << 16) | (payload[4] << 8) | payload[5];

    return LevelCode(
      rulesVersion: payload[0],
      difficulty: Difficulty.values[difficultyIndex],
      mode: GameMode.values[modeIndex],
      seed: seed,
    );
  }

  static int _checksum(List<int> bytes) {
    // Fletcher-ish: cheap, and catches the transpositions people actually make.
    var a = 0;
    var b = 0;
    for (final byte in bytes) {
      a = (a + byte) & 0xFF;
      b = (b + a) & 0xFF;
    }
    return (a ^ b) & 0xFF;
  }

  @override
  String toString() => encode();
}
