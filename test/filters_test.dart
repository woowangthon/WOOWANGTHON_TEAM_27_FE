import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/features/discover/discover_screen.dart';
import 'package:liferadar/features/route/route_controller.dart';
import 'package:liferadar_core/demo.dart';
import 'package:liferadar_core/liferadar_core.dart';

void main() {
  test('기간 필터: 이번 주말은 다가오는 토·일, 일요일이면 오늘만', () {
    final wed = DateTime(2026, 11, 11);
    expect(discoverPeriodRange(DiscoverPeriod.weekend, wed), (DateTime(2026, 11, 14), DateTime(2026, 11, 16)));
    final sun = DateTime(2026, 11, 15);
    expect(discoverPeriodRange(DiscoverPeriod.weekend, sun), (sun, DateTime(2026, 11, 16)));
    expect(discoverPeriodRange(DiscoverPeriod.today, wed).$2, DateTime(2026, 11, 12));
  });

  test('경로 필터: 전체 · 내 관심사 · 관심사 하나 · 카테고리', () {
    final events = sampleEventsAt(DateTime(2026, 11, 9));
    final e = events.firstWhere((e) => e.tags.isNotEmpty);
    expect(routeFilterMatches(null, e, const {}), isTrue);
    expect(routeFilterMatches(routeFilterMine, e, {e.tags.first}), isTrue);
    expect(routeFilterMatches(routeFilterMine, e, const {'no-such-tag'}), isFalse);
    expect(routeFilterMatches(e.category.name, e, const {}), isTrue);
    expect(routeFilterMatches('$routeFilterTagPrefix${e.tags.first}', e, const {}), isTrue);
    expect(routeFilterMatches('${routeFilterTagPrefix}no-such-tag', e, const {}), isFalse);
    final other = EventCategory.values.firstWhere((c) => c != e.category);
    expect(routeFilterMatches(other.name, e, const {}), isFalse);
  });
}
