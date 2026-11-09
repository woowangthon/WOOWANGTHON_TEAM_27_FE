# LifeRadar 개인정보처리방침 · Privacy Policy

시행일 · Effective: 2026-11-09

LifeRadar는 2026 AI 우왕톤 Team 27 (DALAB)이 만든 해커톤 MVP입니다. **사용자 정보를 저장하는 자체 서버가 없습니다.** 앱이 다루는 개인정보는 사용자의 기기에 저장되고, 아래 표의 기능을 쓸 때만 해당 서비스로 직접 전송됩니다.

## 1. 처리하는 정보와 목적

| 정보 | 어디서 | 목적 | 저장 위치 |
|---|---|---|---|
| Google 계정 이름·이메일 | Google 로그인 | 화면에 이름 표시, 계정별로 기기 데이터 구분 | 기기 |
| Google 캘린더 일정 (앞으로 90일) | Google Calendar API (`calendar.events`) | 일정과 관련된 행사·교통·날씨 신호 만들기 | 기기 (캐시) |
| 사용자가 고른 행사 → 캘린더 일정 추가·수정·삭제 | Google Calendar API | 사용자가 누른 경우에만 | 사용자의 Google 캘린더 |
| 관심사, 지금 상황, 직접 만든 일정, 👍/👎 피드백 | 사용자 입력 | 추천 순서 | 기기 |
| "나를 소개하기"에 쓴 글 | 사용자 입력 | 상황·관심사 제안 | 기기 |
| 현재 위치 | 기기 위치 (권한 허용 시) | 지도에 내 위치 표시 | 저장하지 않음 |

## 2. 외부 서비스로 보내는 정보

| 서비스 | 보내는 정보 | 언제 |
|---|---|---|
| Google Gemini API | 카드 설명에 필요한 사실(일정 제목·장소·날짜, 행사 정보), "나를 소개하기" 글 | AI 문장·제안을 만들 때 |
| Google Routes · Weather API | 출발·도착 장소, 일정 장소 | 경로·날씨를 볼 때 |
| Kakao Maps · Local · Mobility | 지도 표시 영역, 장소 검색어, 출발·도착 | 지도·검색·경로를 쓸 때 |
| 국가교통정보센터(ITS) | 없음 (공개 교통 정보만 받음) | 앱 실행 시 |

광고, 판매, 프로필 분석 목적으로 정보를 제공하지 않습니다.

## 3. Google 사용자 데이터

LifeRadar가 Google API로 받은 정보의 사용과 다른 앱으로의 전송은 [Google API 서비스 사용자 데이터 정책](https://developers.google.com/terms/api-services-user-data-policy)(제한적 사용 요구사항 포함)을 따릅니다. 캘린더 정보는 위 표의 기능을 제공하는 데에만 쓰며, AI 모델 학습에 쓰지 않습니다.

## 4. 보관과 삭제

- 모든 정보는 기기에 있으며, 앱의 **프로필 → 계정 삭제**를 누르면 이 기기의 LifeRadar 데이터가 모두 지워집니다. 앱을 삭제해도 지워집니다.
- Google 접근 권한은 앱의 **캘린더 연결 해제** 또는 [Google 계정 → 서드파티 연결](https://myaccount.google.com/connections)에서 언제든 취소할 수 있습니다.

## 5. 문의

[GitHub Issues](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_FE/issues)로 문의해 주세요.

---

## English summary

LifeRadar is a hackathon MVP by Team 27 (DALAB). **It has no server that stores user data.** Your Google name and email, calendar events (next 90 days, `calendar.events` scope), interests, situation, self-introduction text and feedback are stored **on your device only**. Data is sent directly to Google (Gemini, Routes, Weather, Calendar) and Kakao (Maps, Local, Mobility) only when you use the corresponding feature, and is never sold or used for ads. LifeRadar's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements; calendar data is not used to train AI models. Delete everything with **Profile → Delete account** or by uninstalling; revoke Google access at <https://myaccount.google.com/connections>. Contact: [GitHub Issues](https://github.com/woowangthon/WOOWANGTHON_TEAM_27_FE/issues).
