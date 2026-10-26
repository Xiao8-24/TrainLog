import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trainlog/main.dart';
import 'package:trainlog/model.dart';
import 'package:trainlog/store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native host records a set and reopens its SQLite data', (tester) async {
    final labels = jsonDecode(await rootBundle.loadString('assets/catalog.json')) as Json;
    final dir = await Directory.systemTemp.createTemp('trainlog-native-smoke-');
    var store = await TrainingStore.open('${dir.path}/training.db', objects(labels['exercises']));
    final boundaryKey = GlobalKey();
    Future<void> mount() async {
      await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: TrainLogApp(store: store, labels: labels)));
      await tester.pumpAndSettle();
    }
    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      while (store.busy) { await Future<void>.delayed(const Duration(milliseconds: 20)); }
      await tester.pumpAndSettle();
    }
    Future<void> capture(String name) async {
      if (!Platform.isWindows) { return; }
      const target = String.fromEnvironment('TRAINLOG_ARTIFACT_DIR');
      if (target.isEmpty) { return; }
      await Directory(target).create(recursive: true);
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$target/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }
    try {
      await mount();
      expect(store.sessions, isEmpty);
      await capture('windows-dashboard-test-data');
      await tap(find.text('力量训练'));
      await tap(find.text('添加动作'));
      await tap(find.text('杠铃卧推').first);
      await tap(find.byTooltip('编辑第 1 组'));
      await tester.enterText(find.byType(TextFormField).at(0), '40');
      await tester.enterText(find.byType(TextFormField).at(1), '8');
      await tap(find.text('保存'));
      await tap(find.text('开始本组'));
      await Future<void>.delayed(const Duration(seconds: 1));
      await tap(find.text('完成本组'));
      expect(sets(store.draft!).single['isCompleted'], true);
      await capture('windows-active-workout-test-data');
      await tap(find.byTooltip('返回，训练继续计时'));
      await tap(find.text('日历'));
      expect(find.text('安排这一天的训练'), findsOneWidget);
      await capture('windows-calendar-test-data');
      await tester.pumpWidget(const SizedBox());
      await store.close();
      store = await TrainingStore.open('${dir.path}/training.db', objects(labels['exercises']));
      expect(sets(store.draft!).single['weightKg'], 40);
      expect(sets(store.draft!).single['isCompleted'], true);
      await store.finish();
      expect(store.history.length, 1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      if (!store.closed) { await store.close(); }
      await dir.delete(recursive: true);
    }
  });
}
