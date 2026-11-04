import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'model.dart';

class SyncConflict implements Exception {
  const SyncConflict(this.remoteRevision);
  final int remoteRevision;
  @override String toString() => '云端已有较新的记录（版本 $remoteRevision）；本机资料未被覆盖。';
}

class RemoteSnapshot {
  const RemoteSnapshot(this.revision, this.backup);
  final int revision;
  final Json? backup;
}

/// Transport only. Account authorization and consent must be configured before use.
/// The caller owns the token and must keep it in platform secure storage.
class SyncClient {
  SyncClient(this.baseURL, this.token, {HttpClient? client}) : _client = client ?? HttpClient() {
    if (baseURL.scheme != 'https' && !(baseURL.scheme == 'http' && (baseURL.host == '127.0.0.1' || baseURL.host == 'localhost'))) {
      throw ArgumentError.value(baseURL, 'baseURL', '公开服务必须使用 HTTPS');
    }
    if (token.isEmpty) throw ArgumentError.value(token, 'token', '需要账户令牌');
  }
  final Uri baseURL;
  final String token;
  final HttpClient _client;

  Future<(int, Json)> _call(String method, String path, {Json? body, int? revision}) async {
    final request = await _client.openUrl(method, baseURL.resolve(path)).timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (revision != null) request.headers.set('If-Match', '$revision');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close().timeout(const Duration(seconds: 30));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      bytes.addAll(chunk);
      if (bytes.length > 32 * 1024 * 1024) throw const FormatException('云端响应超过 32 MB');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('云端响应格式无效');
    return (response.statusCode, decoded);
  }
  Future<RemoteSnapshot> pull() async {
    final (status, response) = await _call('GET', '/v1/snapshot');
    if (status != 200) throw HttpException('云端读取失败：$status');
    final revision = response['revision'];
    if (revision is! int || revision < 0) throw const FormatException('云端版本无效');
    final backup = response['backup'];
    if (backup != null) {
      if (backup is! Map<String, dynamic>) throw const FormatException('云端备份无效');
      validateBackup(backup);
    }
    return RemoteSnapshot(revision, backup);
  }
  Future<int> push(Json backup, {required int expectedRevision, bool includeHealthDetails = false}) async {
    if (expectedRevision < 0) throw ArgumentError.value(expectedRevision, 'expectedRevision');
    validateBackup(backup);
    if (!includeHealthDetails && _hasSensitiveHealthData(backup)) {
      throw StateError('备份含体重或 Apple Watch 测量值；上传前需要用户明确选择同步这些健康资料。');
    }
    final (status, response) = await _call('PUT', '/v1/snapshot', body: backup, revision: expectedRevision);
    if (status == 409) throw SyncConflict(response['revision'] is int ? response['revision'] as int : -1);
    if (status != 200 || response['revision'] is! int) throw HttpException('云端保存失败：$status');
    return response['revision'] as int;
  }
  void close() => _client.close();
}

bool _hasSensitiveHealthData(Json backup) {
  if ((backup['bodyWeights'] as List).isNotEmpty) return true;
  for (final session in (backup['sessions'] as List).cast<Json>()) {
    if (session['watchLink'] != null || session['phoneLink'] != null) return true;
    final activity = session['activity'] as Json?;
    if (activity != null && (activity['source'] == 'appleWatch' || activity['heartRate'] is List && (activity['heartRate'] as List).isNotEmpty ||
        activity['averageHeartRate'] != null || activity['maximumHeartRate'] != null || activity['activeEnergyKcal'] != null)) return true;
  }
  return false;
}
