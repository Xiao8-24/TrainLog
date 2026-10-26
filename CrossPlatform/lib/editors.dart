part of 'main.dart';

Future<Json?> pickExercise(BuildContext context, TrainingStore store, Json labels) => showDialog<Json>(context: context, builder: (_) => Dialog(child: SizedBox(width: 600, height: 640, child: CatalogPage(store: store, labels: labels, onPick: (e) => Navigator.pop(context, e)))));

Future<void> editSet(BuildContext context, TrainingStore store, String entryID, Json set, Json exercise, Future<void> Function(Future<bool> Function()) perform) async {
  final values = await showDialog<Json>(context: context, builder: (_) => ValuesEditor(title: '记录本组', initial: set, exercise: exercise));
  if (values != null) { await perform(() => store.editSet(entryID, set['id'] as String, values)); }
}
Future<void> editCardio(BuildContext context, TrainingStore store, Future<void> Function(Future<bool> Function()) perform) async {
  final values = await showDialog<Json>(context: context, builder: (_) => ValuesEditor(title: '运动数据', initial: store.draft!['activity'] as Json, cardio: true));
  if (values != null) { await perform(() => store.updateCardio(values)); }
}
class ValuesEditor extends StatefulWidget {
  const ValuesEditor({super.key, required this.title, required this.initial, this.exercise, this.cardio = false, this.plan = false});
  final String title; final Json initial; final Json? exercise; final bool cardio, plan;
  @override State<ValuesEditor> createState() => _ValuesEditorState();
}
class _ValuesEditorState extends State<ValuesEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String kind = widget.initial['kind'] as String? ?? 'working';
  String? error;
  @override void initState() {
    super.initState();
    for (final key in ['weightKg', 'reps', 'durationSeconds', 'restSeconds', 'rpe', 'rir', 'setCount', 'distanceMeters', 'activeEnergyKcal']) {
      final value = widget.initial[key];
      fields[key] = TextEditingController(text: value == null ? (key == 'setCount' ? '3' : key == 'restSeconds' ? '90' : '') : key == 'distanceMeters' ? (number(value) / 1000).toString() : '$value');
    }
  }
  @override void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  Widget field(String key, String label, double min, double max, {bool integer = false, bool required = false}) => Padding(padding: const EdgeInsets.only(bottom: 14), child: TextFormField(controller: fields[key], keyboardType: TextInputType.numberWithOptions(decimal: !integer), decoration: InputDecoration(labelText: label), validator: (text) {
    if (text == null || text.trim().isEmpty) { return required ? '请填写此项' : null; }
    final value = num.tryParse(text.trim());
    if (value == null || !value.isFinite || value < min || value > max || integer && value != value.roundToDouble()) { return '请输入 $min–$max ${integer ? '之间的整数' : '之间的数值'}'; }
    return null;
  }));
  void save() {
    if (!form.currentState!.validate()) { return; }
    final values = <String, dynamic>{};
    for (final e in fields.entries) {
      final text = e.value.text.trim();
      values[e.key] = text.isEmpty ? null : ['reps', 'durationSeconds', 'restSeconds', 'setCount'].contains(e.key) ? num.parse(text).toInt() : num.parse(text).toDouble();
    }
    if (values['distanceMeters'] != null) { values['distanceMeters'] = number(values['distanceMeters']) * 1000; }
    values['kind'] = kind; values['notes'] = widget.initial['notes'] ?? '';
    try {
      if (!widget.cardio) { validateSet({...freshSet(), ...values}, widget.exercise!); }
      Navigator.pop(context, values);
    } catch (e) { setState(() => error = e.toString()); }
  }
  @override Widget build(BuildContext context) {
    final tracking = widget.exercise?['tracking'];
    return AlertDialog(title: Text(widget.title), content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.cardio) ...[if (distanceActivities.contains(widget.initial['kind'])) field('distanceMeters', '距离（km，可留空）', 0, 2000), const Text('距离留空表示未知。不支持距离的运动只记录时长；本版不测量或估算活动能量。')]
      else ...[
        Text(loadingLabel(widget.exercise!)), const SizedBox(height: 16),
        if (widget.plan) field('setCount', '目标组数', 1, 30, integer: true, required: true),
        if (tracking == 'weightReps' || tracking == 'assistedReps') field('weightKg', '${tracking == 'assistedReps' ? '辅助重量' : '重量'}（kg）', 0, 1500),
        if (tracking == 'duration') field('durationSeconds', '持续时间（秒，可在计时后填写）', 1, 86400, integer: true)
        else field('reps', '次数', kind == 'failed' ? 0 : 1, 1000, integer: true),
        field('restSeconds', '组间休息（秒，0 为不休息）', 0, 3600, integer: true, required: true),
        if (!widget.plan) ...[
          DropdownButtonFormField<String>(initialValue: kind, decoration: const InputDecoration(labelText: '组类型'), items: const [DropdownMenuItem(value: 'working', child: Text('正式组')), DropdownMenuItem(value: 'warmup', child: Text('热身组')), DropdownMenuItem(value: 'drop', child: Text('递减组')), DropdownMenuItem(value: 'failed', child: Text('失败组'))], onChanged: (value) => setState(() => kind = value!)),
          const SizedBox(height: 14), field('rpe', 'RPE（1–10，选填）', 1, 10), field('rir', 'RIR（0–10，选填）', 0, 10),
        ],
      ],
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ])))) , actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: save, child: const Text('保存'))]);
  }
}

Future<void> editPlan(BuildContext context, TrainingStore store, Json labels, {Json? plan, DateTime? day}) => showDialog<void>(context: context, barrierDismissible: false, builder: (_) => PlanEditor(store: store, labels: labels, plan: plan, day: day));
class PlanEditor extends StatefulWidget {
  const PlanEditor({super.key, required this.store, required this.labels, this.plan, this.day});
  final TrainingStore store; final Json labels; final Json? plan; final DateTime? day;
  @override State<PlanEditor> createState() => _PlanEditorState();
}
class _PlanEditorState extends State<PlanEditor> {
  late final name = TextEditingController(text: widget.plan?['name'] as String? ?? '我的训练计划');
  late DateTime scheduled = widget.plan == null ? widget.day ?? DateTime.now() : date(widget.plan!['scheduledAt']).toLocal();
  late final items = widget.plan == null ? <Json>[] : objects(copy(widget.plan!)['items']);
  bool saving = false; String? error;
  @override void dispose() { name.dispose(); super.dispose(); }
  Json exercise(Json item) => widget.store.catalog.firstWhere((e) => e['id'].toString().toLowerCase() == item['exerciseID'].toString().toLowerCase());
  Future<void> save() async {
    setState(() { saving = true; error = null; });
    final plan = <String, dynamic>{if (widget.plan != null) ...copy(widget.plan!), 'id': widget.plan?['id'] ?? newID(), 'name': name.text.trim(), 'scheduledAt': stamp(scheduled), 'items': items, 'notes': widget.plan?['notes'] ?? '', 'isSkipped': widget.plan?['isSkipped'] ?? false};
    final ok = await widget.store.savePlan(plan);
    if (!mounted) { return; }
    if (ok) { Navigator.pop(context); } else { setState(() { saving = false; error = widget.store.error; }); }
  }
  @override Widget build(BuildContext context) => PopScope(canPop: !saving, child: AlertDialog(title: Text(widget.plan == null ? '安排训练' : '编辑计划'), content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: name, maxLength: 100, decoration: const InputDecoration(labelText: '计划名称')),
    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_month), title: Text(dayLabel(scheduled)), trailing: const Icon(Icons.edit_calendar_outlined), onTap: saving ? null : () async {
      final value = await showDatePicker(context: context, initialDate: scheduled, firstDate: DateTime(1900), lastDate: DateTime(2200, 12, 31));
      if (value != null) { setState(() => scheduled = value); }
    }),
    for (final (index, item) in items.indexed) Card(child: ListTile(title: Text(exercise(item)['name'] as String), subtitle: Text('${item['setCount']} 组 · ${setLabel(item, exercise(item))}'), trailing: IconButton(tooltip: '移除动作', onPressed: saving ? null : () => setState(() => items.removeAt(index)), icon: const Icon(Icons.remove_circle_outline)), onTap: saving ? null : () async {
      final result = await showDialog<Json>(context: context, builder: (_) => ValuesEditor(title: '动作目标', initial: item, exercise: exercise(item), plan: true));
      if (result != null) { setState(() { for (final k in ['setCount', 'weightKg', 'reps', 'durationSeconds', 'restSeconds']) { if (result[k] != null) { item[k] = result[k]; } else { item.remove(k); } } }); }
    })),
    const SizedBox(height: 12), OutlinedButton.icon(onPressed: saving || items.length >= 100 ? null : () async { final e = await pickExercise(context, widget.store, widget.labels); if (e != null) { setState(() => items.add({'id': newID(), 'exerciseID': e['id'], 'setCount': 3, 'restSeconds': widget.store.settings['restSeconds']})); } }, icon: const Icon(Icons.add), label: const Text('添加动作')),
    const SizedBox(height: 14), const Text('点按动作可设置目标。计划只安排内容，不会自动开始或发送提醒。'),
    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  ]))), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: saving ? null : save, child: Text(saving ? '保存中…' : '保存计划'))]));
}
