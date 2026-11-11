import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/env.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../services/calendar_api.dart';
import 'providers.dart';

enum CalendarStatus { disconnected, connecting, syncing, connected, error }

class CalendarState {
  const CalendarState({this.status = CalendarStatus.disconnected, this.error, this.lastSync});

  final CalendarStatus status;
  final String? error;
  final DateTime? lastSync;

  bool get isConnected => status == CalendarStatus.connected || status == CalendarStatus.syncing;
  bool get isBusy => status == CalendarStatus.connecting || status == CalendarStatus.syncing;
}

/// Google Sign-In은 앱 시작 시 한 번 초기화한다 (웹: GIS SDK 로드).
Future<void>? _googleSignInInitialization;

Future<void> initGoogleSignIn() {
  return _googleSignInInitialization ??= _initializeGoogleSignIn();
}

Future<void> _initializeGoogleSignIn() async {
  if (!isGoogleSignInConfigured) return;
  try {
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? Env.googleOAuthWebClientId : null,
      serverClientId: kIsWeb ? null : Env.googleOAuthWebClientId,
    );
  } catch (_) {
    _googleSignInInitialization = null;
    rethrow;
  }
}

/// Android OAuth 클라이언트는 패키지와 SHA-1로 식별되고, 서버 ID에는 웹 클라이언트를 사용한다.
bool get isGoogleSignInConfigured =>
    (kIsWeb || defaultTargetPlatform == TargetPlatform.android) && Env.googleOAuthWebClientId.isNotEmpty;

final calendarProvider = NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

/// Google 캘린더 연동: 권한 → 일정 읽기 → 장소 지오코딩 → 내 일정.
/// 액세스 토큰은 메모리에만 (1시간). 만료되면 사용자가 다시 "연결"을 누른다.
class CalendarController extends Notifier<CalendarState> {
  String? _token;
  final Map<String, Place?> _geocodeCache = {};

  @override
  CalendarState build() => const CalendarState();

  /// 버튼을 누를 때 호출 (웹 팝업은 사용자 동작에서만 열린다).
  Future<void> connect() async {
    if (!isGoogleSignInConfigured) {
      state = const CalendarState(status: CalendarStatus.error, error: 'not-configured');
      return;
    }
    state = const CalendarState(status: CalendarStatus.connecting);
    try {
      await _authorize();
      await sync();
    } catch (e) {
      state = CalendarState(status: CalendarStatus.error, error: e.toString());
    }
  }

  Future<void> _authorize() async {
    await initGoogleSignIn();
    final signIn = GoogleSignIn.instance;
    var client = signIn.authorizationClient;
    if (!kIsWeb && signIn.supportsAuthenticate()) {
      final account = await signIn.attemptLightweightAuthentication() ??
          await signIn.authenticate(scopeHint: [CalendarApi.scope]);
      client = account.authorizationClient;
    }
    final authz = await client.authorizationForScopes([CalendarApi.scope]) ??
        await client.authorizeScopes([CalendarApi.scope]);
    _token = authz.accessToken;
  }

  Future<void> sync() async {
    final token = _token;
    if (token == null) return;
    state = CalendarState(status: CalendarStatus.syncing, lastSync: state.lastSync);
    try {
      final events = await CalendarApi(token).upcoming();
      final plans = await Future.wait(events.map(_toPlan));
      ref.read(plansProvider.notifier).setPlans(plans);
      state = CalendarState(status: CalendarStatus.connected, lastSync: DateTime.now());
    } on CalendarAuthExpired {
      _token = null;
      state = const CalendarState(status: CalendarStatus.error, error: 'expired');
    } catch (e) {
      state = CalendarState(status: CalendarStatus.error, error: e.toString(), lastSync: state.lastSync);
    }
  }

  /// LifeRadar 행사를 캘린더에 추가한다. 연결되지 않았다면 먼저 권한을 요청한다.
  Future<String?> addEvent(RadarEvent event, {required String title}) async {
    if (!isGoogleSignInConfigured) throw const CalendarApiException('not-configured');
    if (_token == null) await _authorize();
    try {
      final link = await CalendarApi(_token!).insert(event, title: title);
      await sync();
      return link;
    } on CalendarAuthExpired {
      await _authorize(); // 한 번 다시 시도한다
      final link = await CalendarApi(_token!).insert(event, title: title);
      await sync();
      return link;
    }
  }

  /// 일정을 Google 캘린더에 기록(새로 만들거나 기존 일정 수정)한 뒤 동기화한다.
  Future<void> savePlan(Plan plan) => _withApi((api) => api.savePlan(plan, eventId: plan.calendarEventId));

  /// 캘린더의 일정을 삭제한다.
  Future<void> deletePlan(Plan plan) async {
    final id = plan.calendarEventId;
    if (id != null) await _withApi((api) => api.delete(id));
  }

  /// 토큰이 없으면 권한을 요청하고, 만료되었으면 한 번 다시 시도한다. 이후 동기화.
  Future<void> _withApi(Future<void> Function(CalendarApi api) action) async {
    if (!isGoogleSignInConfigured) throw const CalendarApiException('not-configured');
    if (_token == null) await _authorize();
    try {
      await action(CalendarApi(_token!));
    } on CalendarAuthExpired {
      await _authorize();
      await action(CalendarApi(_token!));
    }
    await sync();
  }

  Future<void> disconnect() async {
    final token = _token;
    _token = null;
    if (token != null) {
      try {
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: token);
      } catch (_) {}
    }
    ref.read(plansProvider.notifier).resetToSample();
    state = const CalendarState();
  }

  Future<Plan> _toPlan(CalendarEvent e) async {
    final place = await _geocode(e.location);
    return Plan(
      id: 'gcal-${e.id}',
      title: e.title,
      start: e.start,
      end: e.end,
      locationText: e.location ?? '',
      city: place == null ? '' : place.address.split(' ').first,
      location: place?.location,
      source: 'gcal',
      note: e.description?.isEmpty == true ? null : e.description,
      htmlLink: e.htmlLink,
    );
  }

  /// 캘린더의 장소 텍스트 → 좌표 (Kakao Local). 찾지 못하면 null — 일정이 지도에 표시되지 않는다.
  Future<Place?> _geocode(String? text) async {
    if (text == null || text.isEmpty) return null;
    if (_geocodeCache.containsKey(text)) return _geocodeCache[text];
    Place? result;
    try {
      final hits = await ref.read(kakaoApiProvider).searchPlaces(text, size: 1);
      // 전체 주소여도 키워드 검색이 보통 찾아낸다; 실패하면 첫 단어로 다시 시도한다.
      result = hits.isNotEmpty
          ? hits.first
          : (await ref.read(kakaoApiProvider).searchPlaces(text.split(RegExp(r'[,\s]')).first, size: 1))
              .firstOrNull;
    } catch (_) {}
    return _geocodeCache[text] = result;
  }
}
