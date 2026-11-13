// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get mapAuthRegistrationError =>
      '지도 인증 실패 (MAP_401). 앱 관리자가 카카오 Android 패키지·서명 키 해시 등록을 확인해야 합니다.';

  @override
  String get mapPermissionError =>
      '지도 사용 권한 없음 (MAP_403). 앱 관리자가 카카오맵 사용 설정을 확인해야 합니다.';

  @override
  String get googleRegistrationError =>
      'Google 앱 인증 설정 오류 (GOOGLE_CONFIG). 앱 관리자가 Android 패키지·서명 SHA-1과 OAuth 클라이언트를 확인해야 합니다.';

  @override
  String get googleSignInCanceled =>
      'Google 연결이 완료되지 않았어요. 계정 선택 후 취소됐다면 앱의 Android 인증 설정 확인이 필요할 수 있어요.';

  @override
  String get googleAccountMismatch =>
      'Google 계정이 일치하지 않아요. 로그아웃 후 캘린더를 사용할 계정으로 다시 연결해 주세요.';

  @override
  String get appTitle => 'LifeRadar';

  @override
  String get tabHome => '홈';

  @override
  String get tabMap => '지도';

  @override
  String get tabPlans => '내 일정';

  @override
  String get tabDiscover => '발견';

  @override
  String get homeGreeting => '나를 위한 이벤트';

  @override
  String get homeSubtitle => '내 일정과 관심사 주변에서 일어난 변화';

  @override
  String get whyItMatters => '중요한 이유';

  @override
  String get aiWritten => 'Gemini가 작성';

  @override
  String get errOffline => '인터넷에 연결되어 있지 않아요. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get errBusy => '지금 서비스가 혼잡해요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errService => '지금은 이 서비스를 사용할 수 없어요.';

  @override
  String get errNoRoute => '두 장소 사이의 경로를 찾지 못했어요.';

  @override
  String get errGeneric => '문제가 발생했어요. 다시 시도해 주세요.';

  @override
  String eventsUpdated(int count, String date) {
    return '실제 공공데이터 · 행사 $count개 · $date 업데이트';
  }

  @override
  String get notifyDeniedApp =>
      '알림이 꺼져 있어요. 설정에서 LifeRadar 알림을 켠 뒤 다시 시도해 주세요.';

  @override
  String planLinkNearby(String km) {
    return '일정 장소에서 $km km · 머무는 동안';
  }

  @override
  String planLinkCrowd(String km) {
    return '같은 날 · $km km 거리';
  }

  @override
  String get planLinkTraffic => '일정 시작 전 · 공식 도로 통제';

  @override
  String get planLinkStrike => '같은 날 · 뉴스 보도 (참고)';

  @override
  String get sources => '출처';

  @override
  String confidence(int percent) {
    return '신뢰도 $percent%';
  }

  @override
  String get showOnMap => '지도에서 보기';

  @override
  String get feedbackThanks => '감사합니다! 추천에 반영할게요.';

  @override
  String get layerPlans => '내 일정';

  @override
  String get layerRecommended => '추천';

  @override
  String get layerRoute => '경로';

  @override
  String get modeExplore => '탐색';

  @override
  String get modeMyMap => '내 지도';

  @override
  String get modeRoute => '경로';

  @override
  String get mapKeyMissing =>
      '카카오 지도 키가 없습니다.\n--dart-define-from-file=env.json 으로 실행하세요';

  @override
  String mapError(String message) {
    return '지도를 불러오지 못했습니다: $message';
  }

  @override
  String get plansEmpty => '예정된 일정이 없습니다. Google 캘린더를 연결해 가져오세요.';

  @override
  String get connectCalendar => 'Google 캘린더 연결';

  @override
  String get comingSoon => '준비 중';

  @override
  String get discoverAll => '전체';

  @override
  String get whyForYou => '추천 이유';

  @override
  String get register => '참가 신청';

  @override
  String get addToCalendar => '캘린더에 추가';

  @override
  String get noRegisterLink => '아직 신청 링크가 없습니다';

  @override
  String get sampleData => '샘플 데이터';

  @override
  String matchesInterests(String tags) {
    return '관심사와 일치: $tags';
  }

  @override
  String get language => '언어';

  @override
  String get categoryConference => '컨퍼런스';

  @override
  String get categoryHackathon => '해커톤';

  @override
  String get categoryConcert => '콘서트';

  @override
  String get categoryFestival => '축제';

  @override
  String get categoryMeetup => '밋업';

  @override
  String get categoryJob => '채용';

  @override
  String get categoryScholarship => '장학금';

  @override
  String mapSdkNotLoaded(String origin) {
    return '카카오 지도 SDK를 불러오지 못했습니다.\nKakao Developers에 아래 주소를 Web 도메인으로 등록하세요:\n$origin';
  }

  @override
  String get routeFrom => '출발';

  @override
  String get routeTo => '도착';

  @override
  String get routeDate => '날짜';

  @override
  String get routeFind => '경로 주변 기회 찾기';

  @override
  String get routeDemo => '데모: 서울역 → 부산역';

  @override
  String get routeSearchHint => '장소 검색 (예: 부산역, BEXCO)';

  @override
  String get routeNoResults => '검색 결과가 없습니다';

  @override
  String routeSummary(String distance, String duration) {
    return '자동차 $distance km · $duration';
  }

  @override
  String routeAlongTheWay(int count) {
    return '경로 주변 ($count)';
  }

  @override
  String get routeNoOpportunities => '해당 날짜에 경로 15km 이내의 관련 이벤트가 없습니다.';

  @override
  String routeDetour(String km, int minutes) {
    return '+$km km · +$minutes분';
  }

  @override
  String routeFromRoute(String km) {
    return '경로에서 $km km';
  }

  @override
  String routeError(String message) {
    return '경로 탐색 실패: $message';
  }

  @override
  String get onYourWay => '가는 길에';

  @override
  String hoursMinutes(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String get travelCar => '자동차';

  @override
  String get travelTransit => '대중교통';

  @override
  String routeSummaryTransit(String distance, String duration, String lines) {
    return '$distance km · $duration · $lines';
  }

  @override
  String get calendarConnecting => 'Google에 연결 중…';

  @override
  String get calendarSyncing => '캘린더 동기화 중…';

  @override
  String calendarConnectedCount(int count) {
    return 'Google 캘린더 · 예정 일정 $count개';
  }

  @override
  String get calendarSync => '동기화';

  @override
  String get calendarDisconnect => '연결 해제';

  @override
  String get calendarExpired => 'Google 세션이 만료되었습니다. 다시 연결해 주세요.';

  @override
  String get calendarNotConfigured =>
      '이 플랫폼에서는 아직 Google 로그인이 설정되지 않았습니다 (현재 웹 전용).';

  @override
  String calendarError(String message) {
    return '캘린더 오류: $message';
  }

  @override
  String get calendarPrivacy =>
      'LifeRadar는 예정된 일정만 읽고, 선택한 이벤트만 추가합니다. 언제든 연결을 해제할 수 있습니다.';

  @override
  String get noLocation => '장소 없음';

  @override
  String get sourceCalendar => 'Google 캘린더';

  @override
  String get addedToCalendar => 'Google 캘린더에 추가했습니다';

  @override
  String get addingToCalendar => '추가 중…';

  @override
  String get weatherLater => '예보는 약 10일 전부터 제공';

  @override
  String get onboardingTagline => '검색하기 전에, 내 일정 주변의 기회를 먼저 찾아드려요.';

  @override
  String get onboardingTitle => '어떤 분야에 관심 있으세요?';

  @override
  String get onboardingSubtitle => '몇 개만 골라 주세요. 행사와 경로 추천 순서에 반영돼요.';

  @override
  String get onboardingPickOne => '하나 이상 선택해 주세요';

  @override
  String onboardingContinue(int count) {
    return '계속 ($count개 선택)';
  }

  @override
  String get onboardingPrivacy => '이 기기에만 저장되며 언제든 바꿀 수 있어요.';

  @override
  String get interestsEdit => '내 관심사';

  @override
  String get save => '저장';

  @override
  String get homeEmptyTitle => '아직 신호가 없어요';

  @override
  String get homeEmptyBody => '캘린더를 연결하거나 관심사를 더 추가해 보세요. 일정과 행사·날씨를 연결해 드릴게요.';

  @override
  String get tabProfile => '프로필';

  @override
  String get loginError => 'Google 로그인에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get or => '또는';

  @override
  String get continueAsGuest => '게스트로 둘러보기';

  @override
  String get loginPrivacy => '캘린더는 동의하신 경우에만 별도로 연결돼요.';

  @override
  String get guestName => '게스트';

  @override
  String get guestSubtitle => '로그인하면 내 정보로 이용할 수 있어요';

  @override
  String get signIn => '로그인';

  @override
  String get edit => '수정';

  @override
  String get ok => '확인';

  @override
  String get sectionConnections => '연결된 서비스';

  @override
  String get connected => '연결됨';

  @override
  String get notConnected => '연결 안 됨';

  @override
  String get connect => '연결';

  @override
  String get sectionSettings => '설정';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get sectionAbout => '정보';

  @override
  String get privacy => '개인정보 보호';

  @override
  String get version => '버전';

  @override
  String get logout => '로그아웃';

  @override
  String get exitGuest => '처음 화면으로';

  @override
  String get homeHello => '안녕하세요';

  @override
  String homeHelloName(String name) {
    return '$name님, 안녕하세요';
  }

  @override
  String get statPlans => '일정';

  @override
  String get statSignals => '신호';

  @override
  String get statDeadlines => '마감 임박';

  @override
  String get kindPlanAlert => '일정 알림';

  @override
  String get kindOpportunity => '기회';

  @override
  String get kindDeadline => '마감';

  @override
  String get kindRoute => '경로';

  @override
  String get helpful => '유용해요';

  @override
  String get notForMe => '관심 없어요';

  @override
  String get hide => '숨기기';

  @override
  String get today => '오늘';

  @override
  String get tomorrow => '내일';

  @override
  String get upcoming => '다가오는 일정';

  @override
  String get discoverSubtitle => '관심사와 잘 맞는 순서로 보여드려요';

  @override
  String get matchBadge => '일치';

  @override
  String get eventDetails => '상세 정보';

  @override
  String get openSource => '출처';

  @override
  String get searching => '검색 중…';

  @override
  String get rainChance => '강수';

  @override
  String get showLess => '접기';

  @override
  String get planNew => '새 일정';

  @override
  String get planEdit => '일정 수정';

  @override
  String get planTitle => '제목';

  @override
  String get planTitleHint => '예: 부산 출장';

  @override
  String get planTitleRequired => '제목을 입력하세요';

  @override
  String get planDate => '날짜';

  @override
  String get planStart => '시작';

  @override
  String get planEnd => '종료';

  @override
  String get planAllDay => '하루 종일';

  @override
  String get planLocation => '장소';

  @override
  String get planLocationAdd => '장소 추가';

  @override
  String get planLocationRemove => '장소 삭제';

  @override
  String get planNote => '메모';

  @override
  String get planNoteHint => '기억할 내용';

  @override
  String get planSaveToCalendar => 'Google 캘린더에도 저장';

  @override
  String get planCalendarSynced => '변경 사항은 Google 캘린더에도 저장돼요.';

  @override
  String get planSampleHint => '샘플 일정이에요. 저장하면 내 일정이 돼요.';

  @override
  String get planDelete => '일정 삭제';

  @override
  String planDeleteConfirm(String title) {
    return '\"$title\" 일정을 삭제할까요?';
  }

  @override
  String get planSaved => '일정을 저장했어요';

  @override
  String get planDeleted => '일정을 삭제했어요';

  @override
  String get planEndBeforeStart => '종료 시간은 시작 시간 이후여야 해요';

  @override
  String planSaveError(String message) {
    return '저장하지 못했어요: $message';
  }

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get openInCalendar => 'Google 캘린더에서 열기';

  @override
  String get plansEmptyAdd => '첫 일정을 추가하거나 Google 캘린더를 연결해 가져오세요.';

  @override
  String interestsSelectedCount(int count) {
    return '$count개 선택';
  }

  @override
  String get categoryPerformance => '연극·뮤지컬';

  @override
  String get categoryExhibition => '전시';

  @override
  String get categoryClasses => '교육·체험';

  @override
  String get free => '무료';

  @override
  String dataSource(String name) {
    return '출처: $name';
  }

  @override
  String get showMore => '더 보기';

  @override
  String get realData => '실제 데이터';

  @override
  String get ongoing => '진행 중';

  @override
  String get categoryStartupSupport => '창업 지원';

  @override
  String applicationPeriod(String from, String to) {
    return '접수 $from – $to';
  }

  @override
  String get nationwide => '전국';

  @override
  String get applyNow => '신청하기';

  @override
  String get aiTranslated => 'Gemini로 번역됨';

  @override
  String get statForPlans => '내 일정';

  @override
  String get statAll => '전체 이벤트';

  @override
  String get statSoon => '마감 임박';

  @override
  String get homeSectionPlans => '내 일정 주변';

  @override
  String get homeSectionDeadlines => '곧 마감되는 신청';

  @override
  String get homeFilterEmpty => '지금은 해당 신호가 없어요';

  @override
  String get dislikeConfirmTitle => '관심 없는 신호인가요?';

  @override
  String get dislikeConfirmBody => '비슷한 신호를 덜 보여드릴게요.';

  @override
  String get yes => '예';

  @override
  String get no => '아니요';

  @override
  String get feedbackLiked => '고마워요! 비슷한 신호를 더 보여드릴게요';

  @override
  String get feedbackDisliked => '알겠어요. 비슷한 신호를 줄일게요';

  @override
  String untilDate(String date) {
    return '$date까지';
  }

  @override
  String get openEvent => '행사 자세히 보기';

  @override
  String get signalWhy => '이 신호가 뜬 이유';

  @override
  String get calendarAddFailed => '캘린더에 추가하지 못했어요';

  @override
  String interestsCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get next => '다음';

  @override
  String get back => '이전';

  @override
  String get getStarted => '시작하기';

  @override
  String get themeTitle => '화면 테마를 고르세요';

  @override
  String get themeSubtitle => '프로필에서 언제든 바꿀 수 있어요.';

  @override
  String get themeSystemDesc => '기기 설정을 따라요';

  @override
  String get themeLightDesc => '밝고 깔끔하게';

  @override
  String get themeDarkDesc => '밤에도 눈이 편하게';

  @override
  String get nameTitle => '어떻게 불러드릴까요?';

  @override
  String get nameSubtitle => '홈 화면에서 이 이름으로 인사해요.\n프로필에서 언제든 바꿀 수 있어요.';

  @override
  String get nameHint => '이름';

  @override
  String get nameRequired => '이름을 입력해 주세요';

  @override
  String get editName => '이름 수정';

  @override
  String stepOf(int n, int total) {
    return '$n / $total 단계';
  }

  @override
  String get welcomeTagline => '내 일정과 관심사로 찾는 신호';

  @override
  String get loginF1Title => '일정과 세상을 연결';

  @override
  String get loginF1Body => '캘린더 × 행사 × 날씨 × 마감';

  @override
  String get loginF2Title => '가는 길의 기회';

  @override
  String get loginF2Body => 'KTX·자동차 경로에서 추가 km·분까지';

  @override
  String get loginF3Title => '왜 중요한지 바로';

  @override
  String get loginF3Body => '모든 신호에 이유와 출처를 함께';

  @override
  String get loginPanelTitle => '시작해 볼까요?';

  @override
  String get loginPanelBody => 'Google 계정만 있으면 돼요. 따로 가입할 필요 없어요.';

  @override
  String get myLocation => '내 위치';

  @override
  String get locationDenied => '위치 권한이 꺼져 있어요. 브라우저나 기기 설정에서 허용해 주세요.';

  @override
  String get locationUnavailable => '지금은 위치를 가져올 수 없어요.';

  @override
  String get planViewMonth => '월간 보기';

  @override
  String get planViewList => '목록 보기';

  @override
  String get noPlansThisDay => '이 날은 일정이 없어요';

  @override
  String get planSignalRain => '비 예보 — 우산을 챙기세요';

  @override
  String planSignalCrowd(String event) {
    return '근처 $event — 혼잡 예상';
  }

  @override
  String planSignalNearby(String event) {
    return '근처: $event';
  }

  @override
  String get planAround => '이 일정 주변 소식';

  @override
  String get planNothingAround => '지금은 이 일정에 영향을 줄 소식이 없어요.';

  @override
  String get myPlanBadge => '내 일정';

  @override
  String get calendarOpenGoogle => 'Google 캘린더 열기';

  @override
  String get planWhen => '언제';

  @override
  String get planWhere => '어디서';

  @override
  String get likeUndoTitle => '좋아요를 취소할까요?';

  @override
  String get likeUndoBody => '이 신호가 다시 다른 신호와 같은 순서로 보여요.';

  @override
  String get dislikeUndoTitle => '비슷한 신호를 다시 볼까요?';

  @override
  String get dislikeUndoBody => '이 신호를 더 이상 아래로 내리지 않을게요.';

  @override
  String get removeLike => '좋아요 취소';

  @override
  String get showAgain => '다시 보기';

  @override
  String get keep => '유지';

  @override
  String get notForMeConfirm => '관심 없음';

  @override
  String get feedbackCleared => '평가를 취소했어요';

  @override
  String get notifications => '알림';

  @override
  String get notifyDesc => '마감·일정 알림·비 예보를 시스템 알림으로 받아요';

  @override
  String get notifyUnsupported => '이 기기에서는 아직 지원하지 않아요';

  @override
  String get notifyDenied => '알림이 차단되어 있어요. 브라우저 설정에서 허용해 주세요.';

  @override
  String get notifyOn => '알림을 켰어요';

  @override
  String get notifyTest => '테스트 알림 보내기';

  @override
  String get notifyTestBody => '알림이 잘 작동해요. 일정에 영향을 주는 소식이 생기면 알려드릴게요.';

  @override
  String get accountData => '계정 및 데이터';

  @override
  String get accountDataSubtitle => '계정과 이 기기에 저장된 데이터를 삭제해요';

  @override
  String get deleteAccount => '계정 삭제';

  @override
  String get deleteAccountTitle => '계정을 삭제할까요?';

  @override
  String get deleteAccountBody =>
      '이름·관심사·직접 만든 일정·평가·설정이 이 기기에서 모두 지워지고, Google 접근 권한도 해제돼요. 앱은 처음 상태로 돌아가요. 되돌릴 수 없어요.';

  @override
  String get deleteAccountInfo =>
      'LifeRadar는 데이터를 이 기기에만 저장해요. 삭제하면 모두 지워지고 Google 캘린더 연결도 끊겨요.';

  @override
  String get accountDeleted => '계정을 삭제했어요. 처음부터 시작해요.';

  @override
  String get eventAbout => '소개';

  @override
  String get eventPrice => '요금';

  @override
  String get applicationLabel => '접수 기간';

  @override
  String get organizer => '주관';

  @override
  String get matchesYou => '내 관심사와 일치';

  @override
  String get routePanelHint => '아래로 내리면 지도를 넓게 볼 수 있어요';

  @override
  String get routePanelExpand => '경로 패널 펼치기';

  @override
  String get routePanelCollapse => '경로 패널 내리기';

  @override
  String get filterMine => '내 관심사';

  @override
  String get discoverSearchHint => '행사·장소 검색';

  @override
  String get filterPeriod => '기간';

  @override
  String get filterAnyTime => '전체 기간';

  @override
  String get periodToday => '오늘';

  @override
  String get periodWeekend => '이번 주말';

  @override
  String get periodWeek => '7일 안';

  @override
  String get periodMonth => '한 달 안';

  @override
  String get filterRegion => '지역';

  @override
  String get filterAllRegions => '전체 지역';

  @override
  String get sortMatch => '추천순';

  @override
  String get sortSoon => '날짜순';

  @override
  String get discoverPicks => '관심사 맞춤 추천';

  @override
  String discoverResults(int count) {
    return '$count개';
  }

  @override
  String get filterReset => '초기화';

  @override
  String get discoverNoResults => '조건에 맞는 행사가 없어요';

  @override
  String get routeEdit => '수정';

  @override
  String get stageTitle => '지금 어떤 상황인가요?';

  @override
  String get stageOptional => '선택 · 상황에 맞는 공고와 행사를 먼저 보여 드려요';

  @override
  String get aboutMeCta => 'AI에게 나를 소개하기';

  @override
  String get aboutMeCtaBody => '몇 문장만 쓰면 상황과 관심사를 골라 드려요. 고르는 건 직접 해요.';

  @override
  String get aboutMeTitle => '나를 소개하기';

  @override
  String get aboutMeGreeting =>
      '어떤 사람인지 편하게 적어 주세요. 하는 일, 요즘 관심 있는 것, 주말에 하는 일… 무엇이든 좋아요.';

  @override
  String get aboutMeEx1 => '컴퓨터공학과 3학년이에요. AI 공부 중이고 해커톤에 나가 보고 싶어요.';

  @override
  String get aboutMeEx2 => '마케팅 회사 직장인이에요. 퇴근 후엔 러닝, 주말엔 전시회를 다녀요.';

  @override
  String get aboutMeEx3 => '창업 준비 중이에요. 투자 설명회와 창업 지원 사업 정보가 필요해요.';

  @override
  String get aboutMeHint => '나에 대해 적어 주세요';

  @override
  String get aboutMeSend => '보내기';

  @override
  String get aboutMeThinking => '읽고 있어요…';

  @override
  String get aboutMeUnderstood => '이렇게 이해했어요. 맞는 것만 남겨 주세요.';

  @override
  String get aboutMeKeyword => '단어로 찾아봤어요 (AI 연결 안 됨). 맞는 것만 남겨 주세요.';

  @override
  String get aboutMeNothing => '아직 잘 모르겠어요. 하는 일이나 좋아하는 것을 조금 더 적어 주세요.';

  @override
  String aboutMeStage(String stage) {
    return '상황: $stage';
  }

  @override
  String aboutMeApply(int count) {
    return '적용하기 ($count)';
  }

  @override
  String aboutMeApplied(int count) {
    return '관심사 $count개를 더했어요';
  }

  @override
  String get aboutMeAiBadge => 'AI 제안';

  @override
  String get aboutMePrivacy => '쓴 글은 제안을 만들 때만 Google Gemini로 보내고, 기기에만 저장해요.';

  @override
  String get share => '공유';

  @override
  String get shareFooter => 'LifeRadar에서 찾은 행사예요';

  @override
  String get shareCopied => '공유할 글을 복사했어요';

  @override
  String get planDeleteCalendarNote => 'Google 캘린더에서도 삭제돼요.';

  @override
  String get assistantButton => 'AI 비서';

  @override
  String get assistantTitle => 'LifeRadar AI';

  @override
  String get assistantSubtitle => '내 일정과 실제 데이터로 답해요';

  @override
  String get assistantNewChat => '새 대화';

  @override
  String get assistantHello => '무엇을 찾아 드릴까요?';

  @override
  String get assistantHelloBody =>
      '일정·관심사·실제 공공데이터를 보고 찾아 드려요.\n캘린더 추가 같은 일은 직접 확인한 뒤에만 해요.';

  @override
  String get assistantSuggestWeekend => '이번 주말에 뭐 하지?';

  @override
  String assistantSuggestPlan(String plan) {
    return '$plan 때 갈 만한 곳 있어?';
  }

  @override
  String get assistantSuggestDeadline => '마감 임박한 공고 알려줘';

  @override
  String get assistantSuggestFree => '무료 전시 추천해 줘';

  @override
  String get assistantTrust => '후보는 코드가 실제 데이터에서 고르고, AI는 그중에서만 답해요';

  @override
  String get assistantThinking => '일정과 행사를 살펴보는 중…';

  @override
  String get assistantAiBadge => 'AI 답변';

  @override
  String get assistantRuleBadge => '조건 검색';

  @override
  String get assistantRuleNote => 'AI 연결이 안 돼 조건으로 찾은 결과예요.';

  @override
  String get assistantHint => '무엇이든 물어보세요';

  @override
  String get assistantFooter => 'AI는 제안만 해요. 추가·변경은 직접 확인해요.';

  @override
  String get assistantProposeCalendar => '캘린더에 추가할까요?';

  @override
  String get assistantProposeMap => '지도에서 볼까요?';

  @override
  String get assistantAdd => '추가';

  @override
  String get assistantOpen => '보기';

  @override
  String get assistantAdded => '추가했어요';

  @override
  String get assistantOpened => '열었어요';

  @override
  String get assistantCancelled => '취소했어요';

  @override
  String get retry => '다시 시도';

  @override
  String get planRouteAdd => '경로 추가';

  @override
  String get planRouteArrival => '도착';

  @override
  String get planRouteAutoLocations => '앞뒤 일정의 장소를 가져왔어요. 대중교통 경로를 검색하고 저장하세요.';

  @override
  String get planRouteDelete => '이동 경로 삭제';

  @override
  String get planRouteDeparture => '출발';

  @override
  String get planRouteLate => '다음 일정 시작 시간보다 늦게 도착해요.';

  @override
  String get planRouteMissingLocation => '정확한 경로 검색을 위해 출발·도착 장소를 선택해주세요.';

  @override
  String get planRouteOutsideGap => '앞 일정 종료 후부터 다음 일정 시작 전까지의 출발 시간을 선택해주세요.';

  @override
  String get planRouteSave => '이 경로를 일정에 추가';

  @override
  String get planRouteStale => '일정이 변경됐어요. 창을 닫고 경로를 다시 추가해주세요.';

  @override
  String get planRouteTitle => '이동 계획';

  @override
  String get planRouteSearch => '경로 찾기';

  @override
  String get categoryContest => '공모전';

  @override
  String get applicationDeadline => '접수 마감';

  @override
  String get eligibilityLabel => '참가자격';

  @override
  String get eligibilityUnknown => '참가자격 원문 확인';

  @override
  String get verificationDelayed => '업데이트 지연 · 접수 상태 원문 확인';

  @override
  String get verifiedAtLabel => '마지막 검증';

  @override
  String get applicationOpen => '접수 중';

  @override
  String get applicationUpcoming => '접수 예정';

  @override
  String get applicationClosed => '접수 마감';

  @override
  String get applicationCancelled => '취소';

  @override
  String get applicationUnknown => '접수 상태 미확인';

  @override
  String get planTravelTitle => '이동 방법';

  @override
  String get planTravelHint => '이동 방법을 적어두면 그 노선·도로의 파업·통제 소식을 이 일정에 맞춰 알려드려요.';

  @override
  String get planTravelNone => '선택 안 함';

  @override
  String get planTravelBus => '버스';

  @override
  String get planTravelSubway => '지하철';

  @override
  String get planTravelRail => '기차';

  @override
  String get planTravelAir => '비행기';

  @override
  String get planTravelCar => '자동차';

  @override
  String get planTravelLines => '노선·편명 (선택)';

  @override
  String get planTravelLinesHint => '예: KTX 오송→부산, 2호선, 750번';

  @override
  String get planTravelOriginAdd => '출발지 추가';

  @override
  String get planTravelDepartureAdd => '출발 시각 추가';

  @override
  String planTravelDepartAt(String time) {
    return '$time 출발';
  }

  @override
  String planTravelFrom(String place) {
    return '$place에서';
  }

  @override
  String get planTravelDepartureAfterStart => '출발 시각은 일정 시작 전(24시간 이내)이어야 해요.';

  @override
  String get planTravelAirNote =>
      '항공 운항 정보는 아직 연결되지 않았어요. 비행기는 기록만 하고 알림 근거로 쓰지 않아요.';

  @override
  String get tabAlerts => '알림';

  @override
  String get alertsTitle => '알림';

  @override
  String get more => '더보기';

  @override
  String get alertsMarkAllRead => '모두 읽음으로 표시';

  @override
  String get alertsAllRead => '모든 알림을 읽음으로 표시했어요';

  @override
  String get alertsTestSent => '테스트 알림을 보냈어요';

  @override
  String get alertsAll => '전체';

  @override
  String get alertsEmptyTitle => '확인할 알림이 없어요';

  @override
  String get alertsEmptyBody => '일정에 장소를 넣으면 교통·날씨·혼잡을 대신 살펴볼게요.';

  @override
  String get alertsNoDate => '날짜 미정';

  @override
  String get alertsTomorrow => '내일';

  @override
  String get alertsTopicRoad => '도로';

  @override
  String get alertsTopicTransit => '대중교통';

  @override
  String get alertsTopicWeather => '날씨';

  @override
  String get alertsTopicCrowd => '혼잡';

  @override
  String get alertsCalm => '오늘은 조용해요';

  @override
  String get alertsCalmBody => '다가오는 일정에 영향을 주는 소식이 없어요.';

  @override
  String get alertsSummary => '건 · 일정에 확인할 알림';

  @override
  String alertsNew(int count) {
    return '새 알림 $count';
  }

  @override
  String get alertsPushOn => '푸시 켜짐';

  @override
  String get alertsPushOff => '푸시 꺼짐';

  @override
  String get notifyOff => '알림을 껐어요';

  @override
  String get planRouteSaved => '이동 경로를 일정에 추가했어요';

  @override
  String get planRouteRemoved => '이동 경로를 삭제했어요';

  @override
  String get planRouteError => '경로를 찾지 못했어요. 장소와 시간을 확인해 주세요.';

  @override
  String get calendarConnectedToast => 'Google 캘린더를 연결했어요';

  @override
  String get calendarDisconnectedToast => '캘린더 연결을 해제했어요';

  @override
  String get calendarSyncedToast => '일정을 새로 불러왔어요';

  @override
  String get calendarErrorToast => '캘린더를 불러오지 못했어요. 다시 시도해 주세요.';

  @override
  String get calendarExpiredToast => '캘린더 연결이 만료됐어요. 다시 연결해 주세요.';

  @override
  String get signedOutToast => '로그아웃했어요';

  @override
  String get interestsSaved => '관심사를 저장했어요';

  @override
  String get nameSaved => '이름을 저장했어요';

  @override
  String get refreshedToast => '최신 정보로 새로 고쳤어요';

  @override
  String get assistantCancelledToast => '제안을 넘겼어요';

  @override
  String get travelCheckError => '교통 영향을 확인하지 못했어요';

  @override
  String get themeChanged => '테마를 바꿨어요';

  @override
  String get languageChanged => '언어를 바꿨어요';

  @override
  String get profileTitle => '내 정보';

  @override
  String get profileSettings => '앱 설정';

  @override
  String get profileHelp => '도움말·정보';

  @override
  String get profileStageNone => '상황 미선택';

  @override
  String get calendarAlreadyAdded => '이미 캘린더에 있는 일정이에요';

  @override
  String get calendarAddedLabel => '캘린더에 추가됨';

  @override
  String get planSavedCalendar => '일정을 저장하고 Google 캘린더에도 넣었어요';

  @override
  String get planSaving => '저장하는 중…';

  @override
  String get planDeleting => '삭제하는 중…';

  @override
  String get visitDayTitle => '언제 갈까요? 그날 하루만 캘린더에 넣어요';

  @override
  String get visitDayConfirm => '이날 추가';

  @override
  String get avatarTitle => '프로필 사진';

  @override
  String get avatarChanged => '프로필 사진을 바꿨어요';
}
