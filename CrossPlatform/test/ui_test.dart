import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/main.dart';
import 'package:trainlog/model.dart';
import 'package:trainlog/store.dart';

void main() {
  late TrainingStore store; late Directory dir; late Json labels;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('trainlog-ui-');
    labels = jsonDecode(await File('assets/catalog.json').readAsString()) as Json;
    store = await TrainingStore.open('${dir.path}/training.db', objects(labels['exercises']));
  });
  tearDown(() async { await store.close(); await dir.delete(recursive: true); });
  Future<void> app(WidgetTester tester, Size size, {bool reduce = false, double scale = 1}) async {
    tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(TrainLogApp(store: store, labels: labels)); await tester.pumpAndSettle();
  }
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      while (store.busy) { await Future<void>.delayed(const Duration(milliseconds: 10)); }
    });
    await tester.pumpAndSettle();
  }
  testWidgets('phone can start, add an exercise and save a valid set', (tester) async {
    await app(tester, const Size(412, 915));
    await tap(tester, find.text('力量训练'));
    expect(find.text('正在训练'), findsOneWidget);
    await tap(tester, find.text('添加动作'));
    await tap(tester, find.text('杠铃卧推').first);
    await tap(tester, find.byTooltip('编辑第 1 组'));
    await tester.enterText(find.byType(TextFormField).at(0), '40');
    await tester.enterText(find.byType(TextFormField).at(1), '8');
    await tap(tester, find.text('保存'));
    await tap(tester, find.text('开始本组'));
    await tap(tester, find.text('完成本组'));
    expect(sets(store.draft!).first['isCompleted'], true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('desktop uses rail; calendar is available without active workout', (tester) async {
    await app(tester, const Size(1280, 900)); expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('日历')); await tester.pumpAndSettle();
    expect(find.text('安排这一天的训练'), findsOneWidget);
    await tester.tap(find.byTooltip('上个月')); await tester.pumpAndSettle();
    expect(find.text('安排这一天的训练'), findsOneWidget); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('narrow screen supports navigation and empty history without demo data', (tester) async {
    await app(tester, const Size(320, 740)); expect(find.byType(NavigationBar), findsOneWidget);
    expect(store.sessions, isEmpty); await tester.tap(find.text('动作')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '不存在的动作'); await tester.pumpAndSettle();
    expect(find.text('没有找到动作'), findsOneWidget); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
