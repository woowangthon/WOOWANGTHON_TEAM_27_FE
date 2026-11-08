# LifeRadar FE — 개발자 가이드

Flutter 앱(Android · Web)의 실행, 키 설정, 구조, 데이터 흐름, 테스트, 함정을 정리합니다.
판단 엔진과 AI는 [AI 저장소](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_AI), 데이터 수집은 [BE 저장소](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_BE)에 있습니다.

## 1. 빠른 시작

**필요 환경**: Flutter 3.41 (Dart 3.11), Chrome(웹), Android 실기기(ARM — Kakao 네이티브 지도는 x86 에뮬레이터 미지원).

```bash
git clone https://github.com/woowangthon/WOOWANGTHON_TEAM_27_FE.git
cd WOOWANGTHON_TEAM_27_FE
cp env.example.json env.json          # 키 입력 (2장)
flutter pub get                       # liferadar_core(AI 저장소)를 git으로 받는다
dart run tool/gen_web_env.dart        # 웹용 Kakao JS SDK 설정 생성

# 웹 (Kakao JS 도메인에 http://localhost:8080 등록 필요)
flutter run -d chrome --web-port=8080 --dart-define-from-file=env.json \
  --web-browser-flag="--user-data-dir=$PWD/.dart_tool/chrome-profile"   # 로그인·관심사 유지

# Android APK
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 2. API 키와 외부 서비스

모든 키는 `env.json`에 넣고 `--dart-define-from-file=env.json`으로 전달합니다. **`env.json`과 `web/kakao_config.js`는 커밋하지 않습니다** (`.gitignore`).

| 키 | 용도 | 발급처 | 필수 설정 |
|---|---|---|---|
| `KAKAO_JS_KEY` | 웹 지도 | [Kakao Developers](https://developers.kakao.com) → 앱 → JavaScript 키 | JavaScript SDK 도메인 `http://localhost:8080`, 카카오맵 사용 ON |
| `KAKAO_NATIVE_APP_KEY` | Android 지도 | 같은 앱 → 네이티브 앱 키 | Android 패키지 `com.liferadar.liferadar` + 키 해시 |
| `KAKAO_REST_API_KEY` | 장소 검색, 자동차 경로 | 같은 앱 → REST API 키 | — |
| `GOOGLE_API_KEY` | 대중교통 경로(Routes), 날씨(Weather) | Google Cloud Console | Routes · Weather API 사용 설정 |
| `GOOGLE_OAUTH_WEB_CLIENT_ID` | Google 로그인 → 캘린더 | Google Auth Platform → 웹 클라이언트 | 승인된 JS 원본 `http://localhost:8080`, 테스트 사용자 등록, 범위 `calendar.events` |
| `GEMINI_API_KEY` | 홈 카드 설명 문장 (없으면 규칙 문장) | [Google AI Studio](https://aistudio.google.com/apikey) | `AQ.` 형식 키는 `?key=` 쿼리로 전달 |
| `ITS_API_KEY` | 전국 교통 통제 (국가교통정보센터) — 없으면 서울(TOPIS)만 | [ITS 오픈 API](https://www.its.go.kr/opendata/) | ITS는 해외 IP를 차단하므로 서버가 아닌 앱에서 조회. CORS 허용 |

**Android Google 로그인**: `GOOGLE_OAUTH_WEB_CLIENT_ID`를 `serverClientId`로 사용합니다. 같은 프로젝트에 패키지 `com.liferadar.liferadar` + 서명 인증서 SHA-1로 Android OAuth 클라이언트를 만들어야 합니다 (ID는 env에 넣지 않음).

**Kakao 키 해시 (debug 키스토어)**
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android \
  | openssl sha1 -binary | openssl base64
```

**데이터 주소** (키 불필요, 기본값): `EVENTS_URL`, `TRAFFIC_URL` — BE 저장소의 `data` 브랜치. `--dart-define=EVENTS_URL=`(빈 값)이면 앱에 포함된 데이터만 사용합니다.

## 3. 구조

```
lib/
├── main.dart                 # 시작: 알림 초기화, 캐시된 행사 로드, ProviderScope
├── core/                     # 테마·공용 위젯·토스트·라우터·오류 메시지·알림(웹/Android)·캘린더 링크
├── data/                     # Riverpod 상태
│   ├── providers.dart        # 행사·일정·인사이트·취향·교통 통제 provider
│   ├── live_events.dart      # events.json: 캐시 → 다운로드 → 검증 → 교체
│   ├── live_news.dart        # news.json (뉴스에서 판독한 파업)
│   ├── live_traffic.dart     # traffic.json(서울 TOPIS) + ITS 직접 조회(전국) → 합쳐서 캐시
│   ├── ai_insights.dart      # Gemini 카드 문장 (상위 6개, 캐시, 실패 시 규칙 문장)
│   ├── calendar_controller.dart  # Google 로그인·캘린더 읽기/쓰기
│   ├── notifications.dart    # 중요 신호 → 시스템 알림 (신호당 1회)
│   └── session.dart, interests.dart, seen.dart, location.dart
├── features/                 # 화면: welcome, auth, onboarding, home, map, route, plans, discover, event, profile, shell
├── services/                 # 외부 API: google_api(Routes·Weather), kakao_api, calendar_api
└── l10n/                     # ko / en (gen_l10n)
assets/data/events.json       # 오프라인용 행사 스냅숏 (BE가 생성)
test/                         # 위젯·상태·API 파싱 테스트
```

모델과 엔진(`InsightEngine`, `RouteMatcher`, `TrafficMatcher`, `Taste`), Gemini 검증(`InsightWriter`), 시연 데이터는 `package:liferadar_core`에서 가져옵니다.

## 4. 데이터 흐름

**행사 데이터**
1. 앱 시작: 앱에 포함된 스냅숏과 마지막으로 받은 캐시 중 최신 것을 즉시 표시 (오프라인 동작)
2. 백그라운드: BE `data` 브랜치의 `events.json` 다운로드 → **더 최신이고 20건 이상일 때만** 교체·캐시
3. 발견 화면 상단에 "실제 공공데이터 · 행사 N개 · 업데이트 시각" 표시

**교통 통제**
`traffic.json`(BE, 서울 TOPIS)과 ITS 전국 돌발상황(앱이 직접 조회 — ITS는 해외 서버를 차단)을 동시에 받아 각각 캐시하고, `TrafficNotice.isRelevantAt`으로 끝난 공지를 거른 뒤 합칩니다. 하나가 실패해도 다른 쪽은 그대로 씁니다.

**뉴스 파업**
BE가 3시간마다 네이버 뉴스를 Gemini로 판독해 게시한 `news.json`을 받아 캐시합니다 (`live_news.dart`). 예고·조건부·진행 중 파업만 엔진에 넘기고, 일정 지역(전국·수도권 포함)과 날짜가 맞으면 `strike:` 참고 카드가 됩니다. 알림·AI 재작성 대상이 아닙니다.

**홈 인사이트**
`plans × events × interests × weather × taste × traffic` → `InsightEngine.build` (규칙) → 상위 6개를 `InsightWriter`로 Gemini에 요청 → 검증 통과 문장만 교체 (`aiModel` 표시) → 피드백 반영 정렬.
교통 통제·혼잡 참고 카드는 AI 대상이 아닙니다 (`InsightWriter.isEligible`).

**취향 학습**
👍/👎/숨기기 → `Taste.from(feedback, events)` → 홈·발견·지도·경로의 점수에 반영.

**경로 기반 발견**
출발·도착·날짜 → 대중교통(Google Routes) 또는 자동차(Kakao Mobility) 경로 → `RouteMatcher.match` (15 km 회랑, 같은 날) → 상위 N개만 우회 거리·시간 계산 (자동차: 경유지 경로, 대중교통: 가장 가까운 역에서 왕복).

**캘린더**
Google 로그인 → `calendar.events` 권한 → 향후 90일 일정 읽기 → 장소 지오코딩(Kakao Local) → 내 일정. 행사 추가·일정 수정·삭제도 같은 API. 토큰은 메모리에만 보관합니다. Android에서 캘린더 링크는 Google 캘린더 앱으로 엽니다 (`core/calendar_link.dart`).

**알림**
2일 이내 마감, 3일 이내 일정의 경고 → 시스템 알림 (Android: `flutter_local_notifications`, 웹: Notification API). 혼잡 참고 카드는 알림을 보내지 않습니다. 앱이 닫혀 있을 때의 서버 푸시는 [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md) 설계 참고.

**계정별 로컬 저장**
관심사·직접 만든 일정·이름·본 카드는 `계정 키:항목` 형태로 기기에 저장해, 다른 계정으로 로그인해도 섞이지 않습니다. 계정 삭제는 모든 로컬 데이터와 Google 권한을 지웁니다.

## 5. 디자인 시스템

모든 화면은 `core/theme.dart`의 토큰과 `core/widgets.dart`의 공용 컴포넌트로 만듭니다. **화면 코드에 hex 색이나 임의 여백을 쓰지 않습니다.**

| 토큰 | 내용 |
|---|---|
| `AppPalette` | `background / surface / text / textMuted / primary / accent / danger / info …` 라이트·다크 (본문 대비 ≥ 4.5:1). `context.palette.primary` |
| `Space` | 4/8dp 리듬: `xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · gutter 20` |
| `Radii` | `sm 8 · md 12 · lg 16 · xl 24` |
| `Motion` | `Motion.of(context, d)` — "동작 줄이기"면 0 |

공용 컴포넌트: `Shimmer`·`SkeletonCard`, `Pill`, `MetaRow`, `EmptyState`, `GlassSurface`(liquid glass), `GlassSegmented`, `DetailSheet`, `MarqueeText`, `QuietTags`, `SmoothSize`. 홈 카드의 **일정 연결 줄**은 신호가 어떤 캘린더 일정과 왜 연결되는지(날짜·제목·거리)를 보여줍니다 — 계산하지 않은 값(추천 시간·이동 시간)은 만들지 않습니다.

## 6. 다국어

`lib/l10n/app_ko.arb`, `app_en.arb` → `flutter gen-l10n`. 행사명의 영어는 BE 단계에서 Gemini가 번역하며 상세 화면에 "Gemini로 번역됨"을 표시합니다.

## 7. 테스트

```bash
flutter analyze
flutter test
flutter test --platform chrome test/google_api_test.dart   # 웹(dart2js) 전용 로직
```

| 테스트 | 내용 |
|---|---|
| `app_test.dart` | 첫 실행 → 로그인(게스트) → 이름 → 관심사 → 홈, 언어 전환, 발견 순서, 홈 필터, 상세 시트 높이, 👍/👎 확인, 계정 삭제, 빈 상태 |
| `plans_test.dart` | 계정별 관심사, 일정 추가·수정·삭제, 캘린더 요청 본문, 월간 보기 |
| `ai_insights_test.dart` | Gemini 문장 적용·캐시 재사용, 오류 시 규칙 문장 유지·예비 모델 시도 |
| `live_events_test.dart` | 최신 피드만 교체, 깨진·작은·오래된 파일 무시, 오프라인 |
| `event_feed_test.dart` | 피드 JSON 왕복 |
| `errors_test.dart` | 오류 분류 (오프라인·혼잡·서비스·경로 없음) — 원본 URL·JSON을 보여주지 않음 |
| `google_api_test.dart`, `calendar_api_test.dart`, `weather_test.dart` | 외부 API 응답 파싱 |

엔진·AI 검증 테스트는 AI 저장소, 수집기 테스트는 BE 저장소에 있습니다. 위젯 테스트는 `disableAnimations: true`로 실행해 "동작 줄이기" 경로도 함께 검증합니다.

## 8. 알려진 함정

| 증상 | 원인 / 해결 |
|---|---|
| 지도에 "SDK를 불러오지 못했습니다" | Kakao JS SDK 도메인에 현재 origin 미등록 (포트 8080 확인) |
| 웹에서 경로가 엉뚱한 곳에 그려짐 | dart2js에서 `~`는 부호 없는 32비트 → `-(x + 1)` 사용 |
| Google 자동차 경로가 안 나옴 | Google은 한국 자동차 길찾기 미지원 → Kakao Mobility |
| 서울→부산 자동차 경로에 대전 행사가 없음 | 정상. 고속도로가 대전에서 약 68 km (KTX는 6 km) |
| 캘린더 연결 시 "확인되지 않은 앱" / `access_denied` | 테스트 모드 — 테스트 사용자로 등록된 계정만 가능 |
| 새로고침 후 캘린더 연결이 풀림 | 토큰을 메모리에만 보관 (의도된 동작) |
| `MissingPluginException` | 플러그인 추가 후 오래된 빌드 캐시 → `flutter clean && flutter pub get` |
| `A circle cannot have a border radius` (디버그만) | `copyWith(borderRadius: null)`은 radius를 지우지 않음 → 새 `BoxDecoration` |
| Gemini `404 no longer available` / `429 quota` | 구형 모델 미지원 / 무료 할당량 초과 → `GeminiClient`가 예비 모델로 전환, 실패 시 규칙 문장 |
| 웹에서 행사 포스터가 안 보임 | 이미지 서버 CORS 없음 → `<img>` 대체 전략 |
| `Route` 이름 충돌 | Flutter `Route` vs Kakao `Route` → `import ... as km` |

## 9. 작업 규칙

- 브랜치에서 작업 → PR → `main` (Conventional Commits, 한국어 설명)
- 키·비밀번호는 커밋하지 않는다. 커밋 전 `git diff --cached` 확인
- 샘플 데이터는 `source: 'sample'`과 화면 배지를 유지한다 (시연에서 실제 데이터처럼 보이지 않게)
- AI는 코드가 고른 사실만 설명한다. 사실을 만들게 하지 않는다
