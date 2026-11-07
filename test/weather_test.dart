import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/services/google_api.dart';

void main() {
  test('parseForecast: 낮 예보가 없으면 하루 전체 예보를 사용한다', () {
    final days = GoogleApi.parseForecast({
      'forecastDays': [
        {
          'displayDate': {'year': 2026, 'month': 11, 'day': 9},
          'maxTemperature': {'degrees': 13.4},
          'minTemperature': {'degrees': 8.6},
          'fullDayForecast': {
            'weatherCondition': {'type': 'LIGHT_RAIN', 'description': {'text': '맑고 때때로 비'}},
            'precipitation': {'probability': {'percent': 90}},
          },
        },
        {
          'displayDate': {'year': 2026, 'month': 11, 'day': 10},
          'maxTemperature': {'degrees': 15},
          'minTemperature': {'degrees': 6},
          'daytimeForecast': {
            'weatherCondition': {'type': 'CLEAR', 'description': {'text': 'Sunny'}},
            'precipitation': {'probability': {'percent': 0}},
          },
        },
      ],
    });
    expect(days.length, 2);
    expect(days[0].date, DateTime(2026, 11, 9));
    expect(days[0].maxC, 13);
    expect(days[0].minC, 9);
    expect(days[0].likelyRain, isTrue);
    expect(days[0].condition, '맑고 때때로 비');
    expect(days[1].type, 'CLEAR');
    expect(days[1].likelyRain, isFalse);
  });
}
