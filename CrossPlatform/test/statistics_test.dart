import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/model.dart';
import 'package:trainlog/statistics.dart';

Json session(DateTime day, List<Json> values, {List<String> primary = const ['chest'], List<String> secondary = const ['triceps'], String tracking = 'weightReps', String loading = 'perHand'}) => {
  'status': 'completed', 'mode': 'detailed', 'date': stamp(day),
  'exercises': [{'exercise': {'primary': primary, 'secondary': secondary, 'tracking': tracking, 'loading': loading}, 'sets': values}],
};
Json recorded(String kind, {bool completed = true}) => {'kind': kind, 'isCompleted': completed, 'weightKg': 10.0, 'reps': 8};

void main() {
  test('formal sets and external volume exclude warm-up, drop, failed and unfinished sets', () {
    final value = session(DateTime(2026, 10, 26, 12), [recorded('working'), recorded('warmup'), recorded('drop'), recorded('failed'), recorded('working', completed: false)]);
    expect(workingSets(value).length, 1);
    expect(workoutVolumeKg(value), 160);
    expect(workoutVolumeKg(session(DateTime(2026, 10, 26), [recorded('drop')])), isNull);
    expect(workoutVolumeKg(session(DateTime(2026, 10, 26), [recorded('working')], tracking: 'bodyweightReps', loading: 'bodyweight')), isNull);
  });
  test('weekly muscle coverage matches native day deduplication, secondary muscles and quick records', () {
    final monday = DateTime(2026, 10, 26, 12);
    final values = [
      session(monday, [recorded('working')]),
      session(monday.add(const Duration(hours: 2)), [recorded('working')]),
      session(DateTime(2026, 10, 27, 12), [recorded('drop')]),
      session(DateTime(2026, 10, 25, 12), [recorded('working')]),
      session(DateTime(2026, 11, 2, 12), [recorded('working')]),
      session(monday, [recorded('warmup'), recorded('failed')], primary: ['calves'], secondary: []),
      {'status': 'completed', 'mode': 'quick', 'date': stamp(DateTime(2026, 10, 28, 12)), 'quickEntries': [{'muscle': 'quadriceps'}]},
      {'status': 'draft', 'mode': 'detailed', 'date': stamp(monday), 'exercises': []},
    ];
    expect(muscleTrainingDays(values, DateTime(2026, 10, 28, 18)), {'chest': 2, 'triceps': 2, 'quadriceps': 1});
    expect([0, 1, 2, 3, 4, 6, 7].map(muscleDayLevel), [0, 1, 2, 2, 3, 3, 4]);
  });
}
