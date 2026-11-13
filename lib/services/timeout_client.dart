import 'dart:async';

import 'package:http/http.dart' as http;

/// 모든 요청에 시간 제한을 둔다 — 느린 네트워크에서 스피너가 끝없이 돌지 않게.
/// 시간이 지나면 [TimeoutException] → 화면은 "연결이 느려요" 류의 친절한 오류를 보여준다.
class TimeoutClient extends http.BaseClient {
  TimeoutClient(this._inner, {this.timeout = const Duration(seconds: 20)});
  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}
