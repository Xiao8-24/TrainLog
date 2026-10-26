import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/model.dart';
import 'package:trainlog/store.dart';

void main() {
  late Directory dir;
  late TrainingStore store;
  late DateTime now;
  late List<Json> catalog;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('trainlog-test-');
    now = DateTime.utc(2026, 10, 20, 9);
    catalog = objects((jsonDecode(await File('assets/catalog.json').readAsString()) as Json)['exercises']);
    store = await TrainingStore.open('${dir.path}/training.db', catalog, clock: () => now);
  });
  tearDown(() async { if (!store.closed) { await store.close(); } await dir.delete(recursive: true); });
  Future<void> reopen() async { await store.close(); store = await TrainingStore.open('${dir.path}/training.db', catalog, clock: () => now); }
  Future<(String, String)> prepare({Json? exercise}) async {
    expect(await store.start(), isTrue);
    expect(await store.addExercise(exercise ?? catalog.first), isTrue);
    final e = (store.draft!['exercises'] as List).first as Json;
    final s = (e['sets'] as List).first as Json;
    expect(await store.editSet(e['id'] as String, s['id'] as String, {...s, 'weightKg': 40.0, 'reps': 8}), isTrue);
    return (e['id'] as String, s['id'] as String);
  }
  test('new installation has full stable catalog and no sample workouts', () {
    expect(store.catalog.length, 128); expect(store.sessions, isEmpty);
    expect(store.catalog.first['id'], '544c0100-0000-0000-0000-000000000001');
  });
  test('workout and set timers recover after pause, background and restart', () async {
    final ids = await prepare(); await store.beginSet(ids.$2);
    now = now.add(const Duration(seconds: 20)); await store.togglePause();
    now = now.add(const Duration(minutes: 5)); await reopen();
    expect(elapsed(store.draft!, now), 20); expect(elapsed(activeSet(store.draft!)!['timing'] as Json, now), 20);
    await store.togglePause(); now = now.add(const Duration(seconds: 10)); await reopen();
    expect(elapsed(store.draft!, now), 30);
    await store.completeSet(ids.$1, ids.$2); expect(store.restRemaining, 90);
    now = now.add(const Duration(seconds: 25)); await reopen(); expect(store.restRemaining, 65);
    await store.finish(); expect(store.history.length, 1); expect(store.restRemaining, 0);
    now = now.add(const Duration(hours: 2)); await reopen(); expect(elapsed(store.history.single, now), 55);
  });
  test('invalid completion rolls back without ending active timing or losing values', () async {
    await store.start(); await store.addExercise(catalog.first);
    final e = (store.draft!['exercises'] as List).first as Json;
    final id = e['sets'][0]['id'] as String;
    await store.beginSet(id); now = now.add(const Duration(seconds: 15));
    expect(await store.completeSet(e['id'] as String, id), isFalse);
    expect(activeSet(store.draft!)!['timing']['endedAt'], isNull);
    await reopen(); expect(elapsed(activeSet(store.draft!)!['timing'] as Json, now), 15);
    expect(await store.finish(), isFalse); expect(store.history, isEmpty);
  });
  test('only one active set and one active session', () async {
    final ids = await prepare(); await store.addSet(ids.$1);
    final second = (store.draft!['exercises'] as List).first['sets'][1]['id'] as String;
    await store.beginSet(ids.$2);
    expect(await store.beginSet(second), isFalse); expect(await store.start(), isFalse);
    expect(activeSet(store.draft!)!['id'], ids.$2);
  });
  test('copying a set removes previous effort and timing', () async {
    final ids = await prepare();
    final first = sets(store.draft!).first;
    await store.editSet(ids.$1, ids.$2, {...first, 'rpe': 8.0, 'rir': 2.0});
    await store.beginSet(ids.$2); now = now.add(const Duration(seconds: 10)); await store.completeSet(ids.$1, ids.$2);
    await store.addSet(ids.$1);
    final second = sets(store.draft!).last;
    expect(second['reps'], 8); expect(second['weightKg'], 40); expect(second['isCompleted'], false);
    expect(second['rpe'], isNull); expect(second['rir'], isNull); expect(second['timing'], isNull);
  });
  test('duration exercise can use measured time on completion', () async {
    final e = catalog.firstWhere((e) => e['tracking'] == 'duration');
    await store.start(); await store.addExercise(e);
    final entry = (store.draft!['exercises'] as List).first as Json; final id = entry['sets'][0]['id'] as String;
    await store.beginSet(id); now = now.add(const Duration(seconds: 31));
    expect(await store.completeSet(entry['id'] as String, id), isTrue); expect(sets(store.draft!).first['durationSeconds'], 31);
  });
  test('plan targets freeze at start and survive later plan edits and backup', () async {
    final plan = <String, dynamic>{'id': newID(), 'name': '周一力量', 'scheduledAt': stamp(now.add(const Duration(days: 3))), 'items': [{'id': newID(), 'exerciseID': catalog.first['id'], 'setCount': 3, 'weightKg': 40.0, 'reps': 8, 'restSeconds': 60}], 'notes': '', 'isSkipped': false};
    expect(await store.savePlan(plan), isTrue); expect(await store.start(plan: plan), isTrue);
    final changed = copy(plan); changed['items'][0]['weightKg'] = 100.0; await store.savePlan(changed);
    await reopen(); expect(store.draft!['plan']['targets'][0]['sets'][0]['weightKg'], 40);
    final decoded = decodeBackup(jsonEncode(store.exportBackup()), now: now);
    expect(decoded['sessions'][0]['plan']['targets'][0]['sets'][0]['weightKg'], 40);
  });
  test('cardio records remain manual and unknown measurements stay absent', () async {
    expect(await store.start(activity: 'outdoorRun'), isTrue);
    now = now.add(const Duration(minutes: 20));
    expect(await store.updateCardio({'distanceMeters': 3000.0}), isTrue); expect(await store.finish(), isTrue);
    await reopen(); final a = store.history.single['activity'] as Json;
    expect(a['source'], 'manual'); expect(a['distanceMeters'], 3000); expect(a['activeEnergyKcal'], isNull); expect(a['heartRate'], isEmpty);
  });
  test('malformed and future-schema imports cannot modify current records', () async {
    final before = jsonEncode(store.exportBackup()); final bad = store.exportBackup(); bad['schemaVersion'] = 99;
    expect(() => decodeBackup(jsonEncode(bad), now: now), throwsFormatException);
    expect(await store.importBackup(bad), isFalse); expect(jsonEncode(store.exportBackup()), before);
    expect(() => decodeBackup('{broken', now: now), throwsFormatException);
  });
  test('duplicate IDs are rejected case-insensitively', () {
    final bad = store.exportBackup(); final list = bad['exercises'] as List;
    final duplicate = copy(list.first as Json); duplicate['id'] = (duplicate['id'] as String).toUpperCase(); list.add(duplicate);
    expect(() => validateBackup(bad, now: now), throwsFormatException);
  });
  test('unrelated native fields and measurement ownership survive round trip', () async {
    final backup = store.exportBackup();
    backup['bodyWeights'] = [{'id': newID(), 'date': stamp(now), 'weightKg': 70.5}];
    backup['settings']['representatives'] = {'horizontalPush': catalog.first['id']};
    backup['settings']['unit'] = 'lb'; backup['settings']['targetSuggestionsEnabled'] = false;
    expect(await store.importBackup(decodeBackup(jsonEncode(backup), now: now)), isTrue); await reopen();
    expect(store.exportBackup()['bodyWeights'], backup['bodyWeights']); expect(store.settings, backup['settings']);
  });
  test('corrupt database refuses to open and does not reset original file', () async {
    await store.close(); final file = File('${dir.path}/training.db'); await file.writeAsString('not a sembast database');
    await expectLater(TrainingStore.open(file.path, catalog, clock: () => now), throwsA(anything));
    expect(await file.readAsString(), 'not a sembast database');
  });
  test('backup export fixture for native Swift compatibility check', () async {
    final ids = await prepare(); await store.beginSet(ids.$2); now = now.add(const Duration(seconds: 15)); await store.completeSet(ids.$1, ids.$2); await store.finish();
    final fixture = File('../artifacts/cross-backup-fixture.json'); await fixture.parent.create(recursive: true);
    await fixture.writeAsString(jsonEncode(store.exportBackup()));
    expect(decodeBackup(await fixture.readAsString(), now: now)['sessions'].length, 1);
  });
}
