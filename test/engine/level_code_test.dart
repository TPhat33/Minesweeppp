import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/level_code.dart';

void main() {
  test('a code round-trips through encode and decode', () {
    for (final difficulty in Difficulty.values) {
      for (final mode in GameMode.values) {
        final code = LevelCode(
          difficulty: difficulty,
          mode: mode,
          seed: 0xDEADBEEF,
        );
        final decoded = LevelCode.tryDecode(code.encode())!;
        expect(decoded.difficulty, difficulty);
        expect(decoded.mode, mode);
        expect(decoded.seed, 0xDEADBEEF);
        expect(decoded.rulesVersion, GameRules.rulesVersion);
        expect(decoded.isCurrentRules, isTrue);
      }
    }
  });

  test('codes are grouped for reading aloud', () {
    final code = const LevelCode(
      difficulty: Difficulty.expert,
      mode: GameMode.timed,
      seed: 1,
    ).encode();
    expect(code, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{1,4})+$')));
  });

  test('lower case, spaces and Crockford aliases are accepted', () {
    final original = const LevelCode(
      difficulty: Difficulty.master,
      mode: GameMode.classic,
      seed: 987654,
    );
    final messy = original.encode().toLowerCase().replaceAll('-', ' ');
    final decoded = LevelCode.tryDecode(messy)!;
    expect(decoded.seed, original.seed);
    expect(decoded.difficulty, original.difficulty);
  });

  test('a typo is rejected rather than silently changing the board', () {
    final code = const LevelCode(
      difficulty: Difficulty.beginner,
      mode: GameMode.classic,
      seed: 555,
    ).encode();
    final chars = code.replaceAll('-', '').split('');
    var rejected = 0;
    for (var i = 0; i < chars.length; i++) {
      final mutated = [...chars];
      mutated[i] = mutated[i] == 'Z' ? 'Y' : 'Z';
      if (LevelCode.tryDecode(mutated.join()) == null) rejected++;
    }
    expect(rejected, greaterThan(chars.length ~/ 2));
  });

  test('garbage input returns null instead of throwing', () {
    expect(LevelCode.tryDecode(''), isNull);
    expect(LevelCode.tryDecode('hello'), isNull);
    expect(LevelCode.tryDecode('!!!!-!!!!-!!!'), isNull);
  });

  test('a code from a future rules version decodes but is flagged', () {
    final future = const LevelCode(
      difficulty: Difficulty.legendary,
      mode: GameMode.timed,
      seed: 12,
      rulesVersion: 99,
    ).encode();
    final decoded = LevelCode.tryDecode(future)!;
    expect(decoded.rulesVersion, 99);
    expect(decoded.isCurrentRules, isFalse);
  });
}
