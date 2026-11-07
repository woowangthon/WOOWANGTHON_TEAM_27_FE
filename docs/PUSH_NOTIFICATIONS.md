# 서버 푸시 알림 (FCM) 설계

> 상태 (2026-11-08): **미구현 — 설계만.** 현재 알림은 앱이 실행 중일 때 기기 안에서 보내는 로컬 알림입니다 (Android: `flutter_local_notifications`, 웹: Notification API).

## 현재 구조

- 일정·관심사·피드백은 기기에 저장됩니다 (`shared_preferences`).
- 인사이트는 기기에서 계산합니다: `InsightEngine`(규칙) + Gemini 문장 (`liferadar_core`).
- 로그인은 Google Sign-In이며 Firebase Auth는 사용하지 않습니다.

따라서 어려운 점은 FCM 자체가 아니라 **서버가 사용자 데이터를 모른다는 것**입니다.

## 선택지

| 방식 | 내용 | 예상 기간 | 서버가 아는 정보 |
|---|---|---|---|
| A. FCM만 | Firebase 연결, 토큰 발급, Firebase 콘솔에서 수동 발송 | 2~3시간 | 없음 |
| **B. 하이브리드 (권장)** | 매일 아침 Cloud Function이 모든 기기에 "스캔" 신호(data message) 발송 → 앱이 깨어나 인사이트를 직접 계산하고, 새로운 중요 신호가 있을 때만 로컬 알림 | 0.5~1일 | FCM 토큰(토픽)만 |
| C. 서버 계산 | 일정·관심사를 Firestore에 동기화, 인사이트 엔진을 서버에서 실행, 서버가 알림 선택 | 2일 이상 | 일정·관심사 |

B는 인사이트 엔진을 한 곳(Dart)에 유지하고, 개인 데이터를 서버에 저장하지 않으며, 토픽 발송이라 토큰 DB도 필요 없습니다.

## B 방식 구조

```
Cloud Scheduler (매일 08:00 KST)
   └─▶ Cloud Function `dailyScan`
          └─▶ FCM 토픽 "daily-scan"에 data message {type: "scan"}
                 └─▶ 기기: firebase_messaging 백그라운드 핸들러
                        ├─ 기기에 저장된 일정·행사·관심사 읽기
                        ├─ InsightEngine.build(...) 실행
                        ├─ 새로운 일정 알림·마감 신호가 있는지 확인 (이미 본 신호 제외)
                        └─ 있으면 로컬 알림
```

### 1. Firebase 콘솔 (수동, 약 20분)
1. Firebase 프로젝트 생성 (기존 Google Cloud 프로젝트 선택 가능)
2. Cloud Functions·Scheduler를 위해 **Blaze** 요금제 + **예산 알림** 설정
3. Android 앱 등록: 패키지 `com.liferadar.liferadar`, 서명 인증서 SHA-1

### 2. 앱 (FE)
```bash
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,web
flutter pub add firebase_core firebase_messaging
```
- `main()`: `Firebase.initializeApp(...)`, 토픽 `daily-scan` 구독 (웹은 토픽 미지원)
- `FirebaseMessaging.onBackgroundMessage(...)` — 최상위 함수, `@pragma('vm:entry-point')`. 백그라운드 isolate에는 Riverpod이 없으므로 순수 Dart 엔진을 직접 호출
- 백그라운드에서는 Gemini를 호출하지 않음 (시간 제한) — 규칙 문장 사용

### 3. Cloud Function (BE)
```ts
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

export const dailyScan = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Asia/Seoul", region: "asia-northeast3" },
  async () => {
    await getMessaging().send({ topic: "daily-scan", data: { type: "scan" }, android: { priority: "high" } });
  },
);
```

### 4. 비용
FCM 무료, Cloud Functions 월 200만 호출 무료(하루 1회 ≈ 0), Cloud Scheduler 작업 3개까지 무료.

### 5. 위험 요소
- 삼성·샤오미의 배터리 최적화가 백그라운드 핸들러를 지연·차단할 수 있음
- 백그라운드 핸들러는 **data message**에서만 실행됨 (notification payload가 있으면 시스템이 직접 표시)
- 실기기에서만 검증 가능
