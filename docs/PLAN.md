# LifeRadar AI — MVP 계획

> 제출 마감: **2026-11-15 18:00 KST** · 팀: 2명 · 플랫폼: **Flutter (Android · Web)** · UI: **한국어 + 영어**
>
> 이 문서는 11/5에 쓴 **처음 계획**입니다 (Firebase·FCM 서버 계산 등 일부는 바뀌었습니다). 실제로 만든 것과 그 이유는 [README](../README.md)와 아래 8장에 있습니다.

---

## 1. MVP 핵심 아이디어 (한 문장)

사용자의 **Google Calendar 일정**과 **관심사**를 실제 **이벤트 + 날씨** 정보와 연결하고,
AI가 "이 정보가 왜 나에게 중요한지"를 설명하며 **지도**(A→B 이동 경로 포함)에 보여준다.

**데모 스토리 (피칭용):**
1. 사용자가 Google 계정으로 로그인하고 관심사(AI, Startup, Music 등)를 선택한다.
2. 캘린더에 "11월 20일 — 부산" 일정이 있다 → Home에 AI 카드: *"이날 부산에서 대규모 콘서트가 열려 교통이 혼잡할 수 있습니다. 날씨는 +14°C"* + 출처.
3. Map → Route: 서울 → 부산. 경로 주변 대전의 AI 세미나가 표시된다: *"+12 km, +18분"*.
4. 이벤트 → "참가 신청"(공식 페이지) + "캘린더에 추가" → 새로운 일정이 되고 AI가 이 일정도 모니터링한다.
5. 다음 날 푸시 알림: *"추가하신 세미나의 신청 마감이 2일 남았습니다"*.

---

## 2. 범위 (Scope)

### ✅ MVP 포함 (Must)
| # | 기능 | 설명 |
|---|---|---|
| M1 | Google 로그인 + 캘린더 연결 | 캘린더 **읽기 + 일정 추가** |
| M2 | 온보딩 | 관심사, 목표, 언어(ko/en) |
| M3 | **Home — AI 인사이트** | 일정 + 이벤트 + 날씨 연결, "이유", 출처, 신뢰도 |
| M4 | **Map** | 레이어: My Plans / Recommended / Route Opportunities |
| M5 | **Route 모드** | A→B 경로선, 경로 주변 이벤트, 추가 거리/시간 |
| M6 | **Discover** | 관심사 기반 이벤트 목록 + 필터 |
| M7 | 이벤트 상세 | 설명, 날짜, 장소, "추천 이유", 신청 링크, 캘린더에 추가 |
| M8 | 피드백 | 👍 / 👎 / 숨기기 → 이후 추천에 반영 |
| M9 | 선제적 푸시 (FCM) | 매일 스캔 → 새로운 중요 인사이트가 있으면 푸시 |
| M10 | 다국어 | ko / en |

### 🟡 시간이 남으면 (Should)
- Gemini **Google Search grounding**으로 "인터넷에서 새로운 이벤트 발견"
- 채용/장학금 (Scenario 5) — 이벤트 DB에 `type: job|scholarship`으로 추가
- 날씨 경고 (비 예보 → 일정 당일)

### ❌ MVP 제외 (Won't)
- 앱 내 참가 신청 폼 (외부 링크로 이동)
- iOS, 실시간 교통 정보, 기업/산업 동향 분석 (Scenario 4)

---

## 3. 아키텍처

```
┌──────────────── Flutter App (Android) ────────────────┐
│ Home · Map · Plans · Discover · Settings              │
│ google_sign_in → Calendar API (read/insert)           │
│ Calendar → plans 동기화 (앱 실행 시)                   │
└───────┬───────────────────────┬───────────────────────┘
        │ Firestore              │ Callable Functions
        ▼                        ▼
┌──────────────── Firebase ─────────────────────────────┐
│ Auth · Firestore · FCM                                │
│ Cloud Functions (TypeScript):                         │
│  • ingestEvents   (cron, 하루 1회) TourAPI, KOPIS,     │
│                    curated seed JSON                  │
│  • geocodePlan    (trigger) 장소 텍스트 → lat/lng      │
│  • buildInsights  (cron + trigger) 매칭 → Gemini      │
│  • routeDiscover  (callable) Kakao 길찾기 + 경로 반경  │
│  • sendPush       (인사이트 생성 시) FCM               │
└───────┬───────────────────────────────────────────────┘
        ▼
 Gemini API · Kakao Mobility/Local · TourAPI · KOPIS · OpenWeather
```

### 주요 기술 결정
| 항목 | 결정 | 이유 |
|---|---|---|
| 백엔드 | Firebase + Cloud Functions (TS) | 인증/DB/푸시/cron을 한곳에서, 2인 팀에 가장 빠름 |
| AI | Gemini Flash | 한국어 성능, JSON 출력, Search grounding, 무료 티어 |
| 지도 표시 | `google_maps_flutter` | Android에서 무료, 안정적 |
| 길찾기 (route) | **Kakao Mobility Directions** | Google Maps는 한국에서 자동차 길찾기를 제공하지 않음 |
| 지오코딩 | Kakao Local API | 한국 주소 인식이 우수 |
| 이벤트 | TourAPI(축제), KOPIS(공연), curated JSON(IT/해커톤) | 실제 데이터 + 안정적인 데모 |
| 날씨 | OpenWeather (5일 예보) | 간단, 무료 (KMA는 추후) |
| 상태 관리 | Riverpod + go_router | 표준적, 테스트 용이 |
| 다국어 | Flutter `gen_l10n` (ARB) | 공식 방식 |

### "AI 오류 방지" 접근 방식 (Reliability)
AI는 **이벤트를 스스로 만들어내지 않는다**. 2단계 구조:
1. **결정적 매칭** (코드): 날짜 겹침, 거리(km), 관심사 태그 → 후보 + 점수.
2. **Gemini**는 이 후보만 받아서 `why`, `impact`, `confidence`를 JSON으로 반환; 출처는 항상 실제 URL.

피칭에서 강력한 포인트: "할루시네이션을 막는 grounding 구조".

### Route 알고리즘
1. Kakao: A→B 경로선(polyline) + 전체 소요 시간.
2. 경로선을 ~2 km 간격으로 샘플링 → 각 이벤트에서 경로선까지의 최단 거리 (haversine).
3. 필터: 경로 반경 ≤ 15 km, 이동 기간 내 날짜, 관심사 일치.
4. 상위 5개: Kakao A→이벤트→B − A→B = **추가 km / 분**.
5. 점수 = 관심사 일치도 × 근접도 × 시간 적합도 → Gemini가 짧은 설명 생성.

---

## 4. 데이터 모델 (Firestore)

```
users/{uid}
  displayName, locale, interests[], goals[], homeCity, fcmToken, calendarConnected

users/{uid}/plans/{planId}        ← 캘린더에서 동기화
  title, start, end, locationText, lat, lng, city, source: "gcal", gcalEventId

events/{eventId}                  ← 공용 DB
  title{ko,en}, description, type: event|concert|festival|conference|hackathon|job|scholarship
  tags[], start, end, venue, address, lat, lng, city, url, registerUrl, deadline, source, imageUrl

users/{uid}/insights/{insightId}
  kind: plan_alert|opportunity|route|deadline
  title, body, why, impact, confidence(0-1)
  planId?, eventIds[], signals[{type:weather|event, summary}], sources[{title,url}]
  createdAt, notified, feedback: like|dislike|hidden|null

users/{uid}/routes/{routeId}
  origin{name,lat,lng}, dest{...}, date, polyline, durationMin, distanceKm
  opportunities[{eventId, detourKm, detourMin, score, why}]
```

---

## 5. 화면 구성

| 화면 | 주요 요소 |
|---|---|
| Splash / 로그인 | Google 로그인, 개인정보 활용 안내 |
| 온보딩 | 관심사 칩, 목표, 캘린더 권한 |
| **Home** | 인사이트 카드 (이유, 신호 아이콘, 신뢰도, 출처), 👍👎 |
| **Map** | 레이어 토글, 모드: Explore / My Map / Route, 바텀 시트 |
| Route 입력 | 출발지 / 목적지 / 날짜 → 결과 목록 + 지도 |
| **Discover** | 카테고리 필터, 목록, "추천 이유" |
| 이벤트 상세 | 정보, 지도 위치, 참가 신청, 캘린더에 추가 |
| My Plans | 캘린더에서 가져온 일정, 일정별 연결된 인사이트 |
| 설정 | 언어, 연결된 서비스(연결 해제), 푸시 설정 |

---

## 6. 일정 계획 (9일)

| 일차 | 날짜 | 작업 | 결과물 |
|---|---|---|---|
| D1 | 11-05 (오늘) | 계획 ✔ · **API 키 신청** (data.go.kr TourAPI/KOPIS, Kakao, Gemini, OpenWeather) · Firebase 프로젝트 · Google Cloud OAuth (Calendar scope, 테스트 사용자) | 모든 API 키 확보 |
| D2 | 11-06 | Flutter 기본 구조 (Riverpod, go_router, 테마, i18n) · 로그인 + 온보딩 · 디자인 시스템 | 로그인 동작 |
| D3 | 11-07 | 캘린더 읽기 → plans 동기화 · `geocodePlan` · `ingestEvents` + seed JSON | Firestore에 실제 데이터 |
| D4 | 11-08 | `buildInsights` (매칭 + Gemini + 날씨) · **Home 화면** | 첫 AI 카드 ✨ |
| D5 | 11-09 | **Map**: 마커, 레이어, 바텀 시트, 이벤트 상세 | 지도 동작 |
| D6 | 11-10 | **Route**: Kakao 길찾기, 경로 반경, 우회 계산 | 서울→부산 데모 |
| D7 | 11-11 | Discover · 캘린더에 추가 · 신청 링크 · 피드백 · FCM 푸시 + cron | 모든 Must 완료 |
| D8 | 11-12 | ko/en 번역 · UI 다듬기 · 빈 화면/오류 상태 · 데모 시나리오 데이터 | 데모 준비 완료 |
| D9 | 11-13 | 버그 수정 · 릴리스 APK · 데모 영상 · 피치 덱 | 제출 준비 완료 |
| — | 11-14 | **제출** (예비일) | 🚀 |

---

## 7. 리스크

| 리스크 | 대응 |
|---|---|
| data.go.kr API 승인 지연 | 오늘 신청; 지연 시 curated JSON으로 진행 |
| Google OAuth "확인되지 않은 앱" | 테스트 모드 + 데모 계정을 테스트 사용자로 등록 |
| Gemini 사용량 제한 | 인사이트 캐싱(Firestore), 새로운 후보에 대해서만 호출 |
| Kakao Mobility 쿼터 | Route 결과 저장; 우회 계산은 상위 5개만 |
| 시간 부족 | Should 기능부터 축소; 데모 시나리오 경로는 항상 동작해야 함 |

---

## 8. 저장소 구조 (최종)

| 저장소 | 내용 |
|---|---|
| [WOOWANGTHON_TEAM_27_FE](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_FE) | Flutter 앱 (Android · Web) |
| [WOOWANGTHON_TEAM_27_BE](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_BE) | 데이터 파이프라인 — 공공 API 수집, GitHub Actions 스케줄 게시 (`data` 브랜치) |
| [WOOWANGTHON_TEAM_27_AI](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_AI) | 판단 엔진과 AI 모듈 (`liferadar_core`, 순수 Dart) |

> 초기 계획의 Firebase(Firestore·Cloud Functions)는 MVP에서 사용하지 않았습니다. 데이터는 BE의 정적 JSON으로, 사용자 데이터는 기기에 저장합니다. 서버 푸시 설계는 [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md).

## 9. 계획 대비 결과 (11/10)

| # | 계획 | 결과 |
|---|---|---|
| M1 | Google 로그인 + 캘린더 | ✅ 읽기·추가·수정·삭제, 공개(프로덕션) 게시 |
| M2 | 온보딩 | ✅ 관심사 26개 + 지금 상황 + **AI에게 나를 소개하기** (계획 밖 추가) |
| M3 | Home — AI 인사이트 | ✅ 규칙 엔진 + Gemini 문장 + 숫자 검증, 일정 연결 줄, 뉴스 파업·공식 교통 통제 카드 |
| M4·M5 | Map · Route | ✅ Kakao 지도, KTX·자동차 경로, 우회 km·분, 관심사 필터, 끌어내리는 패널 |
| M6·M7 | Discover · 상세 | ✅ 실제 행사 828건, 검색·기간·지역·무료 필터, 포스터, 공유 |
| M8 | 피드백 | ✅ 👍/👎/숨기기 → 취향 가중치 |
| M9 | 선제적 푸시 (FCM) | 🟡 앱 실행 중 로컬 알림만 — 서버 푸시는 [설계](PUSH_NOTIFICATIONS.md) |
| M10 | 다국어 | ✅ ko / en, 행사명 Gemini 번역 |
| 추가 | 앱 안의 AI 비서 | ✅ 실제 행사 후보 안에서 답하고 행동은 사용자가 확인 |
| Should | 날씨 경고 | ✅ Google Weather, 일정 날 비 예보 카드 |
| Should | Search grounding으로 새 행사 발견 | ✕ 대신 공공 API 6종 + 네이버 뉴스 판독 (사실 출처를 고정하기 위해) |
