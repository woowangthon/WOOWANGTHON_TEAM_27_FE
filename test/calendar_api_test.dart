import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/services/calendar_api.dart';

void main() {
  test('시간 지정 일정(시간대 포함)을 파싱한다', () {
    final e = CalendarEvent.fromJson({
      'id': 'a1',
      'summary': 'Busan trip',
      'location': '부산역',
      'start': {'dateTime': '2026-11-20T09:00:00+09:00'},
      'end': {'dateTime': '2026-11-20T18:00:00+09:00'},
    });
    expect(e.title, 'Busan trip');
    expect(e.location, '부산역');
    expect(e.start.toUtc(), DateTime.utc(2026, 11, 20, 0));
    expect(e.end.difference(e.start), const Duration(hours: 9));
  });

  test('종일 일정과 제목 없는 일정', () {
    final e = CalendarEvent.fromJson({
      'id': 'a2',
      'start': {'date': '2026-11-21'},
      'end': {'date': '2026-11-22'},
    });
    expect(e.title, '(no title)');
    expect(e.location, isNull);
    expect(e.start, DateTime(2026, 11, 21));
  });
}
