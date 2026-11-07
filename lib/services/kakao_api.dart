import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/env.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// Kakao Local (장소 검색)과 Kakao Mobility (자동차 경로).
/// ⚠️ 현재는 클라이언트에서 호출한다 (CORS 허용). 이후 서버 프록시로 옮긴다.
class KakaoApi {
  KakaoApi({http.Client? client, String? restKey})
      : _client = client ?? http.Client(),
        _key = restKey ?? Env.kakaoRestApiKey;

  final http.Client _client;
  final String _key;

  Map<String, String> get _headers => {'Authorization': 'KakaoAK $_key'};

  /// 키워드로 장소 검색 (예: "부산역", "BEXCO").
  Future<List<Place>> searchPlaces(String query, {int size = 8}) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': query.trim(),
      'size': '$size',
    });
    final json = await _get(uri);
    return [
      for (final d in json['documents'] as List)
        Place(
          name: d['place_name'] as String,
          address: ((d['road_address_name'] as String?)?.isNotEmpty ?? false)
              ? d['road_address_name'] as String
              : d['address_name'] as String,
          location: GeoPoint(double.parse(d['y'] as String), double.parse(d['x'] as String)),
        ),
    ];
  }

  /// A→B 자동차 경로 (선택적 경유지 포함).
  /// [withGeometry]가 false면 거리/시간만 (우회 계산용, 더 빠름).
  Future<TravelRoute> directions(
    GeoPoint origin,
    GeoPoint destination, {
    GeoPoint? waypoint,
    bool withGeometry = true,
  }) async {
    String xy(GeoPoint p) => '${p.lng},${p.lat}';
    final uri = Uri.https('apis-navi.kakaomobility.com', '/v1/directions', {
      'origin': xy(origin),
      'destination': xy(destination),
      'waypoints': ?(waypoint == null ? null : xy(waypoint)),
      'summary': '${!withGeometry}',
    });
    final json = await _get(uri);
    final route = (json['routes'] as List).first as Map<String, dynamic>;
    if (route['result_code'] != 0) {
      throw KakaoApiException('No route: ${route['result_msg'] as String? ?? '-'}');
    }
    final summary = route['summary'] as Map<String, dynamic>;
    final points = <GeoPoint>[];
    if (withGeometry) {
      for (final section in route['sections'] as List) {
        for (final road in section['roads'] as List) {
          final v = (road['vertexes'] as List).cast<num>();
          for (var i = 0; i + 1 < v.length; i += 2) {
            points.add(GeoPoint(v[i + 1].toDouble(), v[i].toDouble()));
          }
        }
      }
    }
    return TravelRoute(
      distanceMeters: (summary['distance'] as num).toInt(),
      durationSeconds: (summary['duration'] as num).toInt(),
      points: points,
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    if (_key.isEmpty) throw const KakaoApiException('KAKAO_REST_API_KEY missing');
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw KakaoApiException('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}

class KakaoApiException implements Exception {
  const KakaoApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
