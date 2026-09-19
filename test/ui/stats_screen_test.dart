import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/level_code.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/ui/screens/stats_screen.dart';
import 'package:minesweeppp/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/test_boards.dart';

const _field = <String>[
  '.*.......',
  '..*......',
  '.*.......',
  '.........',
  '.........',
  '....*....',
  '.........',
  '.........',
  '.........',
];

Future<PlayerStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PlayerStore.open();
}

/// Every test pumps a tall surface: the Boards section sits below four
/// difficulty cards in a plain (non-builder) ListView, and a short default
/// test viewport mounts only what fits its cache extent — leaving anything
/// further down simply absent from the tree, not just scrolled off.
void _sizeForFullList(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('an empty board log shows no Boards section', (tester) async {
    _sizeForFullList(tester);
    final store = await _store();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: StatsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Boards'), findsNothing);
  });

  testWidgets('lists a played board and pins sort first', (tester) async {
    _sizeForFullList(tester);
    final store = await _store();
    final pinned = engineFrom(_field, startX: 0, startY: 0, seed: 1);
    final recent = engineFrom(_field, startX: 0, startY: 0, seed: 2);
    await store.recordBoard(pinned);
    await store.recordBoard(recent);
    await store.setPinned(pinned.levelCode, true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: StatsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BOARDS'), findsOneWidget);
    expect(find.text(pinned.levelCode.encode()), findsOneWidget);
    expect(find.text(recent.levelCode.encode()), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

    final codes = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .whereType<String>()
        .where((t) => t.contains('-'))
        .toList();
    // The pinned board's code must appear before the unpinned one's.
    expect(
      codes.indexOf(pinned.levelCode.encode()) <
          codes.indexOf(recent.levelCode.encode()),
      isTrue,
    );
  });

  testWidgets('tapping Play it pops the level code for the caller to run', (
    tester,
  ) async {
    _sizeForFullList(tester);
    final store = await _store();
    final engine = engineFrom(_field, startX: 0, startY: 0, seed: 3);
    await store.recordBoard(engine);

    LevelCode? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<LevelCode>(
                    MaterialPageRoute<LevelCode>(
                      builder: (context) => StatsScreen(store: store),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play it'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.encode(), engine.levelCode.encode());
  });
}
