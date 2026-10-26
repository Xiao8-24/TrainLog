import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'model.dart';
import 'store.dart';
import 'muscle_map.dart';
import 'generated_tokens.dart';
part 'editors.dart';
part 'pages.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const Bootstrap()); }

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override State<Bootstrap> createState() => _BootstrapState();
}
class _BootstrapState extends State<Bootstrap> {
  late Future<(TrainingStore, Json)> ready = load();
  Future<(TrainingStore, Json)> load() async {
    final catalog = jsonDecode(await rootBundle.loadString('assets/catalog.json')) as Json;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return (await TrainingStore.open('${dir.path}${Platform.pathSeparator}trainlog.db', objects(catalog['exercises'])), catalog);
  }
  @override Widget build(BuildContext context) => FutureBuilder<(TrainingStore, Json)>(future: ready, builder: (context, snapshot) {
    if (snapshot.hasData) { return TrainLogApp(store: snapshot.data!.$1, labels: snapshot.data!.$2); }
    return MaterialApp(home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: snapshot.hasError
      ? Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.storage_outlined, size: 48), const SizedBox(height: 16), const Text('暂时无法打开训练记录', style: TextStyle(fontSize: 22)), const SizedBox(height: 12), const Text('可能有另一个窗口正在运行，或记录文件无法读取。原文件已保留，不会自动清空。'), const SizedBox(height: 20), FilledButton(onPressed: () => setState(() => ready = load()), child: const Text('重试'))])
      : const CircularProgressIndicator()))));
  });
}

class TrainLogApp extends StatelessWidget {
  const TrainLogApp({super.key, required this.store, required this.labels});
  final TrainingStore store;
  final Json labels;
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) {
    ThemeData theme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      final accent = dark ? TrainLogTokens.accentDark : TrainLogTokens.accentLight;
      final background = dark ? TrainLogTokens.groupedBackgroundDark : TrainLogTokens.groupedBackgroundLight;
      final card = dark ? TrainLogTokens.cardDark : TrainLogTokens.cardLight;
      return ThemeData(
      useMaterial3: true, brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(primary: accent, surface: card),
      scaffoldBackgroundColor: background,
      fontFamily: Platform.isWindows ? 'Segoe UI' : null,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, color: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TrainLogTokens.cardRadius))),
      appBarTheme: AppBarTheme(backgroundColor: background, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: card, elevation: 0),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: background),
    );
    }
    return MaterialApp(title: 'TrainLog', debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'), supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme(Brightness.light), darkTheme: theme(Brightness.dark),
      themeMode: switch (store.settings['theme']) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system },
      home: Home(store: store, labels: labels));
  });
}

class Home extends StatefulWidget {
  const Home({super.key, required this.store, required this.labels});
  final TrainingStore store;
  final Json labels;
  @override State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  TrainingStore get store => widget.store;
  int page = 0;
  bool workout = false;
  final names = const ['训练', '日历', '动作', '设置'];
  final icons = const [Icons.fitness_center, Icons.calendar_month_outlined, Icons.search, Icons.settings_outlined];
  Future<void> perform(Future<bool> Function() action) async {
    final ok = await action();
    if (!ok && mounted && store.error != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!))); }
  }
  Future<void> start({Json? plan, String? activity}) async {
    if (store.draft != null) { setState(() => workout = true); return; }
    await perform(() => store.start(plan: plan, activity: activity));
    if (mounted && store.draft != null) { setState(() => workout = true); }
  }
  Future<void> pickActivity() async {
    final activity = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('选择运动'), children: (widget.labels['activities'] as Json).entries.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key), child: Padding(padding: const EdgeInsets.all(8), child: Text(e.value as String)))).toList()));
    if (activity != null) { await start(activity: activity); }
  }
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pages = <Widget>[
      Dashboard(store: store, labels: widget.labels, onStart: start, onCardio: pickActivity, onPlan: () => editPlan(context, store, widget.labels), onResume: () => setState(() => workout = true), perform: perform),
      CalendarPage(store: store, labels: widget.labels, onStart: (p) => start(plan: p), perform: perform),
      CatalogPage(store: store, labels: widget.labels),
      SettingsPage(store: store, perform: perform),
    ];
    return PopScope(canPop: !workout, onPopInvokedWithResult: (didPop, result) { if (!didPop) { setState(() => workout = false); } }, child: Scaffold(
      appBar: AppBar(title: Text(workout && store.draft != null ? '正在训练' : 'TrainLog · ${names[page]}'),
        leading: workout ? IconButton(tooltip: '返回，训练继续计时', icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => workout = false)) : null,
        actions: [if (store.busy) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: Row(children: [if (wide && !workout) NavigationRail(selectedIndex: page, labelType: NavigationRailLabelType.all,
        onDestinationSelected: (i) => setState(() => page = i), destinations: List.generate(4, (i) => NavigationRailDestination(icon: Icon(icons[i]), label: Text(names[i])))),
        Expanded(child: Column(children: [if (store.error != null) MaterialBanner(content: Text(store.error!), actions: [TextButton(onPressed: () => setState(() => store.error = null), child: const Text('知道了'))]),
          Expanded(child: AnimatedSwitcher(duration: Duration(milliseconds: reduce ? 0 : 180), child: KeyedSubtree(key: ValueKey(workout && store.draft != null ? 'workout' : page.toString()), child: workout && store.draft != null
            ? WorkoutPage(store: store, labels: widget.labels, perform: perform, onExit: () => setState(() => workout = false)) : pages[page]))),
          if (!workout && store.draft != null) SafeArea(top: false, child: Material(color: Theme.of(context).colorScheme.secondaryContainer, child: ListTile(leading: const Icon(Icons.play_circle_outline), title: const Text('继续当前训练'), subtitle: ClockLabel(value: () => '${store.draft!['timerStartedAt'] == null ? '已暂停 · ' : ''}${clock(elapsed(store.draft!, store.now()))}'), trailing: const Icon(Icons.chevron_right), onTap: () => setState(() => workout = true)))),
        ])),
      ]),
      bottomNavigationBar: wide || workout ? null : NavigationBar(selectedIndex: page, onDestinationSelected: (i) => setState(() => page = i), destinations: List.generate(4, (i) => NavigationDestination(icon: Icon(icons[i]), label: names[i]))),
    ));
  });
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override Widget build(BuildContext context) => Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1080), child: ListView(padding: const EdgeInsets.fromLTRB(TrainLogTokens.contentSpacing, 12, TrainLogTokens.contentSpacing, 32), children: children)));
}
class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)), const SizedBox(height: 12), child]));
}
class ClockLabel extends StatefulWidget {
  const ClockLabel({super.key, required this.value, this.style});
  final String Function() value;
  final TextStyle? style;
  @override State<ClockLabel> createState() => _ClockLabelState();
}
class _ClockLabelState extends State<ClockLabel> {
  Timer? timer;
  @override void initState() { super.initState(); timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) { setState(() {}); } }); }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Text(widget.value(), style: widget.style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]) ?? const TextStyle(fontFeatures: [FontFeature.tabularFigures()]));
}
String titleFor(Json s, Json labels) => s['plan']?['name'] as String? ?? (s['mode'] == 'cardio' ? (labels['activities'][s['activity']?['kind']] as String? ?? '运动') : s['mode'] == 'quick' ? '快速肌群记录' : '力量训练');
String dayLabel(DateTime value) => '${value.year}年${value.month}月${value.day}日';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.store, required this.labels, required this.onStart, required this.onCardio, required this.onPlan, required this.onResume, required this.perform});
  final TrainingStore store;
  final Json labels;
  final Future<void> Function({Json? plan, String? activity}) onStart;
  final VoidCallback onCardio, onPlan, onResume;
  final Future<void> Function(Future<bool> Function()) perform;
  @override Widget build(BuildContext context) {
    final now = store.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final week = store.history.where((s) => !date(s['date']).toLocal().isBefore(monday) && date(s['date']).toLocal().isBefore(monday.add(const Duration(days: 7)))).toList();
    final today = store.history.where((s) { final day = date(s['date']).toLocal(); return day.year == now.year && day.month == now.month && day.day == now.day; }).length;
    final trainingDays = week.map((s) { final day = date(s['date']).toLocal(); return '${day.year}-${day.month}-${day.day}'; }).toSet().length;
    final totalMinutes = (week.fold<double>(0, (sum, s) => sum + elapsed(s, now)) / 60).floor();
    final completedSets = week.fold<int>(0, (sum, s) => sum + sets(s).where((v) => v['isCompleted'] == true).length);
    final upcoming = store.plans.where((p) => p['isSkipped'] != true && !store.history.any((s) => s['plan']?['id'] == p['id'])).toList()..sort((a, b) => date(a['scheduledAt']).compareTo(date(b['scheduledAt'])));
    return PageBody(children: [
      Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dayLabel(now), style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 6), Text(today == 0 ? '今天准备练什么？' : '每一次记录，都在积累。', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 6), Text(today == 0 ? '专注当下，让进步慢慢清晰。' : '今天已完成 $today 次训练。')])),
      Section('本周训练', subtitle: '周一开始 · 次数与训练天数分别统计', child: Card(child: Padding(padding: const EdgeInsets.all(TrainLogTokens.contentSpacing), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${week.length} / ${store.settings['weeklyGoal']} 次', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontFeatures: const [FontFeature.tabularFigures()])), const SizedBox(height: 12), LinearProgressIndicator(value: (week.length / (store.settings['weeklyGoal'] as int)).clamp(0, 1), minHeight: 7, borderRadius: BorderRadius.circular(6)), const SizedBox(height: 16), Row(children: [Expanded(child: _WeekMetric('训练天数', '$trainingDays 天')), Expanded(child: _WeekMetric('总时长', '$totalMinutes 分钟')), Expanded(child: _WeekMetric('正式组数', '$completedSets 组'))])])))),
      Section('开始今天的训练', child: Wrap(spacing: 12, runSpacing: 12, children: [FilledButton.icon(onPressed: store.busy ? null : store.draft != null ? onResume : () => onStart(), icon: const Icon(Icons.fitness_center), label: Text(store.draft != null ? '继续训练' : '力量训练')), FilledButton.tonalIcon(onPressed: store.busy ? null : onCardio, icon: const Icon(Icons.directions_run), label: const Text('有氧与其他运动')), OutlinedButton.icon(onPressed: store.busy ? null : onPlan, icon: const Icon(Icons.event_available_outlined), label: const Text('安排训练'))])),
      if (labels['regions'] != null) Section('肌群分布', child: MuscleMap(labels: labels, sessions: store.history, now: now)),
      Section('训练安排', subtitle: '计划不会随实际记录一起改变。随时可在日历中查看。', child: upcoming.isEmpty ? const EmptyState(Icons.event_note_outlined, '还没有训练计划', '先选动作和目标组数，再安排日期。') : Column(children: upcoming.take(5).map((p) => Card(child: ListTile(title: Text(p['name'] as String), subtitle: Text('${dayLabel(date(p['scheduledAt']).toLocal())} · ${(p['items'] as List).length} 个动作'), trailing: const Icon(Icons.play_arrow), onTap: store.busy ? null : () => onStart(plan: p)))).toList())),
      Section('最近训练', child: store.history.isEmpty ? const EmptyState(Icons.insights_outlined, '从第一组开始', '完成的训练会保存在这里，不会预填演示记录。') : Column(children: store.history.take(8).map((s) => SessionTile(session: s, labels: labels, store: store, perform: perform)).toList())),
    ]);
  }
}
class _WeekMetric extends StatelessWidget {
  const _WeekMetric(this.title, this.value);
  final String title, value;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 5), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))]);
}
class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.title, this.message, {super.key});
  final IconData icon; final String title, message;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 10), Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center)])));
}

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key, required this.store, required this.labels, required this.perform, required this.onExit});
  final TrainingStore store; final Json labels;
  final Future<void> Function(Future<bool> Function()) perform; final VoidCallback onExit;
  @override Widget build(BuildContext context) {
    final s = store.draft!;
    final active = activeSet(s);
    return PageBody(children: [
      Section(titleFor(s, labels), subtitle: s['timerStartedAt'] == null ? '已暂停 · 返回其他页面不会结束训练' : '计时中 · 后台和重启后可继续', child: Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [ClockLabel(value: () => clock(elapsed(store.draft ?? s, store.now())), style: Theme.of(context).textTheme.displaySmall), FilledButton.tonalIcon(onPressed: store.busy ? null : () => perform(store.togglePause), icon: Icon(s['timerStartedAt'] == null ? Icons.play_arrow : Icons.pause), label: Text(s['timerStartedAt'] == null ? '继续' : '暂停')), OutlinedButton(onPressed: store.busy ? null : () async {
        if (!await confirm(context, '结束并保存训练？', '未完成的组会保留为未完成。正在计时的组需要先完成。', '结束并保存')) { return; }
        await perform(store.finish); if (store.draft == null) { onExit(); }
      }, child: const Text('结束训练'))])),
      RestPanel(store: store, perform: perform),
      if (s['mode'] == 'cardio') Section('运动数据', subtitle: '本版本手动记录时长和适用运动的距离；未连接传感器，不会生成心率、血氧或消耗估算。', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('距离：${s['activity']['distanceMeters'] == null ? '未填写' : '${number(s['activity']['distanceMeters']) / 1000} km'}'), const SizedBox(height: 8), Text('活动能量：${s['activity']['activeEnergyKcal'] ?? '未知'} kcal${s['activity']['source'] == 'appleWatch' ? '（导入值）' : ''}'), const SizedBox(height: 12), OutlinedButton(onPressed: store.busy ? null : () => editCardio(context, store, perform), child: const Text('填写运动数据'))])),
      if (s['mode'] == 'quick') const Section('来自 iOS 的快速草稿', subtitle: '保留肌群资料，可在 iOS 继续编辑；这里可以结束或舍弃。', child: SizedBox.shrink()),
      if (s['mode'] == 'detailed') ...[
        if ((s['exercises'] as List).isEmpty) const EmptyState(Icons.add_circle_outline, '添加第一个动作', '填写本组目标，然后开始逐组计时。'),
        for (final entry in (s['exercises'] as List).cast<Json>()) Padding(padding: const EdgeInsets.only(bottom: 20), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry['exercise']['name'] as String, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4), Text(loadingLabel(entry['exercise'] as Json)),
          const SizedBox(height: 12),
          for (final (index, set) in (entry['sets'] as List).cast<Json>().indexed) Padding(padding: const EdgeInsets.only(bottom: 8), child: SetRow(index: index, set: set, exercise: entry['exercise'] as Json, store: store,
            onEdit: () => editSet(context, store, entry['id'] as String, set, entry['exercise'] as Json, perform),
            onStart: store.busy || set['isCompleted'] == true || active != null && active['id'] != set['id'] ? null : () => perform(() => store.beginSet(set['id'] as String)),
            onComplete: store.busy || set['isCompleted'] == true || active != null && active['id'] != set['id'] ? null : () => perform(() => store.completeSet(entry['id'] as String, set['id'] as String)))),
          TextButton.icon(onPressed: store.busy ? null : () => perform(() => store.addSet(entry['id'] as String)), icon: const Icon(Icons.add), label: const Text('加一组')),
        ])))),
        OutlinedButton.icon(onPressed: store.busy ? null : () async { final e = await pickExercise(context, store, labels); if (e != null) { await perform(() => store.addExercise(e)); } }, icon: const Icon(Icons.add), label: const Text('添加动作')),
      ],
      const SizedBox(height: 24),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notes), title: const Text('训练备注'), subtitle: Text((s['notes'] as String).isEmpty ? '记录感受或器械设置' : s['notes'] as String), onTap: store.busy ? null : () async {
        final text = await editText(context, '训练备注', s['notes'] as String);
        if (text != null) { await perform(() => store.updateNotes(text)); }
      }),
      const SizedBox(height: 20),
      TextButton(onPressed: store.busy ? null : () async { if (await confirm(context, '舍弃这次训练？', '本次未保存为历史的训练将删除。', '舍弃训练')) { await perform(store.discard); if (store.draft == null) { onExit(); } } }, child: const Text('舍弃本次训练')),
    ]);
  }
}
String loadingLabel(Json e) => switch (e['loading']) { 'perHand' => '重量按每只哑铃填写 · 总容量按双手计算', 'bodyweight' => '记录次数 · 不把体重估算为负荷', 'assistance' => '辅助重量 · 越小通常越难', 'timeOnly' => '记录持续秒数', _ => '重量按总外部负重填写' };
String setLabel(Json set, Json exercise) {
  if (exercise['tracking'] == 'duration') { return '${set['durationSeconds'] ?? '—'} 秒'; }
  final reps = '${set['reps'] ?? '—'} 次';
  return exercise['tracking'] == 'bodyweightReps' ? reps : '${set['weightKg'] ?? '—'} kg × $reps';
}
class SetRow extends StatelessWidget {
  const SetRow({super.key, required this.index, required this.set, required this.exercise, required this.store, required this.onEdit, this.onStart, this.onComplete});
  final int index; final Json set, exercise; final TrainingStore store; final VoidCallback onEdit; final VoidCallback? onStart, onComplete;
  @override Widget build(BuildContext context) {
    final done = set['isCompleted'] == true; final timing = set['timing'] as Json?;
    return DecoratedBox(decoration: BoxDecoration(color: done ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 17, child: done ? const Icon(Icons.check, size: 18) : Text('${index + 1}')), const SizedBox(width: 10), Expanded(child: Text(setLabel(set, exercise), style: Theme.of(context).textTheme.titleMedium)), if (!done) IconButton(tooltip: '编辑第 ${index + 1} 组', onPressed: store.busy ? null : onEdit, icon: const Icon(Icons.edit_outlined))]),
      if (timing != null) Padding(padding: const EdgeInsets.fromLTRB(44, 0, 0, 6), child: ClockLabel(value: () => '本组 ${clock(elapsed(timing, store.now()))}${timing['endedAt'] != null ? ' · 已完成' : timing['timerStartedAt'] == null ? ' · 已暂停' : ' · 计时中'}')),
      if (!done) Wrap(spacing: 8, runSpacing: 4, children: [TextButton.icon(onPressed: onStart, icon: Icon(timing == null ? Icons.play_arrow : Icons.timer_outlined), label: Text(timing == null ? '开始本组' : timing['timerStartedAt'] == null ? '继续本组' : '本组计时中')), FilledButton.tonalIcon(onPressed: onComplete, icon: const Icon(Icons.done), label: const Text('完成本组'))]),
      if (set['rpe'] != null || set['rir'] != null) Text('RPE ${set['rpe'] ?? '—'} · RIR ${set['rir'] ?? '—'}'),
    ])));
  }
}
class RestPanel extends StatelessWidget {
  const RestPanel({super.key, required this.store, required this.perform}); final TrainingStore store; final Future<void> Function(Future<bool> Function()) perform;
  @override Widget build(BuildContext context) => store.restUntil == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 20), child: Card(color: Theme.of(context).colorScheme.tertiaryContainer, child: ListTile(leading: const Icon(Icons.hourglass_bottom), title: ClockLabel(value: () => store.restRemaining > 0 ? '组间休息 ${clock(store.restRemaining)}' : '休息结束，准备下一组'), subtitle: const Text('开始下一组会结束休息 · 后台不发通知'), trailing: TextButton(onPressed: store.busy ? null : () => perform(store.endRest), child: const Text('结束休息')))));
}

Future<bool> confirm(BuildContext context, String title, String message, String action) async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action))])) ?? false;
Future<String?> editText(BuildContext context, String title, String initial) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text(title), content: TextField(controller: controller, maxLength: 10000, minLines: 3, maxLines: 8, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('保存'))]));
  // Dialog route may still animate out; dispose after it has detached.
  await Future<void>.delayed(const Duration(milliseconds: 300)); controller.dispose(); return result;
}
