import 'dart:convert';

import 'package:http/http.dart' as http;

import 'timeout_client.dart';

import 'package:liferadar_core/liferadar_core.dart';

/// Google Calendar REST API (v3) — 사용자의 OAuth 액세스 토큰 사용.
/// Scope: https://www.googleapis.com/auth/calendar.events (읽기, 추가, 수정, 삭제).
class CalendarApi {
  CalendarApi(this._accessToken, {http.Client? client}) : _client = TimeoutClient(client ?? http.Client());

  static const scope = 'https://www.googleapis.com/auth/calendar.events';
  static const _base = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  final String _accessToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  /// 앞으로 [days]일 동안의 일정 (반복 일정은 개별 인스턴스로).
  Future<List<CalendarEvent>> upcoming({int days = 90, int max = 100}) async {
    final now = DateTime.now().toUtc();
    final uri = Uri.parse(_base).replace(queryParameters: {
      'timeMin': now.toIso8601String(),
      'timeMax': now.add(Duration(days: days)).toIso8601String(),
      'singleEvents': 'true',
      'orderBy': 'startTime',
      'maxResults': '$max',
    });
    final res = await _client.get(uri, headers: _headers);
    _check(res);
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final item in (json['items'] as List? ?? const []))
        if (item['status'] != 'cancelled') CalendarEvent.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 이 LifeRadar 행사가 이미 캘린더에 있으면 그 일정 링크(없으면 빈 문자열), 없으면 null.
  /// 추가할 때 붙인 비공개 속성(liferadarEventId)으로 찾는다 — 다른 기기에서 추가한 것도 찾는다.
  Future<String?> findAdded(String liferadarEventId) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'privateExtendedProperty': 'liferadarEventId=$liferadarEventId',
      'maxResults': '1',
      'showDeleted': 'false',
    });
    final res = await _client.get(uri, headers: _headers);
    _check(res);
    final items = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['items'] as List? ?? const [];
    final live = items.where((i) => i['status'] != 'cancelled').toList();
    if (live.isEmpty) return null;
    return live.first['htmlLink'] as String? ?? '';
  }

  /// LifeRadar 행사를 사용자 캘린더에 추가한다. 생성된 일정 링크를 반환한다.
  Future<String?> insert(RadarEvent e, {required String title}) async {
    final res = await _client.post(
      Uri.parse(_base),
      headers: _headers,
      body: jsonEncode(eventBody(e,title:title)),
    );
    _check(res);
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['htmlLink'] as String?;
  }

  /// Application dates are deadlines, never a multi-week event. Date-only
  /// deadlines use Calendar date fields; no fabricated time or place.
  static Map<String,dynamic> eventBody(RadarEvent e,{required String title}) {
    String day(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final application = e.isApplication && e.deadline != null;
    final d = application ? e.applicationDate(e.deadline!) : e.start;
    return {
      'summary':title,
      if (!application && !e.placeless) 'location':'${e.venue}, ${e.city}',
      'description':[
        'Added by LifeRadar',
        if(application) 'Application deadline / 접수 마감 (KST). Not an event schedule.',
        if(e.eligibilityText != null) 'Eligibility: ${e.eligibilityText}',
        if(e.registerUrl != null) 'Register: ${e.registerUrl}',
        if(e.url != null) e.url,
      ].join('\n'),
      if (application && e.deadlinePrecision == 'date') ...{
        'start':{'date':day(d)},'end':{'date':day(d.add(const Duration(days:1)))},
      } else if (application) ...{
        'start':{'dateTime':e.deadline!.toUtc().toIso8601String()},
        'end':{'dateTime':e.deadline!.toUtc().add(const Duration(minutes:1)).toIso8601String()},
      } else if (_wholeDays(e)) ...{
        // 시각 없이 하루(또는 며칠) — 종일 일정. 몇 시인지 지어내지 않는다.
        'start':{'date':day(e.start)},'end':{'date':day(e.end)},
      } else ...{
        'start':{'dateTime':_local(e.start),'timeZone':'Asia/Seoul'},
        'end':{'dateTime':_local(e.end),'timeZone':'Asia/Seoul'},
      },
      'extendedProperties':{'private':{'liferadarEventId':e.id,
        if(application) 'liferadarDateMeaning':'application-deadline'}},
    };
  }

  /// 사용자 일정을 캘린더에 기록한다: [eventId]가 없으면 새로, 있으면 수정.
  Future<CalendarEvent> savePlan(Plan p, {String? eventId}) async {
    final body = jsonEncode(planBody(p, patch: eventId != null));
    final res = eventId == null
        ? await _client.post(Uri.parse(_base), headers: _headers, body: body)
        : await _client.patch(Uri.parse('$_base/${Uri.encodeComponent(eventId)}'), headers: _headers, body: body);
    _check(res);
    return CalendarEvent.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> delete(String eventId) async {
    final res = await _client.delete(Uri.parse('$_base/${Uri.encodeComponent(eventId)}'), headers: _headers);
    // 410 = 이미 삭제됨 — 오류가 아니다.
    if (res.statusCode == 410 || res.statusCode == 404) return;
    _check(res);
  }

  /// 일정 → Calendar API 요청 본문. 종일 일정은 'date', 아니면 UTC 'dateTime'.
  /// PATCH에서는 반대쪽 필드를 null로 지운다 (예: 시간 지정 → 종일).
  static Map<String, dynamic> planBody(Plan p, {bool patch = false}) {
    String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'summary': p.title,
      'location': p.locationText,
      'description': p.note ?? '',
      if (p.isAllDay) ...{
        'start': {'date': day(p.start), if (patch) 'dateTime': null},
        'end': {'date': day(p.end), if (patch) 'dateTime': null},
      } else ...{
        'start': {'dateTime': p.start.toUtc().toIso8601String(), if (patch) 'date': null},
        'end': {'dateTime': p.end.toUtc().toIso8601String(), if (patch) 'date': null},
      },
    };
  }

  static bool _wholeDays(RadarEvent e) =>
      e.start.hour == 0 && e.start.minute == 0 && e.end.hour == 0 && e.end.minute == 0 && e.end.isAfter(e.start);

  /// 일정 시각은 한국 시간으로 저장됨 — 시간대를 포함한 "로컬" ISO로 보낸다.
  static String _local(DateTime d) => DateTime(d.year, d.month, d.day, d.hour, d.minute)
      .toIso8601String()
      .split('.')
      .first;

  void _check(http.Response res) {
    if (res.statusCode == 401) throw const CalendarAuthExpired();
    if (res.statusCode >= 300) throw CalendarApiException('HTTP ${res.statusCode}: ${res.body}');
  }
}

/// 캘린더에서 읽은 일정 (원본).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.description,
    this.htmlLink,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) {
    DateTime parse(Map<String, dynamic>? t) {
      final dt = t?['dateTime'] as String?;
      if (dt != null) return DateTime.parse(dt).toLocal();
      final d = DateTime.parse(t!['date'] as String); // 종일 일정
      return DateTime(d.year, d.month, d.day);
    }

    return CalendarEvent(
      id: j['id'] as String,
      title: (j['summary'] as String?)?.trim().isNotEmpty == true ? j['summary'] as String : '(no title)',
      start: parse(j['start'] as Map<String, dynamic>?),
      end: parse(j['end'] as Map<String, dynamic>?),
      location: (j['location'] as String?)?.trim(),
      description: (j['description'] as String?)?.trim(),
      htmlLink: j['htmlLink'] as String?,
    );
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? description;
  final String? htmlLink;
}

class CalendarApiException implements Exception {
  const CalendarApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 같은 행사가 이미 캘린더에 있다 — 다시 넣지 않는다.
class CalendarAlreadyAdded extends CalendarApiException {
  const CalendarAlreadyAdded() : super('already-added');
}

/// 같은 행사를 추가하는 중이다 (버튼을 여러 번 누름) — 두 번째 요청은 무시한다.
class CalendarAddInProgress extends CalendarApiException {
  const CalendarAddInProgress() : super('in-progress');
}

class CalendarAuthExpired extends CalendarApiException {
  const CalendarAuthExpired() : super('Google session expired — please reconnect');
}
