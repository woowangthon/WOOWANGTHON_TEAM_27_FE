import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:liferadar/services/google_api.dart';

void main() {
  test('decodePolyline: Google rasmiy misoli', () {
    final pts = GoogleApi.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].lat, closeTo(38.5, 1e-5));
    expect(pts[0].lng, closeTo(-120.2, 1e-5));
    expect(pts[2].lat, closeTo(43.252, 1e-5));
    expect(pts[2].lng, closeTo(-126.453, 1e-5));
  });

  test('nearestPointOnPolyline: 점이 드문 KTX 선에서 선분 위 투영', () {
    // 서울 → 부산 직선; 대전 근처의 점은 선분 중간으로 투영된다.
    const line = [GeoPoint(37.5547, 126.9707), GeoPoint(35.1151, 129.0403)];
    const dcc = GeoPoint(36.3754, 127.3913);
    final p = RouteMatcher.nearestPointOnPolyline(dcc, line);
    // 양 끝점이 아니라 중간 점이어야 한다
    expect(p.lat, inExclusiveRange(35.2, 37.5));
    expect(RouteMatcher.haversineKm(dcc, p), lessThan(RouteMatcher.haversineKm(dcc, line.first)));
  });
}
