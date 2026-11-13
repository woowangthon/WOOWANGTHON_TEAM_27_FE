// Run with Dart and the FE package configuration. All traffic/news/event inputs
// come from the production endpoints. The verification appointments are never
// inserted into the user's calendar or presented as real personal appointments.
import 'dart:convert';
import 'dart:io';
import 'package:liferadar_core/liferadar_core.dart';

Future<void> main(List<String> args) async {
  final config = jsonDecode(await File(args.isEmpty ? 'env.json' : args.first).readAsString()) as Map;
  final service = TravelImpactService(
    kakaoKey: '${config['KAKAO_REST_API_KEY'] ?? ''}',
    googleKey: '${config['GOOGLE_API_KEY'] ?? ''}',
    itsKey: '${config['ITS_API_KEY'] ?? ''}',
  );
  final now = DateTime.now();
  Future<Map<String, dynamic>> run(String id, GeoPoint from, GeoPoint to, DateTime start, TravelMode mode) async {
    final report = await service.check(
      Plan(
        id: id,
        title: 'Live integration verification',
        source: 'local',
        start: start,
        end: start.add(const Duration(hours: 1)),
        location: to,
        locationText: id,
        city: '',
      ),
      now: now,
      origin: from,
      mode: mode,
    );
    return {
      'verification_appointment': id,
      'checked_at': report.checkedAt.toIso8601String(),
      'route_distance_m': report.route?.distanceMeters,
      'route_duration_s': report.route?.durationSeconds,
      'sources': [
        for (final s in report.sources)
          {'name': s.name, 'ok': s.ok, 'detail': s.detail, 'updated_at': s.updatedAt?.toIso8601String()},
      ],
      'findings': [
        for (final i in report.insights)
          {
            'id': i.id,
            'title': i.title.ko,
            'body': i.body.ko,
            'notification_eligible': i.notificationEligible,
            'evidence': i.why.ko,
            'sources': [
              for (final s in i.sources) {'name': s.title, 'url': s.url},
            ],
          },
      ],
    };
  }

  try {
    final reports = [
      await run(
        'seoul-station-to-bongeun-bridge',
        const GeoPoint(37.5547, 126.9706),
        const GeoPoint(37.51567, 127.06873),
        now.add(const Duration(hours: 1)),
        TravelMode.car,
      ),
      await run(
        'seoul-station-to-busan-station',
        const GeoPoint(37.5547, 126.9706),
        const GeoPoint(35.1151, 129.0403),
        DateTime(2026, 12, 10, 14),
        TravelMode.transit,
      ),
      await run('deoksugung-event-road-control', const GeoPoint(37.5547,126.9706),
        const GeoPoint(37.5662,126.9750), now.add(const Duration(hours: 1)), TravelMode.car),
      await run('sinchon-official-bus-diversion', const GeoPoint(37.5573,126.9255),
        const GeoPoint(37.5645,126.9388), DateTime(2026,11,15,11), TravelMode.transit),
    ];
    final output = const JsonEncoder.withIndent('  ').convert({'real_network': true, 'reports': reports});
    await File('.test-tmp/live-traffic/production-verification.json').writeAsString(output);
    stdout.writeln(output);
    if (reports.any((r) => r['route_distance_m'] == null)) exitCode = 2;
  } finally {
    service.close();
  }
}
