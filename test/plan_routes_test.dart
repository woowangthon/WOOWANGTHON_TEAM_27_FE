import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/core/theme.dart';
import 'package:liferadar/data/plan_routes.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/data/session.dart';
import 'package:liferadar/features/plans/plans_screen.dart';
import 'package:liferadar/l10n/app_localizations.dart';
import 'package:liferadar/services/google_api.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _from = Plan(
  id: 'a',
  title: '팀 미팅',
  start: DateTime(2026, 11, 10, 14),
  end: DateTime(2026, 11, 10, 15),
  locationText: '강남역',
  city: '서울',
  location: const GeoPoint(37.4979, 127.0276),
);
final _to = Plan(
  id: 'b',
  title: '전시 관람',
  start: DateTime(2026, 11, 10, 16),
  end: DateTime(2026, 11, 10, 18),
  locationText: '성수역',
  city: '서울',
  location: const GeoPoint(37.5445, 127.0557),
);
const _route = TravelRoute(
  distanceMeters: 10000,
  durationSeconds: 1800,
  mode: TravelMode.transit,
  transitLines: ['2호선'],
);

PlanRoute _saved() => PlanRoute.fromSearch(
  from: _from,
  to: _to,
  origin: '강남역',
  destination: '성수역',
  originLocation: _from.location!,
  destinationLocation: _to.location!,
  departure: _from.end,
  route: _route,
);

class _Google extends GoogleApi {
  DateTime? departure;
  GeoPoint? origin, destination;
  bool fail = false;
  @override
  Future<TravelRoute> transit(
    GeoPoint origin,
    GeoPoint destination, {
    required DateTime departure,
  }) async {
    this.origin = origin;
    this.destination = destination;
    this.departure = departure;
    if (fail) throw TimeoutException('test');
    return _route;
  }

  @override
  Future<List<DailyWeather>> dailyForecast(
    GeoPoint p, {
    String lang = 'ko',
  }) async => [];
}

Future<ProviderContainer> _container({
  String session = '{"kind":"guest"}',
}) async {
  SharedPreferences.setMockInitialValues({'session': session});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      nowProvider.overrideWithValue(DateTime(2026, 11, 10)),
      googleApiProvider.overrideWithValue(_Google()),
    ],
  );
  addTearDown(c.dispose);
  c.read(plansProvider.notifier).setPlans([_from, _to]);
  return c;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<Plan>? plans,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = await _container();
  if (plans != null) c.read(plansProvider.notifier).setPlans(plans);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: const PlansScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(find.text('경로 추가'));
  await tester.tap(find.text('경로 추가'));
  await tester.pumpAndSettle();
}

void main() {
  test('only connect same-day, timed, non-overlapping appointments', () {
    expect(canConnectPlans(_from, _to), isTrue);
    expect(
      canConnectPlans(_from, _to.copyWith(start: DateTime(2026, 11, 11, 16))),
      isFalse,
    );
    expect(
      canConnectPlans(
        _from,
        _to.copyWith(start: DateTime(2026, 11, 10, 14, 30)),
      ),
      isFalse,
    );
    expect(
      canConnectPlans(
        _from.copyWith(
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 11),
        ),
        _to,
      ),
      isFalse,
    );
  });

  test(
    'route persists per account and becomes stale after a plan edit',
    () async {
      final c = await _container(
        session: '{"kind":"google","email":"user@example.com"}',
      );
      final saved = _saved();
      await c.read(planRoutesProvider.notifier).save(saved);
      c.invalidate(planRoutesProvider);
      final restored = c.read(planRoutesProvider)[saved.key]!;
      expect(restored.lines, ['2호선']);
      expect(restored.arrival, DateTime(2026, 11, 10, 15, 30));
      expect(restored.originLocation.lat, _from.location!.lat);
      expect(restored.matches(_from, _to), isTrue);
      expect(
        restored.matches(_from, _to.copyWith(locationText: '서울역')),
        isFalse,
      );
      expect(
        restored.matches(
          _from,
          _to.copyWith(start: _to.start.add(const Duration(hours: 1))),
        ),
        isFalse,
      );
      await c.read(sessionProvider.notifier).signOut();
      await c.read(sessionProvider.notifier).continueAsGuest();
      expect(c.read(planRoutesProvider), isEmpty);
    },
  );

  testWidgets(
    'button between plans → autofill → real search adapter → save → remove',
    (tester) async {
      final c = await _pump(tester);
      await _open(tester);
      expect(find.text('강남역'), findsWidgets);
      expect(find.text('성수역'), findsWidgets);
      final save = find.widgetWithText(FilledButton, '이 경로를 일정에 추가');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(find.text('경로 찾기'));
      await tester.pumpAndSettle();
      final api = c.read(googleApiProvider) as _Google;
      expect(api.origin!.lat, _from.location!.lat);
      expect(api.destination!.lng, _to.location!.lng);
      expect(api.departure, _from.end);
      expect(find.text('2호선'), findsOneWidget);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(c.read(planRoutesProvider).length, 1);
      expect(find.text('이동 계획'), findsOneWidget);
      expect(find.text('경로 추가'), findsNothing);
      await tester.tap(find.text('이동 계획'));
      await tester.pumpAndSettle();
      final remove = find.text('이동 경로 삭제');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(c.read(planRoutesProvider), isEmpty);
      expect(find.text('경로 추가'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing coordinates require place selection; no fake route can be saved',
    (tester) async {
      await _pump(
        tester,
        plans: [
          _from.copyWith(location: () => null),
          _to,
        ],
      );
      await _open(tester);
      expect(find.text('정확한 경로 검색을 위해 출발·도착 장소를 선택해주세요.'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '경로 찾기'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '이 경로를 일정에 추가'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'search failure can retry and edited plans cannot save stale results',
    (tester) async {
      final c = await _pump(tester, width: 320);
      final api = c.read(googleApiProvider) as _Google;
      api.fail = true;
      await _open(tester);
      await tester.tap(find.text('경로 찾기'));
      await tester.pumpAndSettle();
      expect(c.read(planRoutesProvider), isEmpty);
      api.fail = false;
      await tester.ensureVisible(find.text('경로 찾기'));
      await tester.tap(find.text('경로 찾기'));
      await tester.pumpAndSettle();
      c.read(plansProvider.notifier).setPlans([
        _from,
        _to.copyWith(locationText: '다른 장소'),
      ]);
      final save = find.widgetWithText(FilledButton, '이 경로를 일정에 추가');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('일정이 변경됐어요. 창을 닫고 경로를 다시 추가해주세요.'), findsOneWidget);
      expect(c.read(planRoutesProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('list and month view both insert routes, never across dates', (
    tester,
  ) async {
    await _pump(
      tester,
      plans: [
        _from,
        _to,
        _to.copyWith(
          id: 'c',
          start: DateTime(2026, 11, 11, 16),
          end: DateTime(2026, 11, 11, 18),
        ),
      ],
    );
    expect(find.text('경로 추가'), findsOneWidget);
    await tester.tap(find.byTooltip('월간 보기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('경로 추가'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('경로 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
