import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:liferadar/core/errors.dart';
import 'package:liferadar/l10n/app_localizations.dart';
import 'package:liferadar/services/calendar_api.dart';
import 'package:liferadar/services/google_api.dart';
import 'package:liferadar/services/kakao_api.dart';

void main() {
  test('오류 유형 분류', () {
    expect(classifyError(http.ClientException('Failed to fetch', Uri.parse('https://x'))), ErrorKind.offline);
    expect(classifyError(TimeoutException('t')), ErrorKind.offline);
    expect(classifyError('SocketException: Failed host lookup'), ErrorKind.offline);
    expect(classifyError(const GoogleApiException('HTTP 429: {"error": "RESOURCE_EXHAUSTED"}')), ErrorKind.busy);
    expect(classifyError(const CalendarApiException('HTTP 403: forbidden')), ErrorKind.service);
    expect(classifyError(const GoogleApiException('GOOGLE_API_KEY missing')), ErrorKind.service);
    expect(classifyError(const GoogleApiException('HTTP 503: unavailable')), ErrorKind.service);
    expect(classifyError(const GoogleApiException('No transit route found')), ErrorKind.noRoute);
    expect(classifyError(const KakaoApiException('No route: 출발지와 도착지가 5m 이내')), ErrorKind.noRoute);
    expect(classifyError(StateError('x')), ErrorKind.generic);
    expect(classifyError(null), ErrorKind.generic);
  });

  test('사용자에게 원본 텍스트(URL, JSON)를 보여주지 않는다', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final msg = friendlyError(l10n, const KakaoApiException('HTTP 401: {"msg":"appkey invalid"}'));
    expect(msg, l10n.errService);
    expect(msg, isNot(contains('{')));
    final ko = lookupAppLocalizations(const Locale('ko'));
    expect(friendlyError(ko, http.ClientException('Failed to fetch')), ko.errOffline);
  });
}
