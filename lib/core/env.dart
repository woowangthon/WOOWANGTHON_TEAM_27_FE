import 'package:flutter/foundation.dart';

/// 키는 `flutter run --dart-define-from-file=env.json`을 통해 전달함.
/// env.json은 git에 포함되지 않음 (env.example.json 참고).
///
/// ⚠️ 지도·경로·날씨·Gemini 키는 데모를 위해 앱 안에 있다. 다음 단계에서 BE의
/// API 프록시로 옮겨 앱에 키가 들어가지 않게 한다.
abstract final class Env {
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  static const kakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY');
  static const kakaoRestApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');
  static const googleApiKey = String.fromEnvironment('GOOGLE_API_KEY');
  static const googleOAuthWebClientId = String.fromEnvironment('GOOGLE_OAUTH_WEB_CLIENT_ID');

  /// 홈 인사이트 텍스트용 (비어 있으면 — 규칙 텍스트만 표시). 데모용으로 클라이언트에 위치.
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// 매일 갱신되는 실제 행사 (BE 저장소의 GitHub Actions → `data` 브랜치).
  /// 비워 두면 — APK 내부 행사만 표시.
  static const eventsUrl = String.fromEnvironment(
    'EVENTS_URL',
    defaultValue: 'https://raw.githubusercontent.com/woowangthon/WOOWANGTHON_TEAM_27_BE/data/events.json',
  );

  /// 뉴스에서 판독한 대중교통 파업 (BE가 3시간마다 Gemini로 판독해 게시).
  static const newsUrl = String.fromEnvironment(
    'NEWS_URL',
    defaultValue: 'https://raw.githubusercontent.com/woowangthon/WOOWANGTHON_TEAM_27_BE/data/news.json',
  );

  /// 국가교통정보센터(ITS) 키 — 전국 돌발상황. ITS는 해외 IP를 차단해 서버(GitHub Actions)가
  /// 수집할 수 없으므로 앱이 한국 내 기기에서 직접 조회한다. 비어 있으면 서울(TOPIS)만.
  static const itsApiKey = String.fromEnvironment('ITS_API_KEY');

  /// 도로 통제 정보 (TOPIS) — GitHub Actions가 3시간마다 업데이트.
  static const trafficUrl = String.fromEnvironment(
    'TRAFFIC_URL',
    defaultValue: 'https://raw.githubusercontent.com/woowangthon/WOOWANGTHON_TEAM_27_BE/data/traffic-v2.json',
  );

  /// 웹에서는 index.html의 JS SDK(kakao_config.js)를 통해, 안드로이드에서는 네이티브 키 사용.
  static bool get hasKakaoMapKey => kIsWeb ? kakaoJsKey.isNotEmpty : kakaoNativeAppKey.isNotEmpty;
}
