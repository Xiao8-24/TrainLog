import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/model.dart';
import 'package:trainlog/sync_client.dart';

void main() {
  test('sync client validates backups and preserves a newer remote revision', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final catalog = jsonDecode(await File('assets/catalog.json').readAsString()) as Json;
    final backup = initialBackup(objects(catalog['exercises']), DateTime.now());
    Json? remote;
    var revision = 0;
    final service = server.listen((request) async {
      final authorized = request.headers.value(HttpHeaders.authorizationHeader) == 'Bearer test-token';
      if (!authorized) { request.response.statusCode = 401; await request.response.close(); return; }
      if (request.method == 'GET') {
        request.response.write(jsonEncode({'revision': revision, 'backup': remote}));
      } else {
        final expected = int.parse(request.headers.value('If-Match')!);
        if (expected != revision) {
          request.response.statusCode = 409;
          request.response.write(jsonEncode({'conflict': true, 'revision': revision}));
        } else {
          remote = jsonDecode(await utf8.decoder.bind(request).join()) as Json;
          revision += 1;
          request.response.write(jsonEncode({'conflict': false, 'revision': revision}));
        }
      }
      await request.response.close();
    });
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}'), 'test-token');
    try {
      expect((await client.pull()).revision, 0);
      expect(await client.push(backup, expectedRevision: 0), 1);
      await expectLater(client.push(backup, expectedRevision: 0), throwsA(isA<SyncConflict>()));
      expect((await client.pull()).revision, 1);
      expect((await client.pull()).backup!['schemaVersion'], 5);
      expect(revision, 1);
    } finally {
      client.close(); await service.cancel(); await server.close(force: true);
    }
  });
  test('sync client rejects plain HTTP outside loopback', () {
    expect(() => SyncClient(Uri.parse('http://example.com'), 'test-token'), throwsArgumentError);
  });
}
