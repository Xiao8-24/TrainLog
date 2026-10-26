import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'model.dart';

class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, required this.labels, required this.sessions, required this.now});
  final Json labels;
  final List<Json> sessions;
  final DateTime now;
  @override Widget build(BuildContext context) {
    final counts = <String, int>{};
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    for (final session in sessions) {
      if (session['status'] != 'completed' || session['mode'] != 'detailed' || date(session['date']).toLocal().isBefore(from) || date(session['date']).isAfter(now)) { continue; }
      for (final e in (session['exercises'] as List).cast<Json>()) {
        final n = (e['sets'] as List).cast<Json>().where((s) => s['isCompleted'] == true && ['working', 'drop'].contains(s['kind'])).length;
        for (final m in e['exercise']['primary'] as List) { counts[m as String] = (counts[m] ?? 0) + n; }
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final view in ['front', 'back']) Expanded(child: Column(children: [
        Text(view == 'front' ? '正面' : '背面'), const SizedBox(height: 10),
        ExcludeSemantics(child: SizedBox(height: 260, child: Center(child: AspectRatio(aspectRatio: 200/440, child: CustomPaint(painter: _BodyPainter(labels: labels, view: view, counts: counts, base: scheme.surfaceContainerHighest, line: scheme.outlineVariant, color: scheme.primary)))))),
      ]))]),
      const SizedBox(height: 16),
      Text(counts.values.every((n) => n == 0) ? '近 7 天暂无已完成的正式组' : '近 7 天主要肌群的已完成正式组 / 递减组', textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 4, children: counts.entries.where((e) => e.value > 0).map((e) => Chip(label: Text('${labels['muscles'][e.key]} ${e.value} 组'))).toList()),
      const SizedBox(height: 8), const Text('颜色仅反映记录的组数，不代表恢复状态或肌肉增长。', textAlign: TextAlign.center),
    ]);
  }
}
class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.labels, required this.view, required this.counts, required this.base, required this.line, required this.color});
  final Json labels; final String view; final Map<String, int> counts; final Color base, line, color;
  Path path(List points, Size size) {
    final p = Path();
    for (final (i, point) in points.indexed) {
      final x = number(point[0]) / 200 * size.width, y = number(point[1]) / 440 * size.height;
      if (i == 0) { p.moveTo(x, y); } else { p.lineTo(x, y); }
    }
    return p..close();
  }
  @override void paint(Canvas canvas, Size size) {
    canvas.drawPath(path(labels['outline'] as List, size), Paint()..color = base);
    final maxCount = math.max(1, counts.values.fold<int>(0, math.max));
    for (final region in (labels['regions'] as List).cast<Json>().where((r) => r['view'] == view)) {
      final n = counts[region['muscle']] ?? 0;
      final p = path(region['points'] as List, size);
      canvas.drawPath(p, Paint()..color = n == 0 ? Color.lerp(base, line, 0.25)! : Color.lerp(base, color, 0.25 + 0.65 * n / maxCount)!);
      canvas.drawPath(p, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 0.6);
    }
  }
  @override bool shouldRepaint(covariant _BodyPainter old) => old.view != view || old.base != base || old.line != line || old.color != color || !mapsEqual(old.counts, counts);
  bool mapsEqual(Map<String, int> a, Map<String, int> b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
