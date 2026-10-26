import 'dart:convert';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;
const _uuid = Uuid();
String newID() => _uuid.v4();
String stamp(DateTime value) => value.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
DateTime date(dynamic value) {
  require(value is String && RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$').hasMatch(value), '日期格式无效');
  final v = value as String;
  final year = int.parse(v.substring(0, 4)), month = int.parse(v.substring(5, 7)), day = int.parse(v.substring(8, 10));
  require(month >= 1 && month <= 12 && day >= 1 && day <= DateTime.utc(year, month + 1, 0).day && int.parse(v.substring(11, 13)) <= 23 && int.parse(v.substring(14, 16)) <= 59 && int.parse(v.substring(17, 19)) <= 59, '日期值无效');
  return DateTime.parse(v);
}
const distanceActivities = {'outdoorRun', 'indoorRun', 'outdoorWalk', 'indoorWalk', 'outdoorCycle', 'indoorCycle', 'swimming', 'openWaterSwimming', 'rowing', 'hiking', 'skating', 'crossCountrySkiing', 'downhillSkiing', 'snowboarding', 'paddling'};
const activityKinds = {...distanceActivities, 'elliptical', 'stairClimbing', 'jumpRope', 'hiit', 'mixedCardio', 'dance', 'kickboxing', 'boxing', 'crossTraining', 'yoga', 'pilates', 'flexibility', 'coreTraining', 'functionalStrength', 'traditionalStrength', 'badminton', 'tennis', 'tableTennis', 'basketball', 'football', 'volleyball', 'squash', 'climbing'};
const muscleKinds = {'chest', 'trapezius', 'upperBack', 'lats', 'frontDeltoid', 'sideDeltoid', 'rearDeltoid', 'biceps', 'triceps', 'forearms', 'abs', 'obliques', 'lowerBack', 'glutes', 'quadriceps', 'hamstrings', 'calves', 'tibialis'};
Json copy(Json value) => jsonDecode(jsonEncode(value)) as Json;
List<Json> objects(dynamic value) => (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
double number(dynamic value, [double fallback = 0]) => value is num ? value.toDouble() : fallback;
String clock(double seconds) {
  final n = seconds.clamp(0, 315576000).floor();
  return n >= 3600 ? '${n ~/ 3600}:${(n ~/ 60 % 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}'
      : '${n ~/ 60}:${(n % 60).toString().padLeft(2, '0')}';
}
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
double elapsed(Json value, DateTime now) => value['manualDurationSeconds'] != null
    ? number(value['manualDurationSeconds'])
    : number(value['accumulatedSeconds']) + (value['timerStartedAt'] == null ? 0 : now.difference(date(value['timerStartedAt'])).inMilliseconds.clamp(0, 315576000000) / 1000);
void pauseClock(Json value, DateTime now) {
  value['accumulatedSeconds'] = elapsed(value, now);
  value.remove('timerStartedAt');
}
void resumeClock(Json value, DateTime now) {
  value.remove('manualDurationSeconds');
  value['timerStartedAt'] ??= stamp(now);
}
Iterable<Json> sets(Json session) sync* {
  for (final entry in session['exercises'] as List) {
    for (final set in entry['sets'] as List) { yield set as Json; }
  }
}
Json? activeSet(Json session) {
  for (final s in sets(session)) {
    if (s['timing'] != null && s['timing']['endedAt'] == null) { return s; }
  }
  return null;
}
Json freshSet({Json? previous, int rest = 90}) {
  final s = previous == null ? <String, dynamic>{'kind': 'working', 'notes': '', 'restSeconds': rest} : copy(previous);
  s['id'] = newID(); s['isCompleted'] = false;
  for (final key in ['timing', 'rpe', 'rir']) { s.remove(key); }
  return s;
}
Json newSession(String mode, DateTime now, {String activity = 'outdoorRun'}) => {
  'id': newID(), 'date': stamp(now), 'startTime': stamp(now), 'status': 'draft', 'mode': mode,
  'notes': '', 'exercises': <Json>[], 'quickEntries': <Json>[], 'accumulatedSeconds': 0,
  'timerStartedAt': stamp(now), 'createdAt': stamp(now), 'updatedAt': stamp(now),
  if (mode == 'cardio') 'activity': {'kind': activity, 'source': 'manual', 'heartRate': <Json>[]},
};
Json entryFromItem(Json exercise, Json item, int rest) => {
  'id': newID(), 'exercise': copy(exercise), 'notes': '',
  'sets': List.generate(item['setCount'] as int? ?? 3, (_) => {
    ...freshSet(rest: item['restSeconds'] as int? ?? rest),
    for (final key in ['weightKg', 'reps', 'durationSeconds']) if (item[key] != null) key: item[key],
  }),
};

void require(bool condition, String message) { if (!condition) { throw FormatException(message); } }
void validateSet(Json s, Json exercise, {bool complete = false}) {
  for (final spec in [('weightKg', 0, 1500), ('reps', s['kind'] == 'failed' ? 0 : 1, 1000), ('durationSeconds', 1, 86400), ('rpe', 1, 10), ('rir', 0, 10), ('restSeconds', 0, 3600)]) {
    final v = s[spec.$1];
    require(v == null || v is num && v.isFinite && v >= spec.$2 && v <= spec.$3, '${spec.$1} 超出有效范围');
  }
  for (final k in ['reps', 'durationSeconds', 'restSeconds']) { require(s[k] == null || s[k] is int, '$k 必须为整数'); }
  require(['working', 'warmup', 'drop', 'failed'].contains(s['kind']), '训练组类型无效');
  require(s['isCompleted'] is bool && s['notes'] is String && s['restSeconds'] is int, '训练组字段无效');
  if (complete || s['isCompleted'] == true) {
    switch (exercise['tracking']) {
      case 'weightReps': case 'assistedReps': require(s['weightKg'] != null && s['reps'] != null, '请填写重量和次数');
      case 'bodyweightReps': require(s['reps'] != null, '请填写次数');
      case 'duration': require(s['durationSeconds'] != null, '请填写持续秒数');
      default: throw const FormatException('动作记录类型无效');
    }
  }
  if (s['timing'] != null) {
    final t = s['timing'] as Json;
    date(t['startedAt']);
    require(number(t['accumulatedSeconds'], -1) >= 0 && number(t['accumulatedSeconds']) <= 604800, '本组计时无效');
    if (t['endedAt'] != null) { require(!date(t['endedAt']).isBefore(date(t['startedAt'])) && t['timerStartedAt'] == null, '本组结束时间无效'); }
    require(s['isCompleted'] != true || t['endedAt'] != null, '已完成的组仍在计时');
    if (t['timerStartedAt'] != null) { date(t['timerStartedAt']); }
  }
}

/// Keep original fields, including Apple measurement ownership and plan targets.
/// Parsing never writes to the database; a failed import leaves all records intact.
Json decodeBackup(String text, {DateTime? now}) {
  require(utf8.encode(text).length <= 32 * 1024 * 1024, '备份不得超过 32 MB');
  final data = jsonDecode(text) as Json;
  validateBackup(data, now: now);
  return data;
}
void validateBackup(Json data, {DateTime? now}) {
  now ??= DateTime.now();
  require(data['schemaVersion'] is int && data['schemaVersion'] >= 1 && data['schemaVersion'] <= 5, '仅支持 TrainLog 原生备份 1–5；浏览器预览备份不兼容');
  date(data['exportedAt']);
  final exercises = objects(data['exercises']);
  final sessions = objects(data['sessions']);
  final templates = objects(data['templates']);
  final plans = objects(data['plans'] ?? []);
  final weights = objects(data['bodyWeights']);
  require(exercises.length <= 5000 && sessions.length <= 50000 && templates.length <= 1000 && plans.length <= 10000 && weights.length <= 10000, '备份记录过多');
  final ids = <String>{};
  void register(dynamic id) {
    require(id is String && RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$').hasMatch(id), '记录 ID 无效');
    require(ids.add((id as String).toLowerCase()), '备份存在重复 ID');
  }
  void exercise(Json e) {
    require(e['name'] is String && (e['name'] as String).trim().isNotEmpty && e['name'].length <= 100, '动作名称无效');
    require(e['englishName'] is String && e['primary'] is List && e['primary'].isNotEmpty && e['secondary'] is List, '肌群资料无效');
    final primary = (e['primary'] as List).toSet(), secondary = (e['secondary'] as List).toSet();
    require(primary.length == e['primary'].length && secondary.length == e['secondary'].length && primary.intersection(secondary).isEmpty && {...primary, ...secondary}.every(muscleKinds.contains), '肌群重复或类型无效');
    require(['barbell', 'dumbbell', 'cable', 'machine', 'bodyweight', 'other'].contains(e['equipment']), '器械类型无效');
    require({'weightReps': ['total', 'perHand'], 'bodyweightReps': ['bodyweight'], 'assistedReps': ['assistance'], 'duration': ['timeOnly']}[e['tracking']]?.contains(e['loading']) == true, '动作记录口径无效');
    for (final k in ['allowsEstimate', 'isCustom', 'isFavorite', 'isArchived']) { require(e[k] is bool, '动作字段无效'); }
    require(e['allowsEstimate'] != true || e['tracking'] == 'weightReps', '估算模式无效');
  }
  final catalog = <String, Json>{};
  for (final e in exercises) { register(e['id']); exercise(e); catalog[(e['id'] as String).toLowerCase()] = e; }
  int drafts = 0;
  for (final s in sessions) {
    register(s['id']);
    require(['draft', 'completed'].contains(s['status']) && ['quick', 'detailed', 'cardio'].contains(s['mode']), '训练状态无效');
    if (s['status'] == 'draft') { drafts++; }
    for (final k in ['date', 'startTime', 'createdAt', 'updatedAt']) { date(s[k]); }
    require(!date(s['date']).isAfter(now.add(const Duration(minutes: 1))), '训练记录不能在未来，计划请使用计划功能');
    require(s['notes'] is String && s['notes'].length <= 10000 && s['quickEntries'] is List && s['exercises'] is List, '训练字段无效');
    require(s['accumulatedSeconds'] is num && number(s['accumulatedSeconds']) >= 0 && number(s['accumulatedSeconds']) <= 315576000, '训练计时无效');
    if (s['timerStartedAt'] != null) { require(!date(s['timerStartedAt']).isAfter(now.add(const Duration(minutes: 1))), '训练开始时间无效'); }
    if (s['manualDurationSeconds'] != null) { require(s['manualDurationSeconds'] is num && number(s['manualDurationSeconds']) >= 0 && number(s['manualDurationSeconds']) <= 604800, '手动时长无效'); }
    require(s['intensity'] == null || ['light', 'moderate', 'hard'].contains(s['intensity']), '训练强度无效');
    require(s['sessionRPE'] == null || s['sessionRPE'] is num && number(s['sessionRPE']) >= 1 && number(s['sessionRPE']) <= 10, '训练 RPE 无效');
    if (s['status'] == 'completed') {
      require(s['timerStartedAt'] == null && s['endTime'] != null && !date(s['endTime']).isBefore(date(s['startTime'])) && !date(s['endTime']).isAfter(now.add(const Duration(minutes: 1))) && elapsed(s, now) <= 604800, '已完成训练时间无效');
    }
    for (final entry in objects(s['exercises'])) {
      register(entry['id']); final e = Map<String, dynamic>.from(entry['exercise'] as Map); exercise(e);
      require(catalog.containsKey((e['id'] as String).toLowerCase()), '记录引用了不存在的动作');
      require(entry['notes'] is String && entry['sets'] is List && entry['sets'].length <= 1000, '动作记录无效');
      for (final set in objects(entry['sets'])) { register(set['id']); validateSet(set, e); }
    }
    require(sets(s).where((v) => v['timing'] != null && v['timing']['endedAt'] == null).length <= 1, '只能有一组正在计时');
    final quickMuscles = <String>{};
    for (final q in objects(s['quickEntries'])) { register(q['id']); require(muscleKinds.contains(q['muscle']) && quickMuscles.add(q['muscle'] as String) && (q['intensity'] == null || ['light', 'moderate', 'hard'].contains(q['intensity'])), '快速记录肌群无效或重复'); }
    if (s['mode'] == 'detailed') {
      require((s['quickEntries'] as List).isEmpty && s['activity'] == null, '力量训练内容无效');
      if (s['status'] == 'completed') { require(sets(s).any((v) => v['isCompleted'] == true), '已完成训练缺少有效组'); }
    } else if (s['mode'] == 'cardio') {
      require((s['exercises'] as List).isEmpty && (s['quickEntries'] as List).isEmpty && s['activity'] is Map, '有氧记录内容无效');
      final a = s['activity'] as Json;
      require(activityKinds.contains(a['kind']) && ['manual', 'appleWatch'].contains(a['source']) && a['heartRate'] is List && a['heartRate'].length <= 10000, '有氧资料无效');
      require(a['distanceMeters'] == null || distanceActivities.contains(a['kind']) && a['distanceMeters'] is num && a['distanceMeters'].isFinite && a['distanceMeters'] >= 0 && a['distanceMeters'] <= 2000000, '该运动不支持距离或距离超出 0–2000 km');
      require(a['activeEnergyKcal'] == null || a['activeEnergyKcal'] is num && a['activeEnergyKcal'].isFinite && a['activeEnergyKcal'] >= 0 && a['activeEnergyKcal'] <= 100000, '活动能量无效');
      for (final k in ['averageHeartRate', 'maximumHeartRate']) { require(a[k] == null || a[k] is num && a[k].isFinite && a[k] >= 20 && a[k] <= 300, '心率无效'); }
      if (a['averageHeartRate'] != null && a['maximumHeartRate'] != null) { require(a['averageHeartRate'] <= a['maximumHeartRate'], '平均心率高于最高心率'); }
      if (a['source'] == 'manual') { require(a['activeEnergyKcal'] == null && a['averageHeartRate'] == null && a['maximumHeartRate'] == null && (a['heartRate'] as List).isEmpty && a['watchWorkoutID'] == null, '手动运动不能冒充 Apple Watch 测量值'); }
      if (a['source'] == 'appleWatch' && s['status'] == 'completed') { require(a['watchWorkoutID'] is String && Uuid.isValidUUID(fromString: a['watchWorkoutID'] as String), '手表记录缺少健康记录 ID'); }
      for (final point in objects(a['heartRate'])) {
        final at = date(point['date']); require(point['bpm'] is num && number(point['bpm']) >= 20 && number(point['bpm']) <= 300 && !at.isBefore(date(s['startTime'])) && !at.isAfter((s['endTime'] == null ? now : date(s['endTime'])).add(const Duration(seconds: 5))), '心率采样无效');
      }
      if (s['status'] == 'completed') { require(elapsed(s, now) > 0, '运动时长必须大于零'); }
    } else { require((s['exercises'] as List).isEmpty && s['activity'] == null && (s['status'] != 'completed' || (s['quickEntries'] as List).isNotEmpty), '快速记录内容无效'); }
    if (s['plan'] != null) {
      final p = s['plan'] as Json; date(p['scheduledAt']);
      require(s['mode'] == 'detailed' && p['id'] is String && p['id'] != s['id'] && p['name'] is String && p['name'].trim().isNotEmpty && p['name'].length <= 100, '开练时计划资料无效');
      if (p['targets'] != null) {
        final targets = objects(p['targets']); final targetIDs = <String>{}, setIDs = <String>{};
        require(targets.isNotEmpty && targets.length <= 100, '计划快照无效');
        for (final e in targets) {
          require(e['id'] is String && targetIDs.add((e['id'] as String).toLowerCase()), '计划快照动作 ID 重复');
          exercise(e['exercise'] as Json); final values = objects(e['sets']); require(values.isNotEmpty && values.length <= 30, '计划快照组数无效');
          for (final set in values) { require(setIDs.add((set['id'] as String).toLowerCase()) && set['kind'] == 'working' && set['isCompleted'] == false && set['timing'] == null, '计划快照包含无效组'); validateSet(set, e['exercise'] as Json); }
        }
      }
    }
  }
  require(drafts <= 1, '备份包含多个活动训练');
  for (final p in [...templates, ...plans]) {
    register(p['id']); require(p['name'] is String && p['name'].trim().isNotEmpty && p['name'].length <= 100, '计划或模板名称无效');
    final items = objects(p['items']); require(items.isNotEmpty && items.length <= 100, '计划动作应为 1–100 个');
    if (p['scheduledAt'] != null) { date(p['scheduledAt']); require(p['isSkipped'] is bool && p['notes'] is String, '计划字段无效'); }
    for (final i in items) {
      register(i['id']); final e = catalog[(i['exerciseID'] as String).toLowerCase()];
      require(e != null && i['setCount'] is int && i['setCount'] >= 1 && i['setCount'] <= 30, '计划动作或组数无效');
      validateSet({...freshSet(), ...i}, e!);
    }
  }
  for (final w in weights) { register(w['id']); require(!date(w['date']).isAfter(now.add(const Duration(minutes: 1))), '体重日期不能在未来'); require(w['weightKg'] is num && w['weightKg'] >= 20 && w['weightKg'] <= 500, '体重无效'); }
  final settings = data['settings'] as Json;
  require(['kg', 'lb'].contains(settings['unit']) && ['system', 'light', 'dark'].contains(settings['theme']), '设置无效');
  require(settings['weeklyGoal'] is int && settings['weeklyGoal'] >= 1 && settings['weeklyGoal'] <= 14 && settings['restSeconds'] is int && settings['restSeconds'] >= 0 && settings['restSeconds'] <= 3600, '目标或休息设置无效');
  require(settings['hasOnboarded'] is bool && settings['notifyRest'] is bool && settings['trainingGoal'] is String && settings['representatives'] is Map && (settings['targetSuggestionsEnabled'] == null || settings['targetSuggestionsEnabled'] is bool), '设置字段无效');
  for (final e in (settings['representatives'] as Json).entries) { require(catalog[e.value.toString().toLowerCase()]?['pattern'] == e.key, '代表动作模式不匹配'); }
}

Json initialBackup(List<Json> catalog, DateTime now) => {
  'schemaVersion': 5, 'exportedAt': stamp(now), 'sessions': <Json>[], 'exercises': catalog,
  'templates': <Json>[], 'plans': <Json>[], 'bodyWeights': <Json>[],
  'settings': {'unit': 'kg', 'weeklyGoal': 4, 'trainingGoal': '保持规律', 'theme': 'system', 'hasOnboarded': true, 'restSeconds': 90, 'notifyRest': false, 'representatives': <String, dynamic>{}, 'targetSuggestionsEnabled': true},
};
