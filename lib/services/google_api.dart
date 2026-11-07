import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/env.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// Google Maps Platform: Routes (TRANSIT)와 Weather.
/// 한국에서 Google은 자동차 길찾기를 제공하지 않아 자동차는 Kakao를 사용한다.
class GoogleApi {
  GoogleApi({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _key = apiKey ?? Env.googleApiKey;

  final http.Client _client;
  final String _key;

  /// 대중교통 (KTX, SRT, 버스, 지하철) 경로.
  Future<TravelRoute> transit(GeoPoint origin, GeoPoint destination, {required DateTime departure}) async {
    if (_key.isEmpty) throw const GoogleApiException('GOOGLE_API_KEY missing');
    Map<String, dynamic> loc(GeoPoint p) => {
          'location': {
            'latLng': {'latitude': p.lat, 'longitude': p.lng},
          },
        };
    final res = await _client.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _key,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,'
            'routes.legs.steps.travelMode,routes.legs.steps.transitDetails.transitLine.name,'
            'routes.legs.steps.transitDetails.transitLine.nameShort',
      },
      body: jsonEncode({
        'origin': loc(origin),
        'destination': loc(destination),
        'travelMode': 'TRANSIT',
        'departureTime': departure.toUtc().toIso8601String(),
        'polylineQuality': 'HIGH_QUALITY',
        'languageCode': 'ko',
      }),
    );
    if (res.statusCode != 200) throw GoogleApiException('HTTP ${res.statusCode}: ${res.body}');
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) throw const GoogleApiException('No transit route found');
    final r = routes.first as Map<String, dynamic>;
    final lines = <String>[];
    for (final leg in (r['legs'] as List? ?? const [])) {
      for (final step in (leg['steps'] as List? ?? const [])) {
        final line = step['transitDetails']?['transitLine'];
        final name = (line?['name'] ?? line?['nameShort']) as String?;
        if (name != null && !lines.contains(name)) lines.add(name);
      }
    }
    return TravelRoute(
      mode: TravelMode.transit,
      distanceMeters: (r['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: int.parse((r['duration'] as String).replaceAll('s', '')),
      points: decodePolyline(r['polyline']['encodedPolyline'] as String),
      transitLines: lines,
    );
  }

  /// 일별 예보 (오늘부터 약 10일). [lang]: 'ko' 또는 'en'.
  Future<List<DailyWeather>> dailyForecast(GeoPoint p, {String lang = 'ko'}) async {
    if (_key.isEmpty) throw const GoogleApiException('GOOGLE_API_KEY missing');
    final uri = Uri.https('weather.googleapis.com', '/v1/forecast/days:lookup', {
      'key': _key,
      'location.latitude': '${p.lat}',
      'location.longitude': '${p.lng}',
      'days': '10',
      'pageSize': '10',
      'languageCode': lang,
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw GoogleApiException('HTTP ${res.statusCode}: ${res.body}');
    return parseForecast(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  static List<DailyWeather> parseForecast(Map<String, dynamic> json) {
    int? deg(dynamic t) => (t?['degrees'] as num?)?.round();
    return [
      for (final d in (json['forecastDays'] as List? ?? const []))
        () {
          final date = d['displayDate'] as Map<String, dynamic>;
          // 낮 시간 예보가 있으면 그것을, 없으면 하루 전체 예보를 사용한다.
          final f = (d['daytimeForecast'] ?? d['fullDayForecast'] ?? const {}) as Map<String, dynamic>;
          final cond = f['weatherCondition'] as Map<String, dynamic>? ?? const {};
          return DailyWeather(
            date: DateTime(date['year'] as int, date['month'] as int, date['day'] as int),
            condition: (cond['description']?['text'] as String?) ?? '',
            type: (cond['type'] as String?) ?? 'UNKNOWN',
            maxC: deg(d['maxTemperature']),
            minC: deg(d['minTemperature']),
            rainChance: (f['precipitation']?['probability']?['percent'] as num?)?.round(),
          );
        }(),
    ];
  }

  /// Google Encoded Polyline Algorithm.
  static List<GeoPoint> decodePolyline(String s) {
    final pts = <GeoPoint>[];
    var i = 0, lat = 0, lng = 0;
    while (i < s.length) {
      for (var which = 0; which < 2; which++) {
        var shift = 0, result = 0, b = 0;
        do {
          b = s.codeUnitAt(i++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        // ~x 대신 -(x + 1): 웹(dart2js)에서 `~`는 부호 없는 32비트를 반환한다.
        final delta = (result & 1) != 0 ? -((result >> 1) + 1) : (result >> 1);
        if (which == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      pts.add(GeoPoint(lat / 1e5, lng / 1e5));
    }
    return pts;
  }
}

class GoogleApiException implements Exception {
  const GoogleApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
