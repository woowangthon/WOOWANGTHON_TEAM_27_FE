import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android: flutter_local_notifications. API는 동기식(`notifyPermission()`)이나
/// Android는 비동기 응답만 제공하므로 권한 상태를 캐시함.
final _plugin = FlutterLocalNotificationsPlugin();
var _ready = false;
var _permission = 'default';

bool get _android => defaultTargetPlatform == TargetPlatform.android;

bool get notifySupported => _android;

/// main()에서 한 번 실행: 플러그인을 초기화하고 현재 권한을 읽어옴.
Future<void> initNotify() async {
  if (!_android) return;
  try {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
    await _refreshPermission();
  } catch (e) {
    debugPrint('notify init: $e');
  }
}

AndroidFlutterLocalNotificationsPlugin? get _androidImpl =>
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

Future<void> _refreshPermission() async {
  final enabled = await _androidImpl?.areNotificationsEnabled();
  _permission = enabled == true ? 'granted' : (_permission == 'denied' ? 'denied' : 'default');
}

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notifyPermission() => !_android ? 'unsupported' : _permission;

/// Android 13+에서는 시스템 권한 요청 창 표시, 이전 버전에서는 설정에서 권한을 확인함.
Future<String> requestNotifyPermission() async {
  if (!_android) return 'unsupported';
  if (!_ready) await initNotify();
  try {
    final granted = await _androidImpl?.requestNotificationsPermission();
    await _refreshPermission();
    if (_permission != 'granted' && granted == false) _permission = 'denied';
  } catch (e) {
    debugPrint('notify permission: $e');
  }
  return _permission;
}

/// 권한이 영구 거부된 경우 Android 시스템 창이 다시 뜨지 않음 — LifeRadar의
/// 알림 설정 화면을 엶.
Future<bool> openNotifySettings() async {
  if (!_android) return false;
  try {
    await const AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: {'android.provider.extra.APP_PACKAGE': 'com.liferadar.liferadar'},
    ).launch();
    return true;
  } catch (e) {
    debugPrint('notify settings: $e');
    return false;
  }
}

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'signals',
    'LifeRadar signals',
    channelDescription: 'Deadlines and alerts for your plans',
    importance: Importance.high,
    priority: Priority.high,
  ),
);

/// 동일한 [tag] — 단일 알림(중복 생성되지 않고 갱신됨).
void showSystemNotification(String title, String body, {String? tag}) {
  if (!_ready || _permission != 'granted') return;
  final id = (tag ?? '$title$body').hashCode & 0x7fffffff;
  _plugin.show(id: id, title: title, body: body, notificationDetails: _details).catchError(
    (Object e) => debugPrint('notify show: $e'),
  );
}
