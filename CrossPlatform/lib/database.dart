import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import 'model.dart';

/// A single SQLite connection lives off the UI isolate. COMMIT must succeed
/// before a mutation is acknowledged. FULL synchronous + WAL handles relaunch.
class RecordDatabase {
  RecordDatabase._(this._isolate, this._port);
  final Isolate _isolate;
  final SendPort _port;
  static Future<RecordDatabase> open(String path) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_databaseWorker, ready.sendPort);
    final port = await ready.first as SendPort;
    ready.close();
    final db = RecordDatabase._(isolate, port);
    try { await db._request('open', path); return db; }
    catch (_) { await db.close(); rethrow; }
  }
  Future<dynamic> _request(String method, dynamic value) async {
    final reply = ReceivePort();
    _port.send([reply.sendPort, method, value]);
    try {
      final result = await reply.first as Json;
      if (result['ok'] != true) { throw StateError(result['error'] as String); }
      return result['value'];
    } finally { reply.close(); }
  }
  Future<Json?> read() async => await _request('read', null) as Json?;
  Future<void> write(Json envelope) async { await _request('write', envelope); }
  Future<void> close() async {
    try { await _request('close', null); }
    finally { _isolate.kill(priority: Isolate.immediate); }
  }
}

void _databaseWorker(SendPort ready) {
  final messages = ReceivePort();
  ready.send(messages.sendPort);
  Database? db;
  messages.listen((dynamic message) {
    final reply = message[0] as SendPort;
    try {
      dynamic value;
      switch (message[1]) {
        case 'open':
          db = sqlite3.open(message[2] as String);
          final version = db!.select('PRAGMA user_version').single.values.single as int;
          require(version == 0 || version == 1, '此数据库来自更新版本，未修改原文件');
          require(db!.select('PRAGMA quick_check').single.values.single == 'ok', '数据库完整性校验失败');
          db!.execute('PRAGMA busy_timeout = 3000');
          db!.execute('PRAGMA journal_mode = WAL');
          db!.execute('PRAGMA synchronous = FULL');
          db!.execute('CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL) STRICT');
          db!.execute('PRAGMA user_version = 1');
        case 'read':
          final rows = db!.select('SELECT payload FROM state WHERE id = 1');
          value = rows.isEmpty ? null : jsonDecode(rows.single['payload'] as String);
        case 'write':
          final text = jsonEncode(message[2]);
          db!.execute('BEGIN IMMEDIATE');
          try {
            db!.execute('INSERT INTO state(id, payload) VALUES(1, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload', [text]);
            db!.execute('COMMIT');
          } catch (_) { db!.execute('ROLLBACK'); rethrow; }
        case 'close':
          db?.close(); db = null; messages.close();
        default: throw StateError('Unknown database operation');
      }
      reply.send({'ok': true, 'value': value});
    } catch (e) { reply.send({'ok': false, 'error': e.toString()}); }
  });
}
