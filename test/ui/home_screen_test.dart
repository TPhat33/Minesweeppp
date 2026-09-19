import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
import 'package:minesweeppp/ui/screens/home_screen.dart';
import 'package:minesweeppp/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PlayerStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PlayerStore.open();
}

Future<void> _pumpHome(WidgetTester tester, PlayerStore store) async {
  // A tall phone-shaped surface so the whole menu is laid out at once.
  tester.view.physicalSize = const Size(440, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.build(), home: HomeScreen(store: store)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every difficulty and both modes', (tester) async {
    await _pumpHome(tester, await _store());

    for (final difficulty in Difficulty.values) {
      expect(find.text(difficulty.label), findsOneWidget);
    }
    for (final mode in GameMode.values) {
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(find.text('START RUN'), findsOneWidget);
  });

  testWidgets('shows the mine count and density for each preset', (
    tester,
  ) async {
    await _pumpHome(tester, await _store());
    expect(find.textContaining('9x9 · 10 mines'), findsOneWidget);
    expect(find.textContaining('32x24 · 175 mines'), findsOneWidget);
  });

  testWidgets('offers the level code and records entry points', (tester) async {
    await _pumpHome(tester, await _store());
    expect(find.text('Level code'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
  });

  testWidgets('a difficulty can be selected', (tester) async {
    await _pumpHome(tester, await _store());
    await tester.tap(find.text(Difficulty.expert.label));
    await tester.pumpAndSettle();
    // Selection is visual only; the important part is that it does not throw
    // and the tile is still there to start a run from.
    expect(find.text(Difficulty.expert.label), findsOneWidget);
  });

  testWidgets('rejects an invalid level code', (tester) async {
    await _pumpHome(tester, await _store());
    await tester.tap(find.text('Level code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-code');
    await tester.tap(find.text('Play it'));
    await tester.pumpAndSettle();

    expect(find.text('That code is not valid.'), findsOneWidget);
  });

  testWidgets('no resume card without a saved run', (tester) async {
    await _pumpHome(tester, await _store());
    expect(find.text('Run in progress'), findsNothing);
  });
}
