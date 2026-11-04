import 'package:flutter/material.dart';
import 'model.dart';
import 'statistics.dart';
import 'generated_tokens.dart';

class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, required this.labels, required this.sessions, required this.now});
  final Json labels;
  final List<Json> sessions;
  final DateTime now;
  @override Widget build(BuildContext context) {
    final counts = muscleTrainingDays(sessions, now);
    final scheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).brightness == Brightness.dark
      ? const [TrainLogTokens.heat0Dark, TrainLogTokens.heat1Dark, TrainLogTokens.heat2Dark, TrainLogTokens.heat3Dark, TrainLogTokens.heat4Dark]
      : const [TrainLogTokens.heat0Light, TrainLogTokens.heat1Light, TrainLogTokens.heat2Light, TrainLogTokens.heat3Light, TrainLogTokens.heat4Light];
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final view in ['front', 'back']) Expanded(child: Column(children: [
        Text(view == 'front' ? '正面' : '背面'), const SizedBox(height: 10),
        ExcludeSemantics(child: SizedBox(height: 260, child: Center(child: AspectRatio(aspectRatio: 200/440, child: CustomPaint(painter: _BodyPainter(labels: labels, view: view, counts: counts, palette: palette, line: scheme.outlineVariant)))))),
      ]))]),
      const SizedBox(height: 16),
      Text(counts.values.every((n) => n == 0) ? '本周暂无肌群训练记录' : '本周各肌群的训练天数', textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 8, children: List.generate(5, (i) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: palette[i], borderRadius: BorderRadius.circular(3))), const SizedBox(width: 4), Text(const ['0', '1', '2–3', '4–6', '≥7 天'][i])]))),
      Wrap(spacing: 8, runSpacing: 4, children: counts.entries.where((e) => e.value > 0).map((e) => Chip(label: Text('${labels['muscles'][e.key]} ${e.value} 天'))).toList()),
      const SizedBox(height: 8), const Text('同一天每个肌群只计 1 天，包含快速记录及有效正式／递减组的主次肌群。颜色不代表恢复状态或肌肉增长。', textAlign: TextAlign.center),
    ]);
  }
}
class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.labels, required this.view, required this.counts, required this.palette, required this.line});
  final Json labels; final String view; final Map<String, int> counts; final List<Color> palette; final Color line;
  Path path(List points, Size size) {
    final p = Path();
    for (final (i, point) in points.indexed) {
      final x = number(point[0]) / 200 * size.width, y = number(point[1]) / 440 * size.height;
      if (i == 0) { p.moveTo(x, y); } else { p.lineTo(x, y); }
    }
    return p..close();
  }
  @override void paint(Canvas canvas, Size size) {
    canvas.drawPath(path(labels['outline'] as List, size), Paint()..color = palette[0]);
    for (final region in (labels['regions'] as List).cast<Json>().where((r) => r['view'] == view)) {
      final n = counts[region['muscle']] ?? 0;
      final p = path(region['points'] as List, size);
      canvas.drawPath(p, Paint()..color = palette[muscleDayLevel(n)]);
      canvas.drawPath(p, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 0.6);
    }
  }
  @override bool shouldRepaint(covariant _BodyPainter old) => old.view != view || old.line != line || old.palette.length != palette.length || old.palette.asMap().entries.any((e) => palette[e.key] != e.value) || !mapsEqual(old.counts, counts);
  bool mapsEqual(Map<String, int> a, Map<String, int> b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
