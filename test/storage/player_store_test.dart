import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeppp/core/engine/game_rules.dart';
import 'package:minesweeppp/core/engine/level_code.dart';
import 'package:minesweeppp/core/models/board_record.dart';
import 'package:minesweeppp/core/storage/player_store.dart';
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

BoardRecord _record({
  required String code,
  int seed = 1,
  int bestScore = 5,
  bool pinned = false,
  int updatedAtMs = 0,
}) {
  return BoardRecord(
    code: code,
    difficulty: Difficulty.beginner,
    mode: GameMode.classic,
    seed: seed,
    bestScore: bestScore,
    bestChain: 0,
    cleared: false,
    playCount: 1,
    pinned: pinned,
    updatedAtMs: updatedAtMs,
  );
}

void main() {
  group('recordBoard', () {
    test('a lower score does not overwrite bestScore, but still counts the play', () async {
      final store = await _store();
      const seed = 42;

      // Same seed => same level code, regardless of what each engine's own
      // board looks like — a level code is derived from difficulty/mode/seed
      // alone, not from the field, so this is enough to make both runs land
      // on the same board record.
      final high = engineFrom(_field, startX: 0, startY: 0, seed: seed);
      high.toggleFlag(1);
      high.toggleSalvageSelection(1);
      high.commitSalvage();
      for (var i = 0; i < high.board.cellCount; i++) {
        if (!high.board.isMine(i)) high.reveal(i);
      }

      final low = engineFrom(_field, startX: 0, startY: 0, seed: seed);
      expect(high.score, greaterThan(low.score));

      await store.recordBoard(high);
      await store.recordBoard(low);

      final record = store.boardFor(high.levelCode);
      expect(record, isNotNull);
      expect(record!.bestScore, high.score);
      expect(record.playCount, 2);
    });

    test('rivalScore set before a run survives recordBoard afterwards', () async {
      final store = await _store();
      final engine = engineFrom(_field, startX: 0, startY: 0, seed: 7);

      await store.setRivalScore(engine.levelCode, 500);
      await store.recordBoard(engine);

      final record = store.boardFor(engine.levelCode);
      expect(record, isNotNull);
      expect(record!.rivalScore, 500);
    });
  });

  group('eviction', () {
    test('drops only the oldest unpinned records once past the cap', () async {
      final boards = <String, dynamic>{};
      for (var i = 0; i < 3; i++) {
        boards['PIN$i'] = _record(
          code: 'PIN$i',
          seed: i,
          pinned: true,
          updatedAtMs: i,
        ).toJson();
      }
      for (var i = 0; i < PlayerStore.maxBoardRecords; i++) {
        boards['REC$i'] = _record(
          code: 'REC$i',
          seed: 1000 + i,
          updatedAtMs: 100 + i,
        ).toJson();
      }
      expect(boards.length, PlayerStore.maxBoardRecords + 3);

      final store = await _store({'boards': jsonEncode(boards)});
      // Adding one more (real, freshly time-stamped) record pushes the log
      // 4 over the cap — enough to prove eviction removes more than one.
      final fresh = engineFrom(_field, startX: 0, startY: 0, seed: 99999);
      await store.recordBoard(fresh);

      final result = store.loadBoards();
      expect(result.length, PlayerStore.maxBoardRecords);

      // Every pinned record survives, whatever its age.
      for (var i = 0; i < 3; i++) {
        expect(result.containsKey('PIN$i'), isTrue);
      }
      // The oldest unpinned records (smallest updatedAtMs) are the ones
      // dropped — this depends on the eviction being over by exactly 4.
      for (var i = 0; i < 4; i++) {
        expect(result.containsKey('REC$i'), isFalse);
      }
      for (var i = 4; i < PlayerStore.maxBoardRecords; i++) {
        expect(result.containsKey('REC$i'), isTrue);
      }
      expect(result.containsKey(fresh.levelCode.encode()), isTrue);
    });
  });

  group('pinning', () {
    test('returns false and changes nothing once the pin cap is hit', () async {
      final boards = <String, dynamic>{};
      for (var i = 0; i < PlayerStore.maxPinnedBoards; i++) {
        boards['PIN$i'] = _record(
          code: 'PIN$i',
          seed: i,
          pinned: true,
          updatedAtMs: i,
        ).toJson();
      }

      final store = await _store({'boards': jsonEncode(boards)});
      final engine = engineFrom(_field, startX: 0, startY: 0, seed: 55555);
      await store.recordBoard(engine);

      final ok = await store.setPinned(engine.levelCode, true);
      expect(ok, isFalse);

      final record = store.boardFor(engine.levelCode);
      expect(record!.pinned, isFalse);
      final pinnedCount = store.loadBoards().values.where((b) => b.pinned).length;
      expect(pinnedCount, PlayerStore.maxPinnedBoards);
    });

    test('returns false when the board has no record yet', () async {
      final store = await _store();
      const code = LevelCode(
        difficulty: Difficulty.beginner,
        mode: GameMode.classic,
        seed: 1,
      );
      final ok = await store.setPinned(code, true);
      expect(ok, isFalse);
      expect(store.boardFor(code), isNull);
    });
  });

  group('BoardRecord.fromJson', () {
    test('parses a record missing rivalScore and pinned without throwing', () {
      final json = {
        'code': 'ABCD-EFGH-JKMN',
        'difficulty': Difficulty.beginner.name,
        'mode': GameMode.classic.name,
        'seed': 42,
        'bestScore': 100,
        'bestChain': 2,
        'cleared': true,
        'playCount': 3,
        'updatedAtMs': 1234,
        // rivalScore and pinned deliberately omitted.
      };

      final record = BoardRecord.fromJson(json);
      expect(record, isNotNull);
      expect(record!.rivalScore, isNull);
      expect(record.pinned, isFalse);
    });

    test('drops an unparseable record instead of throwing', () {
      expect(BoardRecord.fromJson({'difficulty': 'not-a-real-difficulty'}), isNull);
    });
  });
}
