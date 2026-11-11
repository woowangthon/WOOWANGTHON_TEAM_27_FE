import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:liferadar_core/liferadar_core.dart';

/// Uses the user's screenshot times. It does not read or alter phone storage.
Future<void> main() async {
  final config = jsonDecode(await File('env.json').readAsString()) as Map;
  final client = http.Client();
  final service = TravelImpactService(kakaoKey: '${config['KAKAO_REST_API_KEY'] ?? ''}',
    googleKey: '${config['GOOGLE_API_KEY'] ?? ''}', itsKey: '${config['ITS_API_KEY'] ?? ''}');
  try {
    Future<Place> place(String query) async {
      final response = await client.get(Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {'query': query}),
        headers: {'Authorization': 'KakaoAK ${config['KAKAO_REST_API_KEY']}'}).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw StateError('Place lookup HTTP ${response.statusCode}');
      final docs = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['documents'] as List;
      if (docs.isEmpty) throw StateError('Place not found: $query');
      final d = docs.first as Map;
      return Place(name: d['place_name'] as String, address: d['address_name'] as String,
        location: GeoPoint(double.parse(d['y'] as String), double.parse(d['x'] as String)));
    }
    final from = await place('충북대학교 개신캠퍼스');
    final to = await place('오송역');
    final departure = DateTime(2026,11,15,11,30), arrival = DateTime(2026,11,15,12,42);
    Map<String, dynamic> loc(Place p) => {'location': {'latLng': {'latitude': p.location.lat, 'longitude': p.location.lng}}};
    final response = await client.post(Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': '${config['GOOGLE_API_KEY']}',
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps.transitDetails.transitLine'},
      body: jsonEncode({'origin': loc(from), 'destination': loc(to), 'travelMode': 'TRANSIT',
        'departureTime': departure.toUtc().toIso8601String(), 'languageCode': 'ko'})).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw StateError('Transit lookup HTTP ${response.statusCode}');
    final routes = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['routes'] as List?;
    if (routes == null || routes.isEmpty) throw StateError('No current route returned; service status is unknown.');
    final route = routes.first as Map;
    final lines = <String>[], modes = <String>{};
    for (final leg in route['legs'] as List? ?? const []) {
      for (final step in leg['steps'] as List? ?? const []) {
        final line = step['transitDetails']?['transitLine'];
        if (line == null) continue;
        if (line['name'] is String) lines.add(line['name'] as String);
        final mode = switch (line['vehicle']?['type']) {
          'BUS' || 'INTERCITY_BUS' || 'TROLLEYBUS' => 'bus',
          'SUBWAY' || 'METRO_RAIL' || 'TRAM' => 'subway',
          'RAIL' || 'HEAVY_RAIL' || 'HIGH_SPEED_TRAIN' || 'COMMUTER_TRAIN' || 'LONG_DISTANCE_TRAIN' => 'rail',
          _ => null};
        if (mode != null) modes.add(mode);
      }
    }
    final trip = TripContext(id: 'screenshot-saved-trip', version: '2026-11-15T11:30/12:42',
      departure: departure, arrival: arrival, lines: lines, modes: modes,
      points: TravelImpactService.decodePolyline(route['polyline']['encodedPolyline'] as String));
    final plan = Plan(id: 'screenshot-competition-departure', title: '공모전 출발', source: 'local',
      start: DateTime(2026,11,15,13), end: DateTime(2026,11,15,14),
      location: to.location, locationText: to.name, city: '청주');
    final report = await service.check(plan, now: DateTime.now(), origin: from.location,
      mode: TravelMode.transit, trip: trip);
    final output = {'real_network': true, 'input_basis': 'user screenshot, not phone storage',
      'checked_at': report.checkedAt.toIso8601String(),
      'origin': {'name': from.name, 'address': from.address},
      'destination': {'name': to.name, 'address': to.address},
      'saved_departure': departure.toIso8601String(), 'saved_arrival': arrival.toIso8601String(),
      'current_route_lines': lines, 'current_route_modes': modes.toList(),
      'current_route_duration': route['duration'], 'current_route_distance_m': route['distanceMeters'],
      'saved_bus_label_present_in_current_response': lines.any((s) => s.contains('충북 급행버스')),
      'sources': [for (final s in report.sources) {'name': s.name, 'ok': s.ok, 'detail': s.detail, 'updated_at': s.updatedAt?.toIso8601String()}],
      'findings': [for (final i in report.insights) {'id': i.id, 'title': i.title.ko, 'body': i.body.ko,
        'evidence': i.why.ko, 'notification_eligible': i.notificationEligible,
        'sources': [for (final s in i.sources) {'name': s.title, 'url': s.url}]}]};
    final text = const JsonEncoder.withIndent('  ').convert(output);
    await File('../공모전_저장경로_실제조회.json').writeAsString(text);
    stdout.writeln(text);
  } finally { service.close(); client.close(); }
}
