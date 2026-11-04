import 'model.dart';

Iterable<Json> workingSets(Json session) => objects(session['exercises']).expand((entry) =>
  objects(entry['sets']).where((set) => set['isCompleted'] == true && set['kind'] == 'working'));

double? workoutVolumeKg(Json session) {
  double total = 0;
  var known = false;
  for (final entry in objects(session['exercises'])) {
    final exercise = entry['exercise'] as Json;
    if (exercise['tracking'] != 'weightReps') continue;
    for (final set in objects(entry['sets']).where((set) => set['isCompleted'] == true && set['kind'] == 'working')) {
      if (set['weightKg'] == null || set['reps'] == null) continue;
      total += number(set['weightKg']) * number(set['reps']) * (exercise['loading'] == 'perHand' ? 2 : 1);
      known = true;
    }
  }
  return known ? total : null;
}

/// Same Monday-based week and local calendar-day deduplication as the iOS overview.
Map<String, int> muscleTrainingDays(List<Json> sessions, DateTime now) {
  final local = now.toLocal();
  final from = DateTime(local.year, local.month, local.day - local.weekday + 1);
  final until = DateTime(from.year, from.month, from.day + 7);
  final days = <String, Set<DateTime>>{};
  for (final session in sessions) {
    final time = date(session['date']).toLocal();
    if (session['status'] != 'completed' || time.isBefore(from) || !time.isBefore(until)) continue;
    final coverage = <String>{};
    if (session['mode'] == 'quick') {
      coverage.addAll(objects(session['quickEntries']).map((entry) => entry['muscle'] as String));
    } else {
      for (final entry in objects(session['exercises'])) {
        if (!objects(entry['sets']).any((set) => set['isCompleted'] == true && ['working', 'drop'].contains(set['kind']))) continue;
        final exercise = entry['exercise'] as Json;
        coverage.addAll((exercise['primary'] as List).cast<String>());
        coverage.addAll((exercise['secondary'] as List).cast<String>());
      }
    }
    final day = DateTime(time.year, time.month, time.day);
    for (final muscle in coverage) { days.putIfAbsent(muscle, () => <DateTime>{}).add(day); }
  }
  return days.map((muscle, dates) => MapEntry(muscle, dates.length));
}

int muscleDayLevel(int days) => days <= 0 ? 0 : days == 1 ? 1 : days <= 3 ? 2 : days <= 6 ? 3 : 4;
