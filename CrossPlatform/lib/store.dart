import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'database.dart';
import 'model.dart';

class TrainingStore extends ChangeNotifier {
  TrainingStore._(this._db, this._lock, this.data, this.restUntil, this.now);
  final RecordDatabase _db;
  final RandomAccessFile? _lock;
  final DateTime Function() now;
  Json data;
  String? restUntil;
  bool busy = false;
  String? error;
  bool closed = false;

  static Future<TrainingStore> open(String path, List<Json> catalog, {DateTime Function()? clock, bool lock = true}) async {
    RandomAccessFile? handle;
    RecordDatabase? db;
    try {
      if (lock) {
        await File(path).parent.create(recursive: true);
        handle = await File('$path.lock').open(mode: FileMode.append);
        await handle.lock(FileLock.exclusive);
      }
      db = await RecordDatabase.open(path);
      final record = await db.read();
      final current = clock ?? DateTime.now;
      final data = record == null ? initialBackup(catalog, current()) : copy(record['backup'] as Json);
      validateBackup(data, now: current());
      final store = TrainingStore._(db, handle, data, record?['restUntil'] as String?, current);
      if (record == null) { await db.write({'backup': data}); }
      return store;
    } catch (_) {
      await db?.close();
      await handle?.close();
      rethrow;
    }
  }
  List<Json> get sessions => (data['sessions'] as List).cast<Json>();
  List<Json> get catalog => (data['exercises'] as List).cast<Json>();
  List<Json> get plans => ((data['plans'] ?? []) as List).cast<Json>();
  Json get settings => data['settings'] as Json;
  Json? get draft {
    for (final s in sessions) { if (s['status'] == 'draft') { return s; } }
    return null;
  }
  List<Json> get history => sessions.where((s) => s['status'] == 'completed').toList()..sort((a, b) => date(b['date']).compareTo(date(a['date'])));
  double get restRemaining => restUntil == null || draft == null ? 0 : date(restUntil!).difference(now()).inMilliseconds.clamp(0, 3600000) / 1000;

  /// UI sees committed snapshots only. Failed writes roll back; no silent reset.
  Future<bool> change(void Function(Json next) edit, {String? rest, bool clearRest = false}) async {
    if (busy || closed) { return false; }
    busy = true; error = null; notifyListeners();
    try {
      final next = copy(data);
      edit(next);
      next['schemaVersion'] = 5; next['exportedAt'] = stamp(now());
      validateBackup(next, now: now());
      final nextRest = clearRest ? null : rest ?? restUntil;
      await _db.write({'backup': next, if (nextRest != null) 'restUntil': nextRest});
      data = next; restUntil = nextRest;
      return true;
    } catch (e) {
      error = e is FormatException ? e.message : '保存失败，原记录已保留。请检查磁盘空间后重试。';
      return false;
    } finally {
      busy = false; notifyListeners();
    }
  }
  Json _draft(Json next) => (next['sessions'] as List).cast<Json>().firstWhere((s) => s['status'] == 'draft');
  Future<bool> start({Json? plan, String? activity}) => change((next) {
    require(draft == null, '请先继续或结束当前训练');
    final session = newSession(activity == null ? 'detailed' : 'cardio', now(), activity: activity ?? 'outdoorRun');
    if (plan != null) {
      session['exercises'] = objects(plan['items']).map((i) => entryFromItem(catalog.firstWhere((e) => e['id'].toString().toLowerCase() == i['exerciseID'].toString().toLowerCase()), i, settings['restSeconds'] as int)).toList();
      session['plan'] = {'id': plan['id'], 'name': plan['name'], 'scheduledAt': plan['scheduledAt'], 'targets': jsonCloneEntries(session['exercises'] as List)};
    }
    (next['sessions'] as List).add(session);
  }, clearRest: true);
  Future<bool> addExercise(Json exercise) => change((next) {
    final s = _draft(next); require(s['mode'] == 'detailed', '当前不是力量训练');
    require((s['exercises'] as List).length < 100, '本次训练动作过多');
    (s['exercises'] as List).add(entryFromItem(exercise, {'setCount': 1}, settings['restSeconds'] as int));
    s['updatedAt'] = stamp(now());
  });
  Future<bool> addSet(String entryID) => change((next) {
    final s = _draft(next);
    final entry = (s['exercises'] as List).cast<Json>().firstWhere((e) => e['id'] == entryID);
    final list = entry['sets'] as List;
    require(list.length < 100, '单个动作最多 100 组');
    list.add(freshSet(previous: list.isEmpty ? null : list.last as Json, rest: settings['restSeconds'] as int));
    s['updatedAt'] = stamp(now());
  });
  Future<bool> editSet(String entryID, String setID, Json values) => change((next) {
    final s = _draft(next);
    final entry = (s['exercises'] as List).cast<Json>().firstWhere((e) => e['id'] == entryID);
    final set = (entry['sets'] as List).cast<Json>().firstWhere((v) => v['id'] == setID);
    require(set['isCompleted'] != true, '已完成组不能修改，请新增一组');
    for (final key in ['weightKg', 'reps', 'durationSeconds', 'rpe', 'rir', 'restSeconds', 'kind', 'notes']) {
      if (values[key] == null) { set.remove(key); } else { set[key] = values[key]; }
    }
    validateSet(set, entry['exercise'] as Json); s['updatedAt'] = stamp(now());
  });
  Future<bool> beginSet(String setID) => change((next) {
    final s = _draft(next); final active = activeSet(s);
    require(active == null || active['id'] == setID, '请先完成正在计时的那一组');
    final set = sets(s).firstWhere((v) => v['id'] == setID);
    require(set['isCompleted'] != true, '本组已经完成');
    resumeClock(s, now());
    set['timing'] ??= {'startedAt': stamp(now()), 'accumulatedSeconds': 0};
    resumeClock(set['timing'] as Json, now()); s['updatedAt'] = stamp(now());
  }, clearRest: true);
  Future<bool> completeSet(String entryID, String setID) => change((next) {
    final s = _draft(next); final active = activeSet(s);
    require(active == null || active['id'] == setID, '请先完成正在计时的那一组');
    final entry = (s['exercises'] as List).cast<Json>().firstWhere((e) => e['id'] == entryID);
    final set = (entry['sets'] as List).cast<Json>().firstWhere((v) => v['id'] == setID);
    require(set['isCompleted'] != true, '本组已经完成');
    final timing = set['timing'] as Json?;
    if (timing != null) {
      pauseClock(timing, now()); timing['endedAt'] = stamp(now());
      if (entry['exercise']['tracking'] == 'duration' && set['durationSeconds'] == null) { set['durationSeconds'] = elapsed(timing, now()).ceil(); }
    }
    validateSet(set, entry['exercise'] as Json, complete: true);
    set['isCompleted'] = true; s['updatedAt'] = stamp(now());
  }, rest: stamp(now().add(Duration(seconds: _restFor(setID)))), clearRest: _restFor(setID) == 0);
  int _restFor(String id) => draft == null ? 0 : sets(draft!).firstWhere((s) => s['id'] == id)['restSeconds'] as int;
  Future<bool> togglePause() => change((next) {
    final s = _draft(next); final running = s['timerStartedAt'] != null;
    if (running) { pauseClock(s, now()); } else { resumeClock(s, now()); }
    for (final set in sets(s)) {
      final t = set['timing'] as Json?;
      if (t != null && t['endedAt'] == null) { if (running) { pauseClock(t, now()); } else { resumeClock(t, now()); } }
    }
    s['updatedAt'] = stamp(now());
  }, clearRest: true);
  Future<bool> finish() => change((next) {
    final s = _draft(next);
    require(activeSet(s) == null, '请先完成正在计时的那一组');
    pauseClock(s, now()); s['status'] = 'completed'; s['endTime'] = stamp(now()); s['updatedAt'] = stamp(now());
  }, clearRest: true);
  Future<bool> discard() => change((next) { (next['sessions'] as List).removeWhere((s) => s['status'] == 'draft'); }, clearRest: true);
  Future<bool> updateNotes(String value) => change((next) { final s = _draft(next); s['notes'] = value; s['updatedAt'] = stamp(now()); });
  Future<bool> updateCardio(Json values) => change((next) {
    final s = _draft(next); require(s['mode'] == 'cardio', '当前不是有氧运动');
    final a = s['activity'] as Json;
    if (values['distanceMeters'] == null) { a.remove('distanceMeters'); } else { a['distanceMeters'] = values['distanceMeters']; }
    s['updatedAt'] = stamp(now());
  });
  Future<bool> savePlan(Json plan) => change((next) {
    final list = next['plans'] as List? ?? <Json>[];
    list.removeWhere((p) => p['id'] == plan['id']); list.add(copy(plan)); next['plans'] = list;
  });
  Future<bool> deletePlan(String id) => change((next) { (next['plans'] as List).removeWhere((p) => p['id'] == id); });
  Future<bool> deleteSession(String id) => change((next) { (next['sessions'] as List).removeWhere((p) => p['id'] == id && p['status'] == 'completed'); });
  Future<bool> endRest() => change((_) {}, clearRest: true);
  Future<bool> importBackup(Json imported) => change((next) {
    require(draft == null, '请先结束或舍弃当前训练，再导入备份');
    validateBackup(imported, now: now());
    next.clear(); next.addAll(copy(imported));
  }, clearRest: true);
  Json exportBackup() { final result = copy(data); result['schemaVersion'] = 5; result['exportedAt'] = stamp(now()); validateBackup(result, now: now()); return result; }
  Future<void> close() async {
    while (busy) { await Future<void>.delayed(const Duration(milliseconds: 10)); }
    closed = true; await _db.close(); await _lock?.close(); dispose();
  }
}

List<Json> jsonCloneEntries(List source) => source.map((e) => copy(e as Json)).toList();
