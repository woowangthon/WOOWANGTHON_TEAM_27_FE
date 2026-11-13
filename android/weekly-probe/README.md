# 실제 기기 주간 수집 검증 도구

제품 APK에 포함되지 않는 별도 Android instrumentation이다. 현재 개발 APK와 같은 인증서로 서명해야 실행할 수 있다. 외부 라이브러리는 사용하지 않는다.

- `mode inspect`: 공모전 전용 캐시의 출처별 건수·갱신 상태만 반환한다. 계정·일정·관심사 값은 읽거나 출력하지 않는다.
- `mode make_due`: `flutter.weekly_contests:` 아래 성공·시도·URL 확인 시각만 제거하여 7일 경과 상황을 만든다. 공고 사실과 다른 앱 데이터는 유지한다.
- 추가 인자 `expireVenue true`: 이미 검증한 실제 SVC 공고의 항목 검증 시각만 시험 만료시켜 대면 세션·지오코딩 재수집을 검증한다. 이전 시각은 별도 시험 백업에 저장한다. 다음 `inspect`가 새로 수집되지 않은 시험 시각을 복원한다.
- instrumentation 실행 때문에 Android가 대상 프로세스를 종료할 수 있다. 이전 콜백이 있는 경우 이 앱의 주기 작업만 복원한다.

일반 앱 설치와 별개로 테스트 기기에서만 실행한다. 완료 후 반드시 마지막 `inspect`로 시험 시각을 정리하고 시험 패키지를 제거한다. 사용자 계정·일정이나 앱 전체 데이터를 초기화하는 명령은 사용하지 않는다.

```powershell
adb -s DEVICE_SERIAL install -r weekly-probe.apk
adb -s DEVICE_SERIAL shell am instrument -w -e mode make_due -e expireVenue true com.liferadar.weeklyprobe/.WeeklyProbe
adb -s DEVICE_SERIAL shell am kill com.liferadar.liferadar
adb -s DEVICE_SERIAL shell cmd jobscheduler run -f com.liferadar.liferadar 270713
# LifeRadarContestJob 로그에서 종료를 확인한 뒤:
adb -s DEVICE_SERIAL shell am instrument -w -e mode inspect com.liferadar.weeklyprobe/.WeeklyProbe
adb -s DEVICE_SERIAL uninstall com.liferadar.weeklyprobe
```

OS 주기 실행을 일주일 기다린 결과가 아니라, 실기기에서 주기 작업을 시험 실행한 결과로 기록한다. 7일·6시간 경계는 Dart 고정 시각 테스트로 별도 검증한다.
