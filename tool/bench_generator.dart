// ignore_for_file: avoid_print
//
// Development helper: how hard is it to find a guess-free board at each
// difficulty? Run with `dart run tool/bench_generator.dart`.
import 'package:minesweeppp/core/engine/board_generator.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';

void main(List<String> args) {
  final samples = args.isEmpty ? 5 : int.parse(args.first);
  const generator = BoardGenerator(budget: Duration(seconds: 30));

  for (final difficulty in Difficulty.values) {
    var totalMs = 0;
    var attempts = 0;
    var failures = 0;
    var worstMs = 0;
    for (var i = 1; i <= samples; i++) {
      final generated = generator.generate(
        difficulty: difficulty,
        seed: i * 9173,
      );
      totalMs += generated.elapsed.inMilliseconds;
      worstMs = generated.elapsed.inMilliseconds > worstMs
          ? generated.elapsed.inMilliseconds
          : worstMs;
      attempts += generated.attempts;
      if (!generated.noGuess) failures++;
    }
    final density = (difficulty.mineDensity * 100).toStringAsFixed(1);
    print(
      '${difficulty.label.padRight(13)} density=$density%  '
      'avgAttempts=${(attempts / samples).toStringAsFixed(1)}  '
      'avgTime=${(totalMs / samples).toStringAsFixed(0)}ms  '
      'worst=${worstMs}ms  fallbacks=$failures/$samples',
    );
  }
}
