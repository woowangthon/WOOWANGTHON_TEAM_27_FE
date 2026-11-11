import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';

/// 사용자에게 표시되는 에러 유형. 날것의 `e.toString()`을 화면에 노출하지 말 것:
/// URL, 서버 JSON 응답 및 기술적 명칭이 포함되어 있음.
enum ErrorKind { offline, busy, service, noRoute, generic }

/// 에러를 유형별로 분류함. [error] — 예외(exception) 또는 해당 텍스트(state에 저장된 경우).
ErrorKind classifyError(Object? error) {
  final s = error?.toString() ?? '';
  bool has(String p) => s.contains(p);
  if (_offline.any(has)) return ErrorKind.offline;
  if (has('HTTP 429') || has('RESOURCE_EXHAUSTED') || has('quota')) return ErrorKind.busy;
  if (has('HTTP 401') || has('HTTP 403') || has('missing') || has('not-configured')) return ErrorKind.service;
  if (has('No transit route') || has('No route:')) return ErrorKind.noRoute;
  if (has('HTTP 5')) return ErrorKind.service;
  return ErrorKind.generic;
}

const _offline = [
  'SocketException',
  'ClientException',
  'Failed host lookup',
  'Failed to fetch',
  'XMLHttpRequest',
  'TimeoutException',
  'Connection refused',
  'Connection reset',
  'Connection closed',
  'Network is unreachable',
  'ERR_INTERNET_DISCONNECTED',
  'NETWORK_ERROR',
  'network_error',
];

/// 이해하기 쉽고 지역화된 메시지. 원본 에러는 디버그 로그에 기록됨.
String friendlyError(AppLocalizations l10n, Object? error) {
  if (error != null) debugPrint('error: $error');
  final text = error?.toString() ?? '';
  final mapCode = RegExp(r'^KakaoAuthError\(code: (\d+)').firstMatch(text)?.group(1);
  if (mapCode != null) {
    return switch (mapCode) {
      '401' => l10n.mapAuthRegistrationError,
      '403' => l10n.mapPermissionError,
      '429' => l10n.errBusy,
      '499' => l10n.errOffline,
      _ => '${l10n.errService} (MAP_$mapCode)',
    };
  }
  if (text.contains('GoogleSignInException')) {
    final code = RegExp(r'GoogleSignInExceptionCode\.(\w+)').firstMatch(text)?.group(1);
    if (code == 'clientConfigurationError' || code == 'providerConfigurationError' ||
        RegExp(r'ApiException:\s*10\b|DEVELOPER_ERROR').hasMatch(text)) {
      return l10n.googleRegistrationError;
    }
    if (code == 'canceled' || code == 'interrupted') return l10n.googleSignInCanceled;
    if (code == 'userMismatch') return l10n.googleAccountMismatch;
    return '${l10n.errService} (GOOGLE_${code ?? 'unknown'})';
  }
  return switch (classifyError(error)) {
    ErrorKind.offline => l10n.errOffline,
    ErrorKind.busy => l10n.errBusy,
    ErrorKind.service => l10n.errService,
    ErrorKind.noRoute => l10n.errNoRoute,
    ErrorKind.generic => l10n.errGeneric,
  };
}
