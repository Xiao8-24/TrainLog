part of 'main.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.store, required this.labels, this.onPick});
  final TrainingStore store; final Json labels; final ValueChanged<Json>? onPick;
  @override State<CatalogPage> createState() => _CatalogPageState();
}
class _CatalogPageState extends State<CatalogPage> {
  String search = '', muscle = 'all';
  @override Widget build(BuildContext context) {
    final matches = widget.store.catalog.where((e) => e['isArchived'] != true && (muscle == 'all' || (e['primary'] as List).contains(muscle) || (e['secondary'] as List).contains(muscle)) && '${e['name']} ${e['englishName']}'.toLowerCase().contains(search.toLowerCase().trim())).toList();
    return Column(children: [Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(decoration: const InputDecoration(labelText: '搜索动作', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => search = value)), const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: muscle, decoration: const InputDecoration(labelText: '肌群'), items: [const DropdownMenuItem(value: 'all', child: Text('全部肌群')), ...(widget.labels['muscles'] as Json).entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value as String)))], onChanged: (value) => setState(() => muscle = value!))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerLeft, child: Text('${matches.length} 个动作${widget.onPick != null ? ' · 点按添加' : ''}'))),
      Expanded(child: matches.isEmpty ? const EmptyState(Icons.search_off, '没有找到动作', '试试其他名称或肌群。') : ListView.builder(padding: const EdgeInsets.all(12), itemCount: matches.length, itemBuilder: (context, index) {
        final e = matches[index];
        return ListTile(minVerticalPadding: 12, leading: const Icon(Icons.fitness_center), title: Text(e['name'] as String), subtitle: Text('${e['englishName']}\n${(e['primary'] as List).map((m) => widget.labels['muscles'][m] ?? m).join('、')} · ${loadingLabel(e)}'), isThreeLine: true, trailing: widget.onPick != null ? const Icon(Icons.add) : null, onTap: widget.onPick == null ? () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(e['name'] as String), content: Text('${e['englishName']}\n\n${loadingLabel(e)}\n\n主要肌群：${(e['primary'] as List).map((m) => widget.labels['muscles'][m] ?? m).join('、')}\n辅助肌群：${(e['secondary'] as List).map((m) => widget.labels['muscles'][m] ?? m).join('、')}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('完成'))])) : () => widget.onPick!(e));
      })),
    ]);
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.store, required this.labels, required this.onStart, required this.perform});
  final TrainingStore store; final Json labels; final ValueChanged<Json> onStart;
  final Future<void> Function(Future<bool> Function()) perform;
  @override State<CalendarPage> createState() => _CalendarPageState();
}
class _CalendarPageState extends State<CalendarPage> {
  late DateTime selected = widget.store.now();
  late DateTime month = DateTime(selected.year, selected.month);
  void shift(int amount) {
    final next = DateTime(month.year, month.month + amount);
    if (next.year >= 1900 && next.year <= 2200) { setState(() => month = next); }
  }
  @override Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday - 1;
    final history = widget.store.history.where((s) => sameDay(date(s['date']).toLocal(), selected)).toList();
    final plans = widget.store.plans.where((p) => sameDay(date(p['scheduledAt']).toLocal(), selected)).toList();
    return PageBody(children: [
      Row(children: [IconButton(tooltip: '上个月', onPressed: month.year == 1900 && month.month == 1 ? null : () => shift(-1), icon: const Icon(Icons.chevron_left)), Expanded(child: TextButton(onPressed: () async {
        final d = await showDatePicker(context: context, initialDate: selected, firstDate: DateTime(1900), lastDate: DateTime(2200, 12, 31));
        if (d != null) { setState(() { selected = d; month = DateTime(d.year, d.month); }); }
      }, child: Text('${month.year} 年 ${month.month} 月', style: Theme.of(context).textTheme.titleLarge))), IconButton(tooltip: '下个月', onPressed: month.year == 2200 && month.month == 12 ? null : () => shift(1), icon: const Icon(Icons.chevron_right))]),
      Row(children: ['一', '二', '三', '四', '五', '六', '日'].map((v) => Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(10), child: Text(v))))).toList()),
      LayoutBuilder(builder: (context, box) => Wrap(children: List.generate(((days + offset + 6) ~/ 7) * 7, (i) {
        final n = i - offset + 1;
        if (n < 1 || n > days) { return SizedBox(width: box.maxWidth / 7, height: 60); }
        final day = DateTime(month.year, month.month, n);
        final hasHistory = widget.store.history.any((s) => sameDay(date(s['date']).toLocal(), day));
        final hasPlan = widget.store.plans.any((p) => p['isSkipped'] != true && sameDay(date(p['scheduledAt']).toLocal(), day));
        final isSelected = sameDay(day, selected);
        return SizedBox(
          width: box.maxWidth / 7, height: 60,
          child: Semantics(
            label: '${dayLabel(day)}${hasHistory ? '，有训练' : ''}${hasPlan ? '，有计划' : ''}', selected: isSelected,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12), onTap: () => setState(() => selected = day),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$n', style: TextStyle(fontWeight: sameDay(day, widget.store.now()) ? FontWeight.bold : FontWeight.normal)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (hasHistory) Icon(Icons.circle, size: 6, color: Theme.of(context).colorScheme.primary),
                      if (hasPlan) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.circle_outlined, size: 7)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        );
      }))),
      const SizedBox(height: 10), Row(children: [const Expanded(child: Text('● 已训练   ◯ 有计划')), TextButton(onPressed: () => setState(() { selected = widget.store.now(); month = DateTime(selected.year, selected.month); }), child: const Text('今天'))]),
      const Divider(), const SizedBox(height: 12),
      Section(dayLabel(selected), child: Column(children: [
        for (final p in plans) Card(child: ListTile(title: Text(p['name'] as String), subtitle: Text('${(p['items'] as List).length} 个动作${widget.store.history.any((s) => s['plan']?['id'] == p['id']) ? ' · 已有完成记录' : ''}'), onTap: () => editPlan(context, widget.store, widget.labels, plan: p), trailing: PopupMenuButton<String>(onSelected: (value) async {
          if (value == 'start') { widget.onStart(p); }
          if (value == 'edit' && context.mounted) { await editPlan(context, widget.store, widget.labels, plan: p); }
          if (value == 'delete' && context.mounted && await confirm(context, '删除这项计划？', '历史训练中的计划快照仍会保留。', '删除计划')) { await widget.perform(() => widget.store.deletePlan(p['id'] as String)); }
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'start', child: Text('按计划训练')), PopupMenuItem(value: 'edit', child: Text('编辑计划')), PopupMenuItem(value: 'delete', child: Text('删除计划'))]))),
        for (final s in history) SessionTile(session: s, labels: widget.labels, store: widget.store, perform: widget.perform),
        if (plans.isEmpty && history.isEmpty) const EmptyState(Icons.event_note_outlined, '这一天没有记录', '任何时候都可以查看日历或提前安排训练。'),
        OutlinedButton.icon(onPressed: widget.store.busy ? null : () => editPlan(context, widget.store, widget.labels, day: selected), icon: const Icon(Icons.add), label: const Text('安排这一天的训练')),
      ])),
    ]);
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, required this.labels, required this.store, required this.perform});
  final Json session, labels; final TrainingStore store; final Future<void> Function(Future<bool> Function()) perform;
  @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(session['mode'] == 'cardio' ? Icons.directions_run : Icons.fitness_center), title: Text(titleFor(session, labels)), subtitle: Text('${dayLabel(date(session['date']).toLocal())} · ${clock(elapsed(session, store.now()))}${session['mode'] == 'detailed' ? ' · ${sets(session).where((s) => s['isCompleted'] == true).length} 组' : ''}'), trailing: const Icon(Icons.chevron_right), onTap: () => showDialog<void>(context: context, builder: (_) => SessionDetail(session: session, store: store, labels: labels, perform: perform))));
}
class SessionDetail extends StatelessWidget {
  const SessionDetail({super.key, required this.session, required this.labels, required this.store, required this.perform});
  final Json session, labels; final TrainingStore store; final Future<void> Function(Future<bool> Function()) perform;
  @override Widget build(BuildContext context) {
    final targets = session['plan']?['targets'] as List?;
    final volume = workoutVolumeKg(session);
    return AlertDialog(title: Text(titleFor(session, labels)), content: SizedBox(width: 680, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${dayLabel(date(session['date']).toLocal())} · ${clock(elapsed(session, store.now()))}'), const SizedBox(height: 12),
      if (session['mode'] == 'detailed') Text('正式组 ${workingSets(session).length} 组 · 外部负重容量 ${volume == null ? '未知' : '${volume.toStringAsFixed(1)} kg'}'),
      if (session['plan'] != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(targets == null ? '这份历史记录没有保存计划快照，不从现有计划重建目标。' : '计划与实际 · 目标取自开练时保存的快照。', style: Theme.of(context).textTheme.titleMedium)),
      for (final e in (session['exercises'] as List).cast<Json>()) ...[
        const Divider(), Text(e['exercise']['name'] as String, style: Theme.of(context).textTheme.titleMedium),
        if (targets != null) Builder(builder: (_) {
          final match = targets.cast<Json>().where((t) => t['id'] == e['id']).toList();
          return Text(match.isEmpty ? '计划外添加动作' : '原计划 ${match.first['sets'].length} 组：${(match.first['sets'] as List).cast<Json>().map((s) => setLabel(s, e['exercise'] as Json)).join(' / ')}');
        }),
        for (final (i, s) in (e['sets'] as List).cast<Json>().indexed) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${i + 1}. ${setLabel(s, e['exercise'] as Json)} · ${s['isCompleted'] == true ? '完成' : '未完成'}${s['timing'] == null ? '' : ' · ${clock(elapsed(s['timing'] as Json, store.now()))}'}${s['rpe'] == null ? '' : ' · RPE ${s['rpe']}'}${s['rir'] == null ? '' : ' · RIR ${s['rir']}'}')),
      ],
      if (session['mode'] == 'cardio') ...[Text('距离 ${session['activity']?['distanceMeters'] == null ? '未知' : '${number(session['activity']['distanceMeters']) / 1000} km'}'), const SizedBox(height: 8), Text('活动能量 ${session['activity']?['activeEnergyKcal'] ?? '未知'} kcal'), const SizedBox(height: 8), Text('数据来源：${session['activity']?['source'] == 'appleWatch' ? '导入的 Apple Watch 记录' : '手动记录'}'), if (session['activity']?['averageHeartRate'] != null) Text('平均心率 ${session['activity']['averageHeartRate']} bpm（导入值）')],
      if ((session['notes'] as String).isNotEmpty) ...[const SizedBox(height: 16), Text(session['notes'] as String)],
    ]))), actions: [TextButton(onPressed: store.busy ? null : () async {
      if (await confirm(context, '删除这次训练？', '删除后可通过之前导出的备份恢复。', '删除训练')) { await perform(() => store.deleteSession(session['id'] as String)); if (context.mounted) { Navigator.pop(context); } }
    }, child: const Text('删除记录')), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成'))]);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store, required this.perform});
  final TrainingStore store; final Future<void> Function(Future<bool> Function()) perform;
  Future<void> export(BuildContext context) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(store.exportBackup())));
      require(bytes.length <= 32 * 1024 * 1024, '备份超过 32 MB，未导出');
      final name = 'TrainLog-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      bool saved = false;
      if (Platform.isAndroid) { saved = await const MethodChannel('app.trainlog/documents').invokeMethod<bool>('saveBackup', {'name': name, 'bytes': bytes}) ?? false; }
      else { final location = await getSaveLocation(suggestedName: name, acceptedTypeGroups: const [XTypeGroup(label: 'TrainLog JSON', extensions: ['json'])]); if (location != null) { await XFile.fromData(bytes, name: name).saveTo(location.path); saved = true; } }
      if (context.mounted && saved) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份已导出，可在 TrainLog iOS 或本客户端导入。'))); }
    } catch (e) { if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('未能导出：$e'))); } }
  }
  Future<void> importFile(BuildContext context) async {
    try {
      if (store.draft != null) { throw const FormatException('请先结束或舍弃当前训练再导入。'); }
      final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'TrainLog JSON', extensions: ['json'], mimeTypes: ['application/json'])]);
      if (file == null) { return; }
      require(await file.length() <= 32 * 1024 * 1024, '文件超过 32 MB');
      final data = decodeBackup(await file.readAsString());
      if (!context.mounted) { return; }
      if (await confirm(context, '替换当前训练资料？', '备份包含 ${(data['sessions'] as List).length} 次训练、${(data['plans'] as List? ?? []).length} 项计划。当前资料会被替换，请先导出备份。此操作不会自动同步其他设备。', '替换并导入')) { await perform(() => store.importBackup(data)); }
    } catch (e) { if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('未导入，当前资料保留：$e'))); } }
  }
  @override Widget build(BuildContext context) => PageBody(children: [
    Section('显示与训练', child: Column(children: [DropdownButtonFormField<String>(initialValue: store.settings['theme'] as String, decoration: const InputDecoration(labelText: '外观'), items: const [DropdownMenuItem(value: 'system', child: Text('跟随系统')), DropdownMenuItem(value: 'light', child: Text('浅色')), DropdownMenuItem(value: 'dark', child: Text('深色'))], onChanged: store.busy ? null : (value) => perform(() => store.change((next) => next['settings']['theme'] = value))), const SizedBox(height: 16), DropdownButtonFormField<int>(initialValue: store.settings['weeklyGoal'] as int, decoration: const InputDecoration(labelText: '每周训练目标'), items: List.generate(14, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} 次'))), onChanged: store.busy ? null : (value) => perform(() => store.change((next) => next['settings']['weeklyGoal'] = value))), const SizedBox(height: 16), ListTile(contentPadding: EdgeInsets.zero, title: const Text('默认组间休息'), subtitle: Text('${store.settings['restSeconds']} 秒'), trailing: const Icon(Icons.edit_outlined), onTap: store.busy ? null : () async { final result = await editText(context, '默认休息秒数（0–3600）', '${store.settings['restSeconds']}'); if (result == null) { return; } final value = int.tryParse(result.trim()); if (value != null) { await perform(() => store.change((next) => next['settings']['restSeconds'] = value)); } else if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入 0–3600 的整数'))); } })])),
    Section('本地记录与备份', subtitle: '训练资料保存在本机应用数据目录。移动 Windows 程序不会迁移数据；卸载前请导出。跨设备通过 JSON 手动转移。', child: Wrap(spacing: 12, runSpacing: 12, children: [FilledButton.icon(onPressed: store.busy ? null : () => export(context), icon: const Icon(Icons.file_upload_outlined), label: const Text('导出完整备份')), OutlinedButton.icon(onPressed: store.busy ? null : () => importFile(context), icon: const Icon(Icons.file_download_outlined), label: const Text('导入并替换'))])),
    const Section('关于此版本', subtitle: 'TrainLog 0.10.0 · Android / Windows 预览版', child: Text('支持实时逐组记录、整体与逐组计时、日期计划、健身日历、历史复盘和本地恢复。重量在本版以 kg 编辑，导入的重量单位偏好会保留。\n\niOS 继续使用原生 SwiftUI、HealthKit 和 Watch 连接。Android / Windows 暂无手表连接、系统小组件、云端同步或下次目标建议；导入的原始资料保留在备份中。系统关闭动画时会减少页面过渡。')),
  ]);
}

