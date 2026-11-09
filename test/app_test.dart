import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar_core/demo.dart';
import 'package:liferadar/features/discover/discover_screen.dart';
import 'package:liferadar/features/home/home_screen.dart';
import 'package:liferadar/main.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [session]이 null이면 — 로그인하지 않은 상태 (로그인 화면).
Future<void> pumpApp(
  WidgetTester tester, {
  List<String>? interests,
  DateTime? now,
  String? session = '{"kind":"guest"}',
  bool setupDone = true,
  String? name = 'Tester',
  String locale = 'en',
  List<Override> overrides = const [],
}) async {
  // "동작 줄이기" — 무한 애니메이션(레이더, shimmer)이 멈춘다;
  // 동시에 앱이 이 설정을 존중하는지도 확인한다.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues({
    'interests': ?interests,
    'session': ?session,
    'setup_done': setupDone,
    'name:guest': ?name,
    // 언어가 선택된 상태 (선택 자체는 welcome 테스트에서 확인한다).
    if (setupDone) 'locale': locale,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        nowProvider.overrideWithValue(now ?? DateTime(2026, 11, 6, 10)),
        ...overrides,
      ],
      child: const LifeRadarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('interestScore: 일치하는 태그 비율', () {
    final expo = sampleEvents.firstWhere((e) => e.id == 'ev-busan-ai-expo'); // ai, startup
    final concert = sampleEvents.firstWhere((e) => e.id == 'ev-busan-concert'); // music, culture
    expect(interestScore(expo, {'ai'}), 0.5);
    expect(interestScore(expo, {'ai', 'startup'}), 1.0);
    expect(interestScore(concert, {'ai'}), 0.0);
  });

  testWidgets('첫 실행: 언어 → 테마 → 로그인 (선택이 저장된다)', (tester) async {
    await pumpApp(tester, session: null, setupDone: false, name: null);
    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a look'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Pick a look'))).brightness, Brightness.dark); // 즉시 적용
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Look around as a guest'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('setup_done'), isTrue);
    expect(prefs.getString('locale'), 'en');
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('로그인 → 게스트 → 이름 → 관심사 → 홈 ("Hi, Abbos")', (tester) async {
    await pumpApp(tester, session: null, name: null);
    await tester.ensureVisible(find.text('Look around as a guest'));
    await tester.tap(find.text('Look around as a guest'));
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Abbos ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('What are you into?'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsOneWidget);
    await tester.tap(find.text('AI'));
    await tester.tap(find.text('Startups'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue (2 selected)'));
    await tester.tap(find.text('Continue (2 selected)'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Abbos'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session'), contains('guest'));
    expect(prefs.getString('name:guest'), 'Abbos');
    expect(prefs.getStringList('interests:guest'), containsAll(['ai', 'startup']));
  });

  testWidgets('이름과 관심사가 저장되어 있으면 바로 홈', (tester) async {
    await pumpApp(tester, interests: ['ai'], name: 'Abbos');
    expect(find.text('Hi, Abbos'), findsOneWidget);
  });

  testWidgets('관심사가 저장되어 있으면 홈이 열리고 언어가 바뀐다', (tester) async {
    await pumpApp(tester, interests: ['ai']);

    expect(find.text('Signals for you'), findsOneWidget);
    // InsightEngine: 부산 출장 + 아시아드 콘서트 → 첫 카드
    expect(find.textContaining('Large concert in Busan'), findsWidgets);

    // 언어 설정은 이제 프로필에
    await tester.tap(find.byIcon(Icons.person_outline_rounded).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('한국어'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.radar_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('나를 위한 신호'), findsOneWidget);
    expect(find.textContaining('부산 대형 콘서트'), findsWidgets);
  });

  testWidgets('발견 탭은 관심사에 맞는 행사를 맨 앞에 둔다', (tester) async {
    await pumpApp(tester, interests: ['music']);
    await tester.tap(find.byIcon(Icons.explore_outlined).last);
    await tester.pumpAndSettle();
    // 음악 관심사 → 콘서트가 목록 맨 앞
    final first = find.byType(EventCard).first;
    expect(find.descendant(of: first, matching: find.text('Large concert in Busan (sample)')), findsOneWidget);
  });

  testWidgets('발견 탭: 검색·필터로 좁히고, 초기화하면 다시 전체', (tester) async {
    await pumpApp(tester, interests: ['music']);
    await tester.tap(find.byIcon(Icons.explore_outlined).last);
    await tester.pumpAndSettle();
    final total = find.byType(EventCard).evaluate().length;
    expect(total, greaterThan(1));

    await tester.enterText(find.byType(TextField).first, 'Busan');
    await tester.pumpAndSettle();
    final cards = find.byType(EventCard);
    expect(cards, findsWidgets);
    for (final e in cards.evaluate()) {
      expect(
        (e.widget as EventCard).event.city.toLowerCase() +
            (e.widget as EventCard).event.title.en.toLowerCase() +
            (e.widget as EventCard).event.venue.toLowerCase(),
        contains('busan'),
      );
    }
    expect(find.text('Reset'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'zzzz-no-such-event');
    await tester.pumpAndSettle();
    expect(find.text('No events match these filters'), findsOneWidget);

    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(find.byType(EventCard).evaluate().length, total);
  });

  testWidgets('키가 없으면 지도 탭에 안내 메시지를 보여준다', (tester) async {
    await pumpApp(tester, interests: ['ai']);
    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Kakao Map key is missing'), findsOneWidget);
  });

  testWidgets('신호가 없으면 홈에 안내 카드를 보여준다', (tester) async {
    // 샘플 날짜는 계속 이동하므로(데모가 낡지 않음) 빈 상태는 — 행사가 없는 경우로 만든다.
    await pumpApp(tester, interests: ['ai'], overrides: [eventsProvider.overrideWithValue(const <RadarEvent>[])]);
    expect(find.text('No signals yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect Google Calendar'), findsOneWidget);
  });

  testWidgets('홈: 통계 = 필터, "Due soon"은 마감만 보여준다', (tester) async {
    await pumpApp(tester, interests: ['ai', 'startup', 'music']);
    // 기본값 — "All signals" 선택됨
    final allCell = find.bySemanticsLabel(RegExp(r'^All signals \d+'));
    expect(tester.getSemantics(allCell), isSemantics(isSelected: true, isButton: true));

    await tester.tap(find.text('Due soon'));
    await tester.pumpAndSettle();
    expect(find.text('Deadlines coming up'), findsOneWidget);
    expect(find.text('Plan alert'), findsNothing);
    expect(find.text('Deadline'), findsWidgets);
  });

  testWidgets('홈: 옆으로 밀면 필터가 바뀌고, 필터 줄은 위에 고정된다', (tester) async {
    await pumpApp(tester, interests: ['ai', 'startup', 'music']);
    expect(find.text('Signals for you'), findsOneWidget);
    // 왼쪽으로 밀기 → 다음 필터 (Due soon)
    await tester.fling(find.byType(CustomScrollView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Deadlines coming up'), findsOneWidget);
    // 오른쪽으로 두 번 → My plans
    await tester.fling(find.byType(CustomScrollView), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(CustomScrollView), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Around your plans'), findsOneWidget);

    // 아래로 스크롤해도 필터가 보인다 (pinned)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Due soon'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Due soon')).dy, lessThan(120)); // 화면 위쪽
  });

  testWidgets('신호 창은 높게 열리고, 끌면 95%까지, 뒤로 버튼으로 닫힌다', (tester) async {
    await pumpApp(tester, interests: ['ai', 'startup', 'music']);
    await tester.tap(find.byType(InsightCard).first);
    await tester.pumpAndSettle();
    final back = find.byTooltip('Back');
    expect(back, findsOneWidget);
    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final before = tester.getTopLeft(back).dy;
    expect(before, lessThan(screenH * 0.15)); // ~90% 높이로 열림

    await tester.drag(back, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(back).dy, lessThan(before)); // 95%까지 펼쳐짐
    expect(tester.getTopLeft(back).dy, greaterThan(screenH * 0.04)); // 하지만 전체 화면은 아님

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('👍 취소 (확인 후)', (tester) async {
    await pumpApp(tester, interests: ['ai', 'startup']);
    final prefs = await SharedPreferences.getInstance();
    await tester.ensureVisible(find.byIcon(Icons.thumb_up_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up_outlined).first);
    await tester.pumpAndSettle();
    expect(prefs.getStringList('insight_feedback')!.single, endsWith('|like'));

    // 다시 누르기 → "Remove your like?" → Remove like
    await tester.tap(find.byIcon(Icons.thumb_up_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove your like?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove like'));
    await tester.pumpAndSettle();
    expect(prefs.getStringList('insight_feedback'), isEmpty);
    expect(find.byIcon(Icons.thumb_up_rounded), findsNothing);
  });

  testWidgets('계정 삭제: 안쪽 화면 + 확인 → 모두 지우고 welcome으로', (tester) async {
    await pumpApp(tester, interests: ['ai'], name: 'Abbos');
    await tester.tap(find.byIcon(Icons.person_outline_rounded).last);
    await tester.pumpAndSettle();
    // 떠 있는 하단 내비게이션 아래에 가리지 않도록 — 화면 위쪽으로 스크롤한다.
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Account & data'), 200, scrollable: list);
    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account & data'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget); // 처음부터
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('name:guest'), isNull);
    expect(prefs.getStringList('interests:guest'), isNull);
    expect(prefs.getBool('setup_done'), isNull);
  });

  testWidgets('열어 본 신호 카드는 흐려지고 저장된다', (tester) async {
    await pumpApp(tester, interests: ['ai', 'startup', 'music']);
    double opacityOfFirst() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity;
    expect(opacityOfFirst(), 1);
    await tester.tap(find.byType(InsightCard).first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // 창 닫기
    await tester.pumpAndSettle();
    expect(opacityOfFirst(), lessThan(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('seen:guest'), isNotEmpty);
  });

  testWidgets('👎 피드백이 저장된다', (tester) async {
    await pumpApp(tester, interests: ['ai', 'startup']);
    await tester.ensureVisible(find.byIcon(Icons.thumb_down_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_down_outlined).first);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    // 먼저 확인을 묻는다 — "Keep"을 누르면 아무것도 저장되지 않는다.
    expect(find.text('Not for you?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(prefs.getStringList('insight_feedback'), isNull);

    await tester.tap(find.byIcon(Icons.thumb_down_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Not for me'));
    await tester.pumpAndSettle();
    expect(prefs.getStringList('insight_feedback')!.single, endsWith('|dislike'));
    expect(find.text('Got it — fewer signals like this'), findsOneWidget); // 토스트
  });
}
